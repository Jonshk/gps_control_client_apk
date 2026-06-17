// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../widgets/orbital_logo.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

// ── Colores dark gold ─────────────────────────────────────────
const _gold = Color(0xFFD4A853);
const _goldDim = Color(0x22D4A853);
const _bg = Color(0xFF0E0E0E);
const _bgCard = Color(0xFF141414);
const _bgCard2 = Color(0xFF161616);
const _border = Color(0xFF1E1E1E);
const _border2 = Color(0xFF242424);
const _textPri = Colors.white;
const _textHint = Color(0xFF555555);
const _textFaint = Color(0xFF333333);
const _green = Color(0xFF4CAF50);
const _red = Color(0xFFE24B4A);

// ── Comandos GPS ──────────────────────────────────────────────
class _GpsCmd {
  final String key, label, sublabel;
  final IconData icon;
  final Color accentColor;
  const _GpsCmd({
    required this.key,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.accentColor,
  });
}

const _cmds = [
  _GpsCmd(
    key: 'locate',
    label: 'Ubicación',
    sublabel: 'Obtener posición GPS',
    icon: Icons.my_location_rounded,
    accentColor: _gold,
  ),
  _GpsCmd(
    key: 'stop_engine',
    label: 'Apagar motor',
    sublabel: 'Cortar alimentación',
    icon: Icons.power_settings_new_rounded,
    accentColor: _red,
  ),
  _GpsCmd(
    key: 'start_engine',
    label: 'Enc. motor',
    sublabel: 'Restaurar alimentación',
    icon: Icons.play_circle_outline_rounded,
    accentColor: _green,
  ),
];

// ── Log de actividad ──────────────────────────────────────────
class _Log {
  final String type, label, value, icon;
  final DateTime time;
  _Log({
    required this.type,
    required this.label,
    required this.value,
    required this.icon,
    required this.time,
  });
}

enum _CmdState { idle, sending, waiting, answered }

// ── HomeScreen ────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final SessionData session;
  const HomeScreen({super.key, required this.session});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final WebSocketService _ws = WebSocketService();
  StreamSubscription<PositionUpdate>? _wsSub;
  StreamSubscription<bool>? _wsConnSub;

  double? _lat, _lng;
  double _speed = 0, _heading = 0, _battery = 100;
  String _status = 'offline';
  bool _wsLive = false;
  String _updated = '--';

  final List<_Log> _log = [];
  final Map<String, _CmdState> _state = {};
  final Map<String, Map<String, String>> _resp = {};
  final Map<String, AnimationController> _pulse = {};
  Timer? _pollTimer;
  double _mapFlex = 0.55;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  Future<void> _connectWs() async {
    _wsConnSub = _ws.connectionStream.listen((connected) {
      if (mounted) setState(() => _wsLive = connected);
    });
    await _ws.connectVehicle(
      deviceId: widget.session.vehicleId ?? widget.session.deviceId ?? '',
      clientId: widget.session.clientId,
      wsToken: widget.session.wsToken,
    );
    _wsSub = _ws.positionStream?.listen((u) {
      if (!mounted) return;
      setState(() {
        _wsLive = true;
        _lat = u.lat;
        _lng = u.lng;
        _speed = u.speed;
        _heading = u.heading;
        _battery = u.battery;
        _status = u.vehicleStatus;
        _updated = _fmt(u.timestamp);
      });
      if (_lat != null && _lng != null)
        _map.move(LatLng(_lat!, _lng!), _map.camera.zoom);
    });
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--';
    }
  }

  String _clock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _wsConnSub?.cancel();
    _ws.dispose();
    for (final c in _pulse.values) c.dispose();
    super.dispose();
  }

  Color get _sc => _status == 'active'
      ? _green
      : _status == 'idle'
          ? const Color(0xFF8B6A1A)
          : _red;

  Future<void> _send(String key) async {
    HapticFeedback.mediumImpact();
    _pulse[key] ??= AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    final cmd = _cmds.firstWhere((c) => c.key == key);
    setState(() {
      _state[key] = _CmdState.sending;
      _resp.remove(key);
      _log.insert(
          0,
          _Log(
              type: 'sent',
              label: cmd.label,
              value: 'Enviando comando...',
              icon: '📤',
              time: DateTime.now()));
    });
    try {
      await ApiService.sendCommand(widget.session.token, key);
      if (!mounted) return;
      setState(() => _state[key] = _CmdState.waiting);
      _startPolling(key);
    } catch (e) {
      if (!mounted) return;
      _pulse[key]?.stop();
      setState(() {
        _state[key] = _CmdState.answered;
        _resp[key] = {
          'icon': '❌',
          'label': 'Error',
          'value': e.toString().replaceFirst('Exception: ', '')
        };
      });
    }
  }

  void _startPolling(String key) {
    _pollTimer?.cancel();
    int count = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (t) async {
      count++;
      if (count > 22) {
        t.cancel();
        if (mounted && _state[key] == _CmdState.waiting) {
          _pulse[key]?.stop();
          setState(() {
            _state[key] = _CmdState.answered;
            _resp[key] = {
              'icon': '⏱️',
              'label': 'Sin respuesta',
              'value': 'Tiempo agotado'
            };
          });
        }
        return;
      }
      try {
        final responses = await ApiService.getResponses(widget.session.token);
        if (responses.isEmpty || !mounted) return;
        final latest = responses.first;
        final dt = DateTime.tryParse(latest['received_at'] as String? ?? '');
        if (dt != null && DateTime.now().toUtc().difference(dt).inMinutes < 2) {
          t.cancel();
          _pulse[key]?.stop();
          final body = latest['body'] as String? ?? '';
          final parsed = _parseSms(body);
          if (!mounted) return;
          setState(() {
            _state[key] = _CmdState.answered;
            _resp[key] = parsed;
            _log.insert(
                0,
                _Log(
                    type: 'received',
                    label: parsed['label']!,
                    value: parsed['value']!,
                    icon: parsed['icon']!,
                    time: DateTime.now()));
            if (_log.length > 50) _log.removeLast();
            final lat = double.tryParse(parsed['lat'] ?? '');
            final lng = double.tryParse(parsed['lng'] ?? '');
            if (lat != null && lng != null) {
              _lat = lat;
              _lng = lng;
              _status = 'active';
              _updated = _clock(DateTime.now());
              _map.move(LatLng(lat, lng), 16);
            }
          });
        }
      } catch (_) {}
    });
  }

  Map<String, String> _parseSms(String body) {
    final b = body.toLowerCase();
    final latM = RegExp(r'lat[:= ]+([-\d.]+)', caseSensitive: false).firstMatch(body);
    final lngM = RegExp(r'(?:lon|lng|long)[:= ]+([-\d.]+)', caseSensitive: false).firstMatch(body);
    if (latM != null && lngM != null)
      return {'icon': '📍', 'label': 'Ubicación GPS', 'value': '${latM.group(1)}, ${lngM.group(1)}', 'lat': latM.group(1) ?? '', 'lng': lngM.group(1) ?? ''};
    final mapM = RegExp(r'q=([-\d.]+),\s*([-\d.]+)', caseSensitive: false).firstMatch(body);
    if (mapM != null)
      return {'icon': '📍', 'label': 'Ubicación GPS', 'value': '${mapM.group(1)}, ${mapM.group(2)}', 'lat': mapM.group(1) ?? '', 'lng': mapM.group(2) ?? ''};
    if (b.contains('stopelec ok')) return {'icon': '🔴', 'label': 'Motor apagado', 'value': 'Corte aplicado'};
    if (b.contains('supplyelec ok')) return {'icon': '🟢', 'label': 'Motor encendido', 'value': 'Alimentación restaurada'};
    if (b.contains('fix ok')) return {'icon': '📡', 'label': 'Tracking activo', 'value': 'Enviando posición'};
    if (b.contains('nofix ok')) return {'icon': '⏹️', 'label': 'Tracking detenido', 'value': 'OK'};
    if (b.contains('move ok')) return {'icon': '🚨', 'label': 'Alerta movimiento', 'value': 'Activada'};
    if (b.contains('reset ok')) return {'icon': '🔄', 'label': 'GPS reiniciado', 'value': 'OK'};
    if (b.contains('pwdfail')) return {'icon': '⚠️', 'label': 'Contraseña incorrecta', 'value': 'PWDFAIL'};
    final bat = RegExp(r'bat[:= ]+\s*(\d+)', caseSensitive: false).firstMatch(body);
    if (bat != null) return {'icon': '🔋', 'label': 'Batería', 'value': '${bat.group(1)}%'};
    return {'icon': '💬', 'label': 'Respuesta GPS', 'value': body.length > 70 ? '${body.substring(0, 70)}...' : body};
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _openDrawer() => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _Drawer(
          session: widget.session,
          speed: _speed,
          battery: _battery,
          status: _status,
          statusColor: _sc,
          updated: _updated,
          log: _log,
          onLogout: () async {
            Navigator.pop(context);
            await ApiService.clearSession();
            if (mounted) _goToLogin();
          },
          onChangePassword: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangePasswordScreen(token: widget.session.token)));
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final safeH = screenH -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        56;
    final mapH = (safeH * _mapFlex).clamp(120.0, safeH - 160);
    final panelH = safeH - mapH - 14;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── TopBar ───────────────────────────────────────────
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: _openDrawer,
                child: const OrbitalLogoMini(size: 36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.session.clientName,
                      style: const TextStyle(
                          color: _textPri,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Actualizado: $_updated',
                      style: const TextStyle(color: _textFaint, fontSize: 9),
                    ),
                  ],
                ),
              ),
              _KpiChip('${_speed.toStringAsFixed(0)}', 'km/h',
                  _speed > 80 ? _red : _green),
              const SizedBox(width: 6),
              _KpiChip('${_battery.toStringAsFixed(0)}', '%bat',
                  _battery < 20 ? _red : _green),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _wsLive ? _green : _red,
                      boxShadow: [
                        BoxShadow(
                          color: (_wsLive ? _green : _red).withOpacity(.7),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _wsLive ? 'LIVE' : 'OFF',
                    style: TextStyle(
                        color: _wsLive ? _green : _red,
                        fontSize: 7,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ]),
          ),

          // ── Mapa ─────────────────────────────────────────────
          SizedBox(
            height: mapH,
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                    initialCenter: _lat != null
                        ? LatLng(_lat!, _lng!)
                        : const LatLng(-2.1962, -79.8956),
                    initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gvam.gpscontrol',
                  ),
                  if (_lat != null && _lng != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(_lat!, _lng!),
                        width: 48,
                        height: 48,
                        child: Transform.rotate(
                          angle: _heading * 3.14159 / 180,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _sc.withOpacity(.15),
                              border: Border.all(color: _sc, width: 2),
                            ),
                            child: Icon(Icons.navigation_rounded, color: _sc, size: 28),
                          ),
                        ),
                      ),
                    ]),
                ],
              ),

              // Status pill
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _bg.withOpacity(.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _sc.withOpacity(.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _sc),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _status == 'active' ? 'En ruta' : _status == 'idle' ? 'Detenido' : 'Sin señal',
                      style: TextStyle(color: _sc, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
              ),

              // Botón menú
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _openDrawer,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _bg.withOpacity(.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border2),
                    ),
                    child: const Icon(Icons.menu_rounded, color: _textHint, size: 18),
                  ),
                ),
              ),
            ]),
          ),

          // ── Divisor arrastrable ───────────────────────────────
          GestureDetector(
            onVerticalDragUpdate: (d) {
              setState(() {
                final delta = d.delta.dy / safeH;
                _mapFlex = (_mapFlex + delta).clamp(0.2, 0.75);
              });
            },
            child: Container(
              height: 14,
              color: _bgCard2,
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),

          // ── Panel comandos ────────────────────────────────────
          SizedBox(
            height: panelH,
            child: _CmdPanel(
              cmds: _cmds,
              state: _state,
              resp: _resp,
              pulse: _pulse,
              onSend: _send,
              log: _log,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Cmd Card ──────────────────────────────────────────────────
class _CmdCard extends StatefulWidget {
  final _GpsCmd cmd;
  final bool isWait, isAns;
  final Map<String, String>? resp;
  final VoidCallback? onTap;
  const _CmdCard({
    required this.cmd,
    required this.isWait,
    required this.isAns,
    required this.resp,
    required this.onTap,
  });
  @override
  State<_CmdCard> createState() => _CmdCardState();
}

class _CmdCardState extends State<_CmdCard> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cmd = widget.cmd;
    final resp = widget.resp;
    final isWait = widget.isWait;
    final isAns = widget.isAns;
    final color = cmd.accentColor;

    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onTap!();
            },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..translate(0.0, _pressed ? 2.0 : 0.0),
        transformAlignment: Alignment.center,
        height: 112,
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWait || isAns ? color.withOpacity(.4) : _border2,
            width: 1,
          ),
          boxShadow: isWait
              ? [BoxShadow(color: color.withOpacity(.15), blurRadius: 16, spreadRadius: 2)]
              : _pressed
                  ? []
                  : [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(children: [
          // Glow fondo activo
          if (isWait || isAns)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        color.withOpacity(.07 + _glowCtrl.value * .05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icono
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(.08),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: color.withOpacity(.18), width: 1),
                      ),
                      child: isWait
                          ? Padding(
                              padding: const EdgeInsets.all(9),
                              child: CircularProgressIndicator(color: color, strokeWidth: 2))
                          : isAns
                              ? Center(child: Text(resp!['icon'] ?? '✅', style: const TextStyle(fontSize: 18)))
                              : Icon(cmd.icon, color: color, size: 19),
                    ),

                    // LED
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isWait
                              ? Color.lerp(const Color(0xFFD4A853), const Color(0xFFFFE066), _glowCtrl.value)
                              : isAns
                                  ? color
                                  : const Color(0xFF2A2A2A),
                          boxShadow: isWait || isAns
                              ? [
                                  BoxShadow(
                                    color: (isWait ? _gold : color).withOpacity(.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Text(
                  isAns ? (resp!['label'] ?? cmd.label) : cmd.label,
                  style: TextStyle(
                    color: isAns || isWait ? color : _textPri,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isAns
                      ? (resp!['value'] ?? '')
                      : isWait
                          ? 'Esperando respuesta...'
                          : cmd.sublabel,
                  style: TextStyle(
                    color: _textPri.withOpacity(.28),
                    fontSize: 9,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── KPI Chip ──────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String val, unit;
  final Color color;
  const _KpiChip(this.val, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(val, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(unit, style: TextStyle(color: color.withOpacity(.5), fontSize: 7)),
        ]),
      );
}

// ── Panel de comandos ─────────────────────────────────────────
class _CmdPanel extends StatefulWidget {
  final List<_GpsCmd> cmds;
  final Map<String, _CmdState> state;
  final Map<String, Map<String, String>> resp;
  final Map<String, AnimationController> pulse;
  final Future<void> Function(String) onSend;
  final List<_Log> log;
  const _CmdPanel({
    required this.cmds,
    required this.state,
    required this.resp,
    required this.pulse,
    required this.onSend,
    required this.log,
  });
  @override
  State<_CmdPanel> createState() => _CmdPanelState();
}

class _CmdPanelState extends State<_CmdPanel> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: _bgCard2,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Column(children: [
          TabBar(
            controller: _tab,
            indicatorColor: _gold,
            labelColor: _gold,
            unselectedLabelColor: _textHint,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5),
            tabs: [
              const Tab(text: 'COMANDOS'),
              Tab(
                text: widget.log.isEmpty
                    ? 'RESPUESTAS'
                    : 'RESPUESTAS (${widget.log.where((l) => l.type == "received").length})',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              // Tab Comandos
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                child: Row(
                  children: widget.cmds.map((cmd) {
                    final st = widget.state[cmd.key] ?? _CmdState.idle;
                    final isWait = st == _CmdState.sending || st == _CmdState.waiting;
                    final isAns = st == _CmdState.answered && widget.resp[cmd.key] != null;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _CmdCard(
                          cmd: cmd,
                          isWait: isWait,
                          isAns: isAns,
                          resp: widget.resp[cmd.key],
                          onTap: isWait ? null : () => widget.onSend(cmd.key),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Tab Respuestas
              widget.log.isEmpty
                  ? const Center(
                      child: Text(
                        'Envía un comando\npara ver la respuesta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textHint, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: widget.log.length,
                      itemBuilder: (_, i) {
                        final l = widget.log[i];
                        final isSent = l.type == 'sent';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSent
                                ? _gold.withOpacity(.06)
                                : _green.withOpacity(.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSent ? _gold.withOpacity(.2) : _green.withOpacity(.2),
                            ),
                          ),
                          child: Row(children: [
                            Text(l.icon, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.label,
                                      style: TextStyle(
                                          color: isSent ? _gold : _green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                  Text(l.value,
                                      style: const TextStyle(color: _textHint, fontSize: 9),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Text(
                              '${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: _textFaint, fontSize: 9),
                            ),
                          ]),
                        );
                      },
                    ),
            ]),
          ),
        ]),
      );
}

// ── Drawer ────────────────────────────────────────────────────
class _Drawer extends StatelessWidget {
  final SessionData session;
  final double speed, battery;
  final String status, updated;
  final Color statusColor;
  final List<_Log> log;
  final VoidCallback onLogout, onChangePassword;
  const _Drawer({
    required this.session,
    required this.speed,
    required this.battery,
    required this.status,
    required this.statusColor,
    required this.updated,
    required this.log,
    required this.onLogout,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * .68,
        decoration: const BoxDecoration(
          color: _bgCard2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),

          // Header usuario
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withOpacity(.3)),
                ),
                child: Center(
                  child: Text(
                    session.clientName.isNotEmpty ? session.clientName[0] : '?',
                    style: const TextStyle(
                        color: _gold, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.clientName,
                      style: const TextStyle(
                          color: _textPri, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(session.username,
                      style: const TextStyle(color: _textHint, fontSize: 12)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // KPIs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _DKpi('VELOCIDAD', '${speed.toStringAsFixed(0)} km/h', speed > 80 ? _red : _green),
              const SizedBox(width: 8),
              _DKpi('BATERÍA', '${battery.toStringAsFixed(0)}%', battery < 20 ? _red : _green),
              const SizedBox(width: 8),
              _DKpi('ESTADO',
                  status == 'active' ? 'En ruta' : status == 'idle' ? 'Detenido' : 'Sin señal',
                  statusColor),
            ]),
          ),

          const SizedBox(height: 12),
          const Divider(color: _border),

          // Actividad reciente label
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Row(children: [
              Icon(Icons.history_rounded, color: _textFaint, size: 13),
              SizedBox(width: 5),
              Text('ACTIVIDAD RECIENTE',
                  style: TextStyle(
                      color: _textFaint, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ]),
          ),

          Expanded(
            child: log.isEmpty
                ? const Center(
                    child: Text('Sin actividad aún',
                        style: TextStyle(color: _textHint, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: log.length,
                    itemBuilder: (_, i) {
                      final l = log[i];
                      final isSent = l.type == 'sent';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 6, height: 6,
                            margin: const EdgeInsets.only(top: 4, right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSent ? _gold : _green,
                            ),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.label,
                                  style: TextStyle(
                                      color: isSent ? _gold : _green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800)),
                              Text(l.value,
                                  style: const TextStyle(color: _textHint, fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                          Text(
                            '${l.time.hour.toString().padLeft(2, '0')}:${l.time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: _textFaint, fontSize: 9),
                          ),
                        ]),
                      );
                    },
                  ),
          ),

          const Divider(color: _border),

          // Botones acción
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onChangePassword,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gold.withOpacity(.25)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.lock_reset_rounded, color: _gold, size: 16),
                      SizedBox(width: 6),
                      Text('Cambiar clave',
                          style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withOpacity(.25)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.logout_rounded, color: _red, size: 16),
                      SizedBox(width: 6),
                      Text('Cerrar sesión',
                          style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _DKpi extends StatelessWidget {
  final String title, value;
  final Color color;
  const _DKpi(this.title, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(.18)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(title,
                style: const TextStyle(color: _textFaint, fontSize: 8, letterSpacing: .5)),
          ]),
        ),
      );
}