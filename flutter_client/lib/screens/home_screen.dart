// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/websocket_service.dart';
import '../services/sms_service.dart';
import '../services/api_service.dart';
import 'change_password_screen.dart';

class AppCommand {
  final String key, label, description, command;
  final IconData icon;
  final Color color;
  const AppCommand({required this.key, required this.label, required this.description,
    required this.icon, required this.color, required this.command});
}

const List<AppCommand> _mainCommands = [
  AppCommand(key:'locate',       label:'Ubicación',    description:'Obtener posición GPS',   icon:Icons.location_on,               color:Color(0xFF00D4A0), command:'fix060s001n'),
  AppCommand(key:'start_engine', label:'Enc. motor',   description:'Restaurar alimentación', icon:Icons.play_arrow_rounded,        color:Color(0xFF22C55E), command:'supplyelec'),
  AppCommand(key:'stop_engine',  label:'Apagar motor', description:'Cortar alimentación',    icon:Icons.power_settings_new_rounded, color:Color(0xFFE8232A), command:'stopelec'),
];

String buildSms(String key, String password) {
  final cmd = _mainCommands.firstWhere((c) => c.key == key,
    orElse: () => AppCommand(key:key, label:key, description:key, icon:Icons.sms, color:const Color(0xFF60A5FA), command:key));
  return '${cmd.command}$password';
}

Map<String, String> parseSms(String body) {
  final b = body.toLowerCase();
  if (b.contains('lat') && (b.contains('lon') || b.contains('lng') || b.contains('long'))) {
    final latM = RegExp(r'lat[:= ]+([-\d.]+)', caseSensitive: false).firstMatch(body);
    final lngM = RegExp(r'(?:lon|lng|long)[:= ]+([-\d.]+)', caseSensitive: false).firstMatch(body);
    final spdM = RegExp(r'speed[:= ]+([\d.]+)', caseSensitive: false).firstMatch(body);
    final lat = latM?.group(1) ?? ''; final lng = lngM?.group(1) ?? '';
    return {'icon':'📍','label':'Ubicación GPS','value':lat.isNotEmpty&&lng.isNotEmpty?'$lat, $lng · ${spdM?.group(1)??'0'} km/h':'Ubicación recibida','lat':lat,'lng':lng};
  }
  final mapM = RegExp(r'q=([-\d.]+),\s*([-\d.]+)', caseSensitive: false).firstMatch(body);
  if (mapM != null) return {'icon':'📍','label':'Ubicación GPS','value':'${mapM.group(1)}, ${mapM.group(2)}','lat':mapM.group(1)??'','lng':mapM.group(2)??''};
  if (b.contains('fix ok'))        return {'icon':'📍','label':'Ubicación solicitada','value':'Esperando posición GPS'};
  if (b.contains('stopelec ok'))   return {'icon':'🔴','label':'Motor apagado','value':'Corte aplicado'};
  if (b.contains('supplyelec ok')) return {'icon':'🟢','label':'Motor encendido','value':'Motor restaurado'};
  if (b.contains('pwdfail'))       return {'icon':'⚠️','label':'Contraseña incorrecta','value':'PWDFAIL'};
  if (b.contains('bat:')) { final m=RegExp(r'bat:\s*(\d+)',caseSensitive:false).firstMatch(body); return {'icon':'🔋','label':'Batería','value':'${m?.group(1)??'?'}%'}; }
  if (b.contains('pwr:'))          return {'icon':'ℹ️','label':'Estado GPS','value':body.length>70?'${body.substring(0,70)}...':body};
  return {'icon':'💬','label':'Respuesta GPS','value':body.length>70?'${body.substring(0,70)}...':body};
}

class _SmsLog {
  final String type, label, value, icon;
  final DateTime time;
  _SmsLog({required this.type, required this.label, required this.value, required this.icon, required this.time});
}

enum CmdState { idle, sending, waiting, answered }

// ══════════════════════════════════════════════════════════════
// ROUTER
// ══════════════════════════════════════════════════════════════
class HomeScreen extends StatelessWidget {
  final SessionData session;
  const HomeScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) =>
    session.isFleet ? FleetHomeScreen(session: session) : IndividualHomeScreen(session: session);
}

// ══════════════════════════════════════════════════════════════
// INDIVIDUAL
// ══════════════════════════════════════════════════════════════
class IndividualHomeScreen extends StatefulWidget {
  final SessionData session;
  const IndividualHomeScreen({super.key, required this.session});
  @override State<IndividualHomeScreen> createState() => _IndividualState();
}

class _IndividualState extends State<IndividualHomeScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final WebSocketService _ws = WebSocketService();
  StreamSubscription<PositionUpdate>? _wsSub;

  double? _lat, _lng;
  double _speed = 0, _heading = 0, _battery = 100;
  String _status = 'offline';
  bool _wsLive = false;
  String _updated = '--';

  final List<_SmsLog> _log = [];
  final Map<String, CmdState> _state = {};
  final Map<String, Map<String, String>> _resp = {};
  final Map<String, AnimationController> _pulse = {};

  static const kPass = '123456';

  @override
  void initState() { super.initState(); _connectWs(); _startSms(); }

  Future<void> _connectWs() async {
    await _ws.connectVehicle(deviceId: widget.session.deviceId ?? '', clientId: widget.session.clientId, wsToken: widget.session.wsToken);
    _wsSub = _ws.positionStream?.listen((u) {
      if (!mounted) return;
      setState(() { _wsLive=true; _lat=u.lat; _lng=u.lng; _speed=u.speed; _heading=u.heading; _battery=u.battery; _status=u.vehicleStatus; _updated=_fmt(u.timestamp); });
      if (_lat!=null&&_lng!=null) _map.move(LatLng(_lat!,_lng!), _map.camera.zoom);
    });
  }

  Future<void> _startSms() async {
    final sim = widget.session.simNumber ?? widget.session.phone ?? '';
    if (sim.isEmpty) return;
    await SmsService.startListening(simNumber: sim, onIncoming: (body, _) => _onSms(body));
  }

  void _onSms(String body) {
    final parsed = parseSms(body);
    parsed['time'] = _clock(DateTime.now());
    if (!mounted) return;
    String? mk;
    _state.forEach((k, v) { if (v == CmdState.waiting) mk = k; });
    setState(() {
      _log.insert(0, _SmsLog(type:'received', label:parsed['label']!, value:parsed['value']!, icon:parsed['icon']!, time:DateTime.now()));
      if (_log.length > 50) _log.removeLast();
      if (mk != null) { _state[mk!]=CmdState.answered; _resp[mk!]=parsed; _pulse[mk!]?.stop(); }
      final lat = double.tryParse(parsed['lat']??'');
      final lng = double.tryParse(parsed['lng']??'');
      if (lat!=null&&lng!=null) { _lat=lat; _lng=lng; _status='active'; _updated=_clock(DateTime.now()); _map.move(LatLng(lat,lng),16); }
    });
  }

  String _fmt(String iso) { try { return _clock(DateTime.parse(iso).toLocal()); } catch(_) { return '--'; } }
  String _clock(DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

  @override
  void dispose() { _wsSub?.cancel(); _ws.disconnect(); SmsService.stopListening(); for (final c in _pulse.values) c.dispose(); super.dispose(); }

  Color get _sc => _status=='active' ? const Color(0xFF22C55E) : _status=='idle' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

  Future<void> _send(String key) async {
    final phone = widget.session.simNumber ?? widget.session.phone;
    if (phone==null||phone.isEmpty) return;
    HapticFeedback.mediumImpact();
    _pulse[key] ??= AnimationController(vsync:this, duration:const Duration(milliseconds:900))..repeat(reverse:true);
    final sms = buildSms(key, kPass);
    final cmd = _mainCommands.firstWhere((c)=>c.key==key);
    setState(() { _state[key]=CmdState.sending; _resp.remove(key);
      _log.insert(0, _SmsLog(type:'sent', label:cmd.label, value:sms, icon:'📤', time:DateTime.now())); });
    final ok = await SmsService.sendCommand(phone:phone, command:sms);
    if (!mounted) return;
    setState(() => _state[key]=ok?CmdState.waiting:CmdState.idle);
    if (!ok) { _pulse[key]?.stop(); setState(() { _resp[key]={'icon':'❌','label':'No enviado','value':'Error SMS','time':_clock(DateTime.now())}; _state[key]=CmdState.answered; }); return; }
    Future.delayed(const Duration(seconds:90), () {
      if (mounted&&_state[key]==CmdState.waiting) { _pulse[key]?.stop(); setState(() { _state[key]=CmdState.answered; _resp[key]={'icon':'⏱️','label':'Sin respuesta','value':'Tiempo agotado','time':_clock(DateTime.now())}; }); }
    });
  }

  void _showDrawer() => showModalBottomSheet(context:context, backgroundColor:Colors.transparent, isScrollControlled:true,
    builder:(_) => _InfoDrawer(session:widget.session, speed:_speed, battery:_battery, status:_status, statusColor:_sc, updated:_updated, log:_log,
      onLogout: () async { Navigator.pop(context); await ApiService.clearSession(); if (mounted) Navigator.of(context).pushReplacementNamed('/login'); }));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final mapH = (constraints.maxHeight - 58 - 20 - 260).clamp(150.0, 500.0);
        return Column(children: [
          _TopBar(session:widget.session, updated:_updated, speed:_speed, battery:_battery, wsLive:_wsLive, onMenu:_showDrawer),
          SizedBox(height:mapH, child:_MapArea(mapController:_map, lat:_lat, lng:_lng, heading:_heading, status:_status, statusColor:_sc, onMenu:_showDrawer)),
          _ResizeHint(),
          Expanded(child:SingleChildScrollView(child:_CommandPanel(commands:_mainCommands, cmdState:_state, cmdResp:_resp, pulseCtrl:_pulse, onSend:_send))),
        ]);
      })),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLOTA
// ══════════════════════════════════════════════════════════════
class FleetHomeScreen extends StatefulWidget {
  final SessionData session;
  const FleetHomeScreen({super.key, required this.session});
  @override State<FleetHomeScreen> createState() => _FleetState();
}

class _FleetState extends State<FleetHomeScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final WebSocketService _ws = WebSocketService();
  StreamSubscription<PositionUpdate>? _wsSub;

  FleetVehicle? _sel;
  final Map<String, FleetVehicle> _live = {};
  final List<_SmsLog> _log = [];
  final Map<String, CmdState> _state = {};
  final Map<String, Map<String, String>> _resp = {};
  final Map<String, AnimationController> _pulse = {};

  bool _wsLive = false;
  String _updated = '--';

  static const kPass = '123456';

  @override
  void initState() {
    super.initState();
    for (final v in widget.session.vehicles) _live[v.id] = v;
    if (widget.session.vehicles.isNotEmpty) { _sel = widget.session.vehicles.first; _startSms(_sel!); }
    _connectWs();
  }

  Future<void> _connectWs() async {
    await _ws.connectVehicle(deviceId: _sel?.deviceId ?? '', clientId: widget.session.clientId, wsToken: widget.session.wsToken);
    _wsSub = _ws.positionStream?.listen((u) {
      if (!mounted) return;
      setState(() {
        _wsLive = true; _updated = _clock(DateTime.now());
        if (_sel != null) { _live[_sel!.id] = _sel!.copyWith(lat:u.lat, lng:u.lng, speed:u.speed, heading:u.heading, battery:u.battery, status:u.vehicleStatus); _sel = _live[_sel!.id]; }
      });
      if (u.lat != 0 && u.lng != 0) _map.move(LatLng(u.lat, u.lng), _map.camera.zoom);
    });
  }

  Future<void> _startSms(FleetVehicle v) async {
    final sim = v.phone ?? ''; if (sim.isEmpty) return;
    SmsService.stopListening();
    await SmsService.startListening(simNumber: sim, onIncoming: (body, _) => _onSms(body));
  }

  void _onSms(String body) {
    final parsed = parseSms(body); parsed['time'] = _clock(DateTime.now());
    if (!mounted) return;
    String? mk; _state.forEach((k, v) { if (v == CmdState.waiting) mk = k; });
    setState(() {
      _log.insert(0, _SmsLog(type:'received', label:parsed['label']!, value:parsed['value']!, icon:parsed['icon']!, time:DateTime.now()));
      if (_log.length > 50) _log.removeLast();
      if (mk != null) { _state[mk!]=CmdState.answered; _resp[mk!]=parsed; _pulse[mk!]?.stop(); }
      final lat = double.tryParse(parsed['lat']??''); final lng = double.tryParse(parsed['lng']??'');
      if (lat!=null&&lng!=null&&_sel!=null) { _live[_sel!.id]=_sel!.copyWith(lat:lat,lng:lng,status:'active'); _sel=_live[_sel!.id]; _updated=_clock(DateTime.now()); _map.move(LatLng(lat,lng),16); }
    });
  }

  String _clock(DateTime dt) => '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

  @override
  void dispose() { _wsSub?.cancel(); _ws.disconnect(); SmsService.stopListening(); for (final c in _pulse.values) c.dispose(); super.dispose(); }

  void _selectVehicle(FleetVehicle v) {
    setState(() { _sel=v; _state.clear(); _resp.clear(); _log.clear(); });
    _startSms(v);
    if (v.lat!=null&&v.lng!=null) _map.move(LatLng(v.lat!,v.lng!),16);
  }

  Color _vc(String? s) => s=='active' ? const Color(0xFF22C55E) : s=='idle' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

  Future<void> _send(String key) async {
    if (_sel==null) return;
    final phone = _sel!.phone ?? '';
    if (phone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sin SIM configurada'))); return; }
    HapticFeedback.mediumImpact();
    _pulse[key] ??= AnimationController(vsync:this, duration:const Duration(milliseconds:900))..repeat(reverse:true);
    final sms = buildSms(key, kPass);
    final cmd = _mainCommands.firstWhere((c)=>c.key==key);
    setState(() { _state[key]=CmdState.sending; _resp.remove(key);
      _log.insert(0, _SmsLog(type:'sent', label:cmd.label, value:sms, icon:'📤', time:DateTime.now())); });
    final ok = await SmsService.sendCommand(phone:phone, command:sms);
    if (!mounted) return;
    setState(() => _state[key]=ok?CmdState.waiting:CmdState.idle);
    if (!ok) { _pulse[key]?.stop(); setState(() { _resp[key]={'icon':'❌','label':'No enviado','value':'Error SMS'}; _state[key]=CmdState.answered; }); return; }
    Future.delayed(const Duration(seconds:90), () {
      if (mounted&&_state[key]==CmdState.waiting) { _pulse[key]?.stop(); setState(() { _state[key]=CmdState.answered; _resp[key]={'icon':'⏱️','label':'Sin respuesta','value':'Tiempo agotado'}; }); }
    });
  }

  void _showDrawer() => showModalBottomSheet(context:context, backgroundColor:Colors.transparent, isScrollControlled:true,
    builder:(_) => _InfoDrawer(session:widget.session, speed:_sel?.speed??0, battery:_sel?.battery??100,
      status:_sel?.status??'offline', statusColor:_vc(_sel?.status), updated:_updated, log:_log,
      onLogout: () async { Navigator.pop(context); await ApiService.clearSession(); if (mounted) Navigator.of(context).pushReplacementNamed('/login'); }));

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.session.vehicles.map((v) => _live[v.id] ?? v).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final mapH = (constraints.maxHeight - 58 - 72 - 20 - 260).clamp(120.0, 400.0);
        return Column(children: [
          Container(color:const Color(0xFF111827), padding:const EdgeInsets.fromLTRB(14,10,14,10),
            child:Row(children:[
              GestureDetector(onTap:_showDrawer, child:Container(width:38,height:38,
                decoration:BoxDecoration(color:const Color(0xFFE8232A).withOpacity(0.12), borderRadius:BorderRadius.circular(11)),
                child:const Icon(Icons.location_on, color:Color(0xFFE8232A), size:21))),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
                Text(widget.session.clientName, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.w800, fontSize:14, letterSpacing:-0.3), maxLines:1, overflow:TextOverflow.ellipsis),
                Text('${vehicles.length} vehículos · $_updated', style:const TextStyle(color:Color(0xFF6B7280), fontSize:10)),
              ])),
              Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                decoration:BoxDecoration(color:(_wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444)).withOpacity(0.1),
                  borderRadius:BorderRadius.circular(20), border:Border.all(color:(_wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444)).withOpacity(0.3))),
                child:Row(mainAxisSize:MainAxisSize.min, children:[
                  Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle, color:_wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444))),
                  const SizedBox(width:4),
                  Text(_wsLive?'LIVE':'OFF', style:TextStyle(color:_wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444), fontSize:9, fontWeight:FontWeight.w900)),
                ])),
            ])),
          SizedBox(height:72, child:Container(color:const Color(0xFF0F1623),
            child:ListView.builder(scrollDirection:Axis.horizontal, padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
              itemCount:vehicles.length, itemBuilder:(_,i) {
                final v = vehicles[i]; final isSel = v.id==_sel?.id; final color = _vc(v.status);
                return GestureDetector(onTap:()=>_selectVehicle(v), child:AnimatedContainer(
                  duration:const Duration(milliseconds:200), margin:const EdgeInsets.only(right:8),
                  padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
                  decoration:BoxDecoration(color:isSel?color.withOpacity(0.15):const Color(0xFF1F2937),
                    borderRadius:BorderRadius.circular(12), border:Border.all(color:isSel?color:Colors.white12, width:isSel?1.5:1)),
                  child:Row(mainAxisSize:MainAxisSize.min, children:[
                    Container(width:8,height:8,decoration:BoxDecoration(shape:BoxShape.circle, color:color)),
                    const SizedBox(width:7),
                    Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisAlignment:MainAxisAlignment.center, children:[
                      Text(v.name, style:TextStyle(color:isSel?Colors.white:Colors.white70, fontSize:12, fontWeight:FontWeight.w700)),
                      Text(v.plate, style:const TextStyle(color:Color(0xFF6B7280), fontSize:9)),
                    ]),
                  ])));
              }))),
          SizedBox(height:mapH, child:_MapArea(mapController:_map, lat:_sel?.lat, lng:_sel?.lng, heading:_sel?.heading??0,
            status:_sel?.status??'offline', statusColor:_vc(_sel?.status), onMenu:_showDrawer,
            extraMarkers: vehicles.where((v)=>v.id!=_sel?.id&&v.lat!=null&&v.lng!=null).map((v)=>
              Marker(point:LatLng(v.lat!,v.lng!), width:32, height:32,
                child:GestureDetector(onTap:()=>_selectVehicle(v), child:Container(
                  decoration:BoxDecoration(shape:BoxShape.circle, color:_vc(v.status).withOpacity(0.3),
                    border:Border.all(color:_vc(v.status), width:1.5)),
                  child:Icon(Icons.directions_car, color:_vc(v.status), size:16))))).toList())),
          _ResizeHint(),
          if (_sel!=null)
            Expanded(child:SingleChildScrollView(child:_CommandPanel(commands:_mainCommands, cmdState:_state, cmdResp:_resp, pulseCtrl:_pulse, onSend:_send)))
          else
            const Expanded(child:Center(child:Text('Selecciona un vehículo', style:TextStyle(color:Color(0xFF6B7280))))),
        ]);
      })),
    );
  }
}

// ── Widgets compartidos ───────────────────────────────────────

class _TopBar extends StatelessWidget {
  final SessionData session; final String updated; final double speed, battery; final bool wsLive; final VoidCallback onMenu;
  const _TopBar({required this.session, required this.updated, required this.speed, required this.battery, required this.wsLive, required this.onMenu});
  @override
  Widget build(BuildContext context) => Container(color:const Color(0xFF111827), padding:const EdgeInsets.fromLTRB(14,10,14,10),
    child:Row(children:[
      GestureDetector(onTap:onMenu, child:Container(width:38,height:38,
        decoration:BoxDecoration(color:const Color(0xFFE8232A).withOpacity(0.12), borderRadius:BorderRadius.circular(11)),
        child:const Icon(Icons.location_on, color:Color(0xFFE8232A), size:21))),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text(session.clientName, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.w800, fontSize:14, letterSpacing:-0.3), maxLines:1, overflow:TextOverflow.ellipsis),
        Text('Actualizado: $updated', style:const TextStyle(color:Color(0xFF6B7280), fontSize:10)),
      ])),
      _Chip('${speed.toStringAsFixed(0)}','km/h', speed>80?const Color(0xFFEF4444):const Color(0xFF22C55E)),
      const SizedBox(width:7),
      _Chip('${battery.toStringAsFixed(0)}','%', battery<20?const Color(0xFFEF4444):const Color(0xFF34D399)),
      const SizedBox(width:7),
      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
        decoration:BoxDecoration(color:(wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444)).withOpacity(0.1),
          borderRadius:BorderRadius.circular(20), border:Border.all(color:(wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444)).withOpacity(0.3))),
        child:Row(mainAxisSize:MainAxisSize.min, children:[
          Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle, color:wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444))),
          const SizedBox(width:4),
          Text(wsLive?'LIVE':'OFF', style:TextStyle(color:wsLive?const Color(0xFF22C55E):const Color(0xFFEF4444), fontSize:9, fontWeight:FontWeight.w900, letterSpacing:0.5)),
        ])),
    ]));
}

class _MapArea extends StatelessWidget {
  final MapController mapController;
  final double? lat, lng, heading;
  final String status;
  final Color statusColor;
  final VoidCallback onMenu;
  final List<Marker> extraMarkers;
  const _MapArea({required this.mapController, required this.lat, required this.lng, required this.heading,
    required this.status, required this.statusColor, required this.onMenu, this.extraMarkers=const[]});
  @override
  Widget build(BuildContext context) => Stack(children:[
    FlutterMap(mapController:mapController, options:MapOptions(
      initialCenter:lat!=null&&lng!=null?LatLng(lat!,lng!):const LatLng(-2.1962,-79.8956), initialZoom:16),
      children:[
        TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName:'com.gvam.gpscontrol'),
        if (lat!=null&&lng!=null) MarkerLayer(markers:[
          Marker(point:LatLng(lat!,lng!), width:56, height:56, child:Transform.rotate(angle:(heading??0)*3.14159/180,
            child:Container(decoration:BoxDecoration(shape:BoxShape.circle, color:statusColor.withOpacity(0.20),
              border:Border.all(color:statusColor, width:2), boxShadow:[BoxShadow(color:statusColor.withOpacity(0.35), blurRadius:18, spreadRadius:2)]),
              child:Icon(Icons.navigation_rounded, color:statusColor, size:30)))),
          ...extraMarkers,
        ]),
      ]),
    Positioned(top:10, left:10, child:Container(
      padding:const EdgeInsets.symmetric(horizontal:10, vertical:6),
      decoration:BoxDecoration(color:const Color(0xFF111827).withOpacity(0.92), borderRadius:BorderRadius.circular(20), border:Border.all(color:statusColor.withOpacity(0.4))),
      child:Row(mainAxisSize:MainAxisSize.min, children:[
        Container(width:6,height:6,decoration:BoxDecoration(shape:BoxShape.circle, color:statusColor)),
        const SizedBox(width:5),
        Text(status=='active'?'En ruta':status=='idle'?'Detenido':'Sin señal', style:TextStyle(color:statusColor, fontSize:11, fontWeight:FontWeight.w800)),
      ]))),
    Positioned(top:10, right:10, child:GestureDetector(onTap:onMenu, child:Container(padding:const EdgeInsets.all(8),
      decoration:BoxDecoration(color:const Color(0xFF111827).withOpacity(0.92), borderRadius:BorderRadius.circular(10), border:Border.all(color:Colors.white10)),
      child:const Icon(Icons.menu, color:Colors.white54, size:20)))),
  ]);
}

class _ResizeHint extends StatelessWidget {
  const _ResizeHint();
  @override
  Widget build(BuildContext context) => Container(height:14, color:const Color(0xFF111827),
    child:Center(child:Container(width:46, height:3, decoration:BoxDecoration(color:Colors.white12, borderRadius:BorderRadius.circular(99)))));
}

class _CommandPanel extends StatelessWidget {
  final List<AppCommand> commands;
  final Map<String, CmdState> cmdState;
  final Map<String, Map<String, String>> cmdResp;
  final Map<String, AnimationController> pulseCtrl;
  final void Function(String) onSend;
  const _CommandPanel({required this.commands, required this.cmdState, required this.cmdResp, required this.pulseCtrl, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(
    decoration:const BoxDecoration(color:Color(0xFF111827), border:Border(top:BorderSide(color:Color(0xFF1F2937)))),
    padding:const EdgeInsets.fromLTRB(12,12,12,16),
    child:Row(children:commands.map((cmd)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),
      child:_BigBtn(cmd:cmd, state:cmdState[cmd.key]??CmdState.idle, response:cmdResp[cmd.key], pulse:pulseCtrl[cmd.key], onTap:()=>onSend(cmd.key))))).toList()));
}

class _BigBtn extends StatelessWidget {
  final AppCommand cmd; final CmdState state; final Map<String,String>? response; final AnimationController? pulse; final VoidCallback onTap;
  const _BigBtn({required this.cmd, required this.state, required this.response, required this.pulse, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isWait = state==CmdState.sending||state==CmdState.waiting;
    final isAns  = state==CmdState.answered&&response!=null;
    final h = (MediaQuery.of(context).size.height * 0.26).clamp(180.0, 240.0);
    return GestureDetector(onTap:isWait?null:onTap, child:AnimatedBuilder(
      animation:pulse??kAlwaysCompleteAnimation,
      builder:(_,__) {
        final p = isWait?(pulse?.value??0.0):0.0;
        return AnimatedContainer(duration:const Duration(milliseconds:220), curve:Curves.easeOutCubic,
          height:h, padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(
            color:isAns?cmd.color.withOpacity(0.18):isWait?cmd.color.withOpacity(0.09+p*0.10):cmd.color.withOpacity(0.075),
            borderRadius:BorderRadius.circular(20),
            border:Border.all(color:isAns?cmd.color.withOpacity(0.80):isWait?cmd.color.withOpacity(0.35+p*0.35):cmd.color.withOpacity(0.24), width:isAns?2:1.2),
            boxShadow:[BoxShadow(color:cmd.color.withOpacity(isWait||isAns?0.28:0.10), blurRadius:isWait||isAns?24:10)]),
          child:Stack(children:[
            if (isWait) Positioned(top:0,right:0,child:Container(width:9,height:9,decoration:BoxDecoration(shape:BoxShape.circle, color:cmd.color, boxShadow:[BoxShadow(color:cmd.color.withOpacity(0.7), blurRadius:10)]))),
            Center(child:isAns?_Answered(cmd:cmd,r:response!):isWait?_Waiting(cmd:cmd,state:state):_Idle(cmd:cmd)),
          ]));
      }));
  }
}

class _Idle extends StatelessWidget {
  final AppCommand cmd;
  const _Idle({required this.cmd});
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment:MainAxisAlignment.center, children:[
    Icon(cmd.icon, color:cmd.color, size:44), const SizedBox(height:8),
    Text(cmd.label, textAlign:TextAlign.center, style:TextStyle(color:cmd.color, fontSize:17, fontWeight:FontWeight.w900, height:1.05), maxLines:2, overflow:TextOverflow.ellipsis),
    const SizedBox(height:4),
    Text(cmd.description, textAlign:TextAlign.center, style:TextStyle(color:cmd.color.withOpacity(0.5), fontSize:9), maxLines:1, overflow:TextOverflow.ellipsis),
  ]);
}

class _Waiting extends StatelessWidget {
  final AppCommand cmd; final CmdState state;
  const _Waiting({required this.cmd, required this.state});
  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment:MainAxisAlignment.center, children:[
    SizedBox(width:38,height:38,child:CircularProgressIndicator(color:cmd.color, strokeWidth:2.8)), const SizedBox(height:10),
    Text(state==CmdState.sending?'Enviando...':'Esperando...', textAlign:TextAlign.center, style:TextStyle(color:cmd.color, fontSize:13, fontWeight:FontWeight.w900)),
  ]);
}

class _Answered extends StatelessWidget {
  final AppCommand cmd; final Map<String,String> r;
  const _Answered({required this.cmd, required this.r});
  Future<void> _maps() async {
    final lat=r['lat']; final lng=r['lng'];
    if (lat==null||lng==null||lat.isEmpty||lng.isEmpty) return;
    final app=Uri.parse('geo:$lat,$lng?q=$lat,$lng'); final web=Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(app, mode:LaunchMode.externalApplication)) await launchUrl(web, mode:LaunchMode.externalApplication);
  }
  @override
  Widget build(BuildContext context) {
    final hasLoc=(r['lat']??'').isNotEmpty&&(r['lng']??'').isNotEmpty;
    return Padding(padding:const EdgeInsets.symmetric(horizontal:2), child:Column(mainAxisAlignment:MainAxisAlignment.center, mainAxisSize:MainAxisSize.min, children:[
      Text(r['icon']??'✅', style:const TextStyle(fontSize:26)), const SizedBox(height:5),
      Text(r['label']??'Respuesta', textAlign:TextAlign.center, style:TextStyle(color:cmd.color, fontSize:13, fontWeight:FontWeight.w900, height:1.05), maxLines:2, overflow:TextOverflow.ellipsis),
      if ((r['value']??'').isNotEmpty) ...[const SizedBox(height:6),
        Container(width:double.infinity, padding:const EdgeInsets.symmetric(horizontal:6,vertical:6),
          decoration:BoxDecoration(color:Colors.black.withOpacity(0.16), borderRadius:BorderRadius.circular(9), border:Border.all(color:Colors.white.withOpacity(0.07))),
          child:Text(r['value']!, textAlign:TextAlign.center, style:TextStyle(color:Colors.white.withOpacity(0.82), fontSize:8.5, fontWeight:FontWeight.w700, height:1.12), maxLines:3, overflow:TextOverflow.ellipsis))],
      if ((r['time']??'').isNotEmpty) ...[const SizedBox(height:5), Text(r['time']!, style:TextStyle(color:Colors.white.withOpacity(0.38), fontSize:8.5, fontWeight:FontWeight.w700))],
      if (hasLoc) ...[const SizedBox(height:7), InkWell(onTap:_maps, borderRadius:BorderRadius.circular(999), child:Container(
        padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
        decoration:BoxDecoration(color:cmd.color.withOpacity(0.16), borderRadius:BorderRadius.circular(999), border:Border.all(color:cmd.color.withOpacity(0.45))),
        child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(Icons.map_rounded, color:cmd.color, size:12), const SizedBox(width:4), Text('Google Maps', style:TextStyle(color:cmd.color, fontSize:8.5, fontWeight:FontWeight.w900))])))],
    ]));
  }
}

class _Chip extends StatelessWidget {
  final String value, unit; final Color color;
  const _Chip(this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
    decoration:BoxDecoration(color:color.withOpacity(0.1), borderRadius:BorderRadius.circular(8), border:Border.all(color:color.withOpacity(0.25))),
    child:RichText(text:TextSpan(children:[
      TextSpan(text:value, style:TextStyle(color:color, fontSize:13, fontWeight:FontWeight.w900)),
      TextSpan(text:' $unit', style:TextStyle(color:color.withOpacity(0.65), fontSize:9, fontWeight:FontWeight.w600)),
    ])));
}

class _InfoDrawer extends StatelessWidget {
  final SessionData session; final double speed, battery; final String status, updated; final Color statusColor; final List<_SmsLog> log; final VoidCallback onLogout;
  const _InfoDrawer({required this.session, required this.speed, required this.battery, required this.status, required this.statusColor, required this.updated, required this.log, required this.onLogout});
  @override
  Widget build(BuildContext context) => Container(
    height:MediaQuery.of(context).size.height*0.68,
    decoration:const BoxDecoration(color:Color(0xFF111827), borderRadius:BorderRadius.vertical(top:Radius.circular(20))),
    child:Column(children:[
      const SizedBox(height:8),
      Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24, borderRadius:BorderRadius.circular(2))),
      const SizedBox(height:16),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20), child:Row(children:[
        Container(padding:const EdgeInsets.all(10), decoration:BoxDecoration(color:const Color(0xFFE8232A).withOpacity(0.12), borderRadius:BorderRadius.circular(10)),
          child:const Icon(Icons.location_on, color:Color(0xFFE8232A), size:22)),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text(session.clientName, style:const TextStyle(color:Colors.white, fontWeight:FontWeight.bold, fontSize:16), maxLines:1, overflow:TextOverflow.ellipsis),
          Text(session.username, style:const TextStyle(color:Color(0xFF6B7280), fontSize:12)),
        ])),
      ])),
      const SizedBox(height:16),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16), child:Row(children:[
        _DKpi('VELOCIDAD','${speed.toStringAsFixed(0)} km/h', speed>80?const Color(0xFFEF4444):const Color(0xFF22C55E)),
        const SizedBox(width:8),
        _DKpi('BATERÍA','${battery.toStringAsFixed(0)}%', battery<20?const Color(0xFFEF4444):const Color(0xFF34D399)),
        const SizedBox(width:8),
        _DKpi('ESTADO',status=='active'?'En ruta':status=='idle'?'Detenido':'Sin señal', statusColor),
      ])),
      const SizedBox(height:12),
      const Divider(color:Color(0xFF1F2937)),
      const Padding(padding:EdgeInsets.symmetric(horizontal:20,vertical:6), child:Row(children:[
        Icon(Icons.history, color:Color(0xFF4B5563), size:14), SizedBox(width:6),
        Text('ACTIVIDAD RECIENTE', style:TextStyle(color:Color(0xFF4B5563), fontSize:10, fontWeight:FontWeight.bold, letterSpacing:1)),
      ])),
      Expanded(child:log.isEmpty?const Center(child:Text('Sin actividad aún', style:TextStyle(color:Color(0xFF4B5563)))):
        ListView.builder(padding:const EdgeInsets.symmetric(horizontal:16), itemCount:log.length, itemBuilder:(_,i){
          final l=log[i]; final isSent=l.type=='sent';
          return Padding(padding:const EdgeInsets.only(bottom:9), child:Row(children:[
            Text(l.icon, style:const TextStyle(fontSize:15)), const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              Text(l.label, style:TextStyle(color:isSent?const Color(0xFF60A5FA):const Color(0xFF4ADE80), fontSize:12, fontWeight:FontWeight.bold)),
              if (l.value.isNotEmpty) Text(l.value, style:const TextStyle(color:Color(0xFF6B7280), fontSize:10), maxLines:2, overflow:TextOverflow.ellipsis),
            ])),
            Text('${l.time.hour.toString().padLeft(2,'0')}:${l.time.minute.toString().padLeft(2,'0')}', style:const TextStyle(color:Color(0xFF374151), fontSize:9)),
          ]));
        })),
      const Divider(color:Color(0xFF1F2937)),
      // Cambiar contraseña
      InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(token: session.token),
          ));
        },
        child: const Padding(padding: EdgeInsets.symmetric(vertical:12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children:[
            Icon(Icons.lock_reset_rounded, color: Color(0xFF00D4A0), size:18),
            SizedBox(width:8),
            Text('Cambiar contraseña', style: TextStyle(color: Color(0xFF00D4A0), fontSize:13, fontWeight:FontWeight.bold)),
          ]))),
      const Divider(color:Color(0xFF1F2937)),
      // Cerrar sesión
      InkWell(onTap:onLogout, child:const Padding(padding:EdgeInsets.symmetric(vertical:14),
        child:Row(mainAxisAlignment:MainAxisAlignment.center, children:[
          Icon(Icons.logout, color:Color(0xFFEF4444), size:18), SizedBox(width:8),
          Text('Cerrar sesión', style:TextStyle(color:Color(0xFFEF4444), fontSize:13, fontWeight:FontWeight.bold)),
        ]))),
    ]));
}

class _DKpi extends StatelessWidget {
  final String title, value; final Color color;
  const _DKpi(this.title, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child:Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:10),
    decoration:BoxDecoration(color:color.withOpacity(0.08), borderRadius:BorderRadius.circular(12), border:Border.all(color:color.withOpacity(0.25))),
    child:Column(children:[
      Text(title, style:const TextStyle(color:Color(0xFF6B7280), fontSize:9, fontWeight:FontWeight.bold), maxLines:1, overflow:TextOverflow.ellipsis),
      const SizedBox(height:4),
      Text(value, style:TextStyle(color:color, fontSize:13, fontWeight:FontWeight.w900), maxLines:1, overflow:TextOverflow.ellipsis),
    ])));
}