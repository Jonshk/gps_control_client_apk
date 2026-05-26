import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final SessionModel session;
  const HomeScreen({super.key, required this.session});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VehicleStatus? _status;
  bool _loadingStatus = true;
  Timer? _timer;
  final _mapCtrl = MapController();
  GpsCommand? _sendingCmd;
  String? _cmdResult;
  bool _cmdSuccess = true;

  // ── Respuestas recibidas del GPS ──────────────────────────────────────
  final List<GpsResponse> _responses = [];
  bool _showResponses = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());

    // Iniciar polling de respuestas del GPS via backend
    SmsService.startListening(
      token: widget.session.token,
      onResponse: (response) {
        if (!mounted) return;
        setState(() {
          _responses.insert(0, response);
          if (_responses.length > 50) _responses.removeLast();
          _showResponses = true;
        });
        _fetchStatus();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    SmsService.stopListening();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final s = await ApiService.getStatus(widget.session.token);
      if (!mounted) return;
      setState(() {
        _status = s;
        _loadingStatus = false;
      });
      _mapCtrl.move(LatLng(s.lat, s.lng), 15);
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _sendCommand(GpsCommand cmd) async {
    setState(() {
      _sendingCmd = cmd;
      _cmdResult = null;
    });
    final result = await SmsService.sendCommand(cmd, widget.session.token);
    if (!mounted) return;
    setState(() {
      _sendingCmd = null;
      _cmdResult = result.message;
      _cmdSuccess = result.isSuccess;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _cmdResult = null);
    });
  }

  Future<void> _logout() async {
    await ApiService.logout(widget.session.token);
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _openSupport() async {
    const msg = 'Hola, necesito soporte con mi GPS Control EC.';
    final uri = Uri.parse(
        'https://wa.me/$kSupportPhone?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      appBar: AppBar(
        backgroundColor: AppTheme.dark,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.session.vehicleName.isNotEmpty
                ? widget.session.vehicleName
                : 'Mi vehículo',
            style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          Text(widget.session.clientName,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w400)),
        ]),
        actions: [
          // Botón respuestas GPS con badge
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.sms_outlined,
                  color: _responses.isNotEmpty
                      ? AppTheme.teal
                      : const Color(0x66F0F6FF),
                ),
                onPressed: () =>
                    setState(() => _showResponses = !_showResponses),
                tooltip: 'Respuestas del GPS',
              ),
              if (_responses.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0x66F0F6FF)),
            onPressed: _fetchStatus,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.support_agent, color: Color(0x66F0F6FF)),
            onPressed: _openSupport,
            tooltip: 'Soporte WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0x66F0F6FF)),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Column(children: [
        // ── Mapa ─────────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Stack(children: [
            _MapView(status: _status, mapCtrl: _mapCtrl),

            if (_loadingStatus)
              Container(
                color: AppTheme.dark.withOpacity(0.6),
                child: const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.teal, strokeWidth: 2)),
              ),

            if (_status != null)
              Positioned(
                  top: 12,
                  right: 12,
                  child: _StatusBadge(status: _status!.status)),

            // Badge "conectado al backend"
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.dark.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppTheme.teal.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppTheme.teal, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  const Text('Conectado',
                      style: TextStyle(
                          color: AppTheme.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Panel respuestas GPS ──────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showResponses
              ? _ResponsesPanel(
                  responses: _responses,
                  onClose: () => setState(() => _showResponses = false),
                )
              : const SizedBox.shrink(),
        ),

        // ── KPIs ──────────────────────────────────────────────────────
        if (_status != null) _KpiRow(status: _status!),

        // ── Resultado de envío ────────────────────────────────────────
        if (_cmdResult != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (_cmdSuccess ? AppTheme.teal : AppTheme.red)
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (_cmdSuccess ? AppTheme.teal : AppTheme.red)
                      .withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(
                  _cmdSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: _cmdSuccess ? AppTheme.teal : AppTheme.red,
                  size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_cmdResult!,
                      style: TextStyle(
                          color: _cmdSuccess
                              ? AppTheme.teal
                              : AppTheme.red,
                          fontSize: 13))),
            ]),
          ),

        // ── Botones de comandos ───────────────────────────────────────
        Container(
          color: AppTheme.dark2,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Column(children: [
            Row(children: [
              _CmdBtn(
                  cmd: GpsCommand.locate,
                  sending: _sendingCmd,
                  onTap: _sendCommand),
              const SizedBox(width: 8),
              _CmdBtn(
                  cmd: GpsCommand.moveAlert,
                  sending: _sendingCmd,
                  onTap: _sendCommand),
              const SizedBox(width: 8),
              _CmdBtn(
                  cmd: GpsCommand.speedAlert,
                  sending: _sendingCmd,
                  onTap: _sendCommand),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _CmdBtn(
                  cmd: GpsCommand.stopEngine,
                  sending: _sendingCmd,
                  onTap: _sendCommand,
                  danger: true),
              const SizedBox(width: 8),
              _CmdBtn(
                  cmd: GpsCommand.resumeEngine,
                  sending: _sendingCmd,
                  onTap: _sendCommand),
              const SizedBox(width: 8),
              _CmdBtn(
                  cmd: GpsCommand.online,
                  sending: _sendingCmd,
                  onTap: _sendCommand),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Panel de respuestas del GPS ───────────────────────────────────────────

class _ResponsesPanel extends StatelessWidget {
  final List<GpsResponse> responses;
  final VoidCallback onClose;
  const _ResponsesPanel({required this.responses, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      color: AppTheme.dark2,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            const Icon(Icons.sms_outlined, color: AppTheme.teal, size: 16),
            const SizedBox(width: 8),
            const Text('Respuestas del GPS',
                style: TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (responses.isEmpty)
              Text('Esperando...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 11)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClose,
              child: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.4), size: 20),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF1E293B)),
        if (responses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Envía un comando y aquí aparecerá la respuesta',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 12),
                textAlign: TextAlign.center),
          )
        else
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: responses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _ResponseItem(r: responses[i]),
            ),
          ),
      ]),
    );
  }
}

class _ResponseItem extends StatelessWidget {
  final GpsResponse r;
  const _ResponseItem({required this.r});

  @override
  Widget build(BuildContext context) {
    final time =
        '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.teal.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.teal.withOpacity(0.15)),
      ),
      child: Row(children: [
        Expanded(
            child: Text(r.parsed,
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500))),
        const SizedBox(width: 8),
        Text(time,
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 10)),
      ]),
    );
  }
}

// ── Mapa ──────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  final VehicleStatus? status;
  final MapController mapCtrl;
  const _MapView({required this.status, required this.mapCtrl});

  @override
  Widget build(BuildContext context) {
    final center = status != null
        ? LatLng(status!.lat, status!.lng)
        : const LatLng(-2.1704, -79.8895);

    return FlutterMap(
      mapController: mapCtrl,
      options: MapOptions(initialCenter: center, initialZoom: 14.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gpscontrolec.client',
        ),
        if (status != null)
          MarkerLayer(markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: _VehicleMarker(status: status!.status),
            ),
          ]),
      ],
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  final String status;
  const _VehicleMarker({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? AppTheme.teal
        : status == 'idle'
            ? const Color(0xFF60A5FA)
            : const Color(0xFFF87171);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)
        ],
      ),
      child:
          const Icon(Icons.directions_car, color: Colors.white, size: 22),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('En ruta', AppTheme.teal),
      'idle' => ('En espera', Color(0xFF60A5FA)),
      _ => ('Sin señal', Color(0xFFF87171)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.dark.withOpacity(0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final VehicleStatus status;
  const _KpiRow({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.dark2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        _Kpi(
            label: 'Velocidad',
            value: '${status.speed.toInt()} km/h',
            icon: Icons.speed,
            color: AppTheme.teal),
        const SizedBox(width: 8),
        _Kpi(
            label: 'Geocerca',
            value: status.geofence ?? 'Ninguna',
            icon: Icons.location_on_outlined,
            color: const Color(0xFF60A5FA)),
        const SizedBox(width: 8),
        _Kpi(
            label: 'Estado',
            value: status.statusLabel,
            icon: Icons.circle,
            color: status.statusColor),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Kpi(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.dark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── Botón de comando ──────────────────────────────────────────────────────

class _CmdBtn extends StatelessWidget {
  final GpsCommand cmd;
  final GpsCommand? sending;
  final Future<void> Function(GpsCommand) onTap;
  final bool danger;

  const _CmdBtn({
    required this.cmd,
    required this.sending,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSending = sending == cmd;
    final color = switch (cmd) {
      GpsCommand.stopEngine   => AppTheme.red,
      GpsCommand.resumeEngine => AppTheme.teal,
      GpsCommand.locate       => AppTheme.teal,
      GpsCommand.moveAlert    => const Color(0xFFFBBF24),
      GpsCommand.speedAlert   => const Color(0xFFFB923C),
      GpsCommand.online       => const Color(0xFF60A5FA),
      GpsCommand.monitor      => const Color(0xFFA78BFA),
    };
    final icon = switch (cmd) {
      GpsCommand.locate       => Icons.my_location,
      GpsCommand.stopEngine   => Icons.power_settings_new,
      GpsCommand.resumeEngine => Icons.play_circle_outline,
      GpsCommand.moveAlert    => Icons.notifications_active_outlined,
      GpsCommand.speedAlert   => Icons.speed,
      GpsCommand.online       => Icons.wifi_tethering,
      GpsCommand.monitor      => Icons.mic_none,
    };

    return Expanded(
      child: GestureDetector(
        onTap: sending != null ? null : () => onTap(cmd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 68,
          decoration: BoxDecoration(
            color: color.withOpacity(isSending ? 0.05 : 0.09),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: color.withOpacity(isSending ? 0.3 : 0.18)),
          ),
          child: isSending
              ? Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 2)))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 5),
                    Text(cmd.label,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 2),
                  ]),
        ),
      ),
    );
  }
}