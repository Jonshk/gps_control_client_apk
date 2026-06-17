// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class PositionUpdate {
  final String deviceId;
  final String vehicleName;
  final String plate;
  final double lat;
  final double lng;
  final double speed;
  final double heading;
  final double battery;
  final String vehicleStatus;
  final String timestamp;

  PositionUpdate({
    required this.deviceId,
    required this.vehicleName,
    required this.plate,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.battery,
    required this.vehicleStatus,
    required this.timestamp,
  });

  factory PositionUpdate.fromJson(Map<String, dynamic> json) {
    return PositionUpdate(
      deviceId: json['device_id'] ?? '',
      vehicleName: json['vehicle_name'] ?? '',
      plate: json['plate'] ?? '',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      speed: (json['speed'] ?? 0.0).toDouble(),
      heading: (json['heading'] ?? 0.0).toDouble(),
      battery: (json['battery'] ?? 100.0).toDouble(),
      vehicleStatus: json['status'] ?? 'offline',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class WebSocketService {
  static const String _baseUrl = 'ws://10.0.2.2:8000';

  WebSocketChannel? _channel;
  StreamController<PositionUpdate>? _positionController;
  StreamController<bool>? _connectionController;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _intentionalClose = false;
  String? _lastWsUrl;

  // Stream de posiciones
  Stream<PositionUpdate>? get positionStream => _positionController?.stream;

  // Stream de estado de conexión (true = conectado, false = desconectado)
  Stream<bool> get connectionStream {
    _connectionController ??= StreamController<bool>.broadcast();
    return _connectionController!.stream;
  }

  // ─── Conectar WebSocket INDIVIDUAL ───────────────────
  Future<void> connectVehicle({
    required String deviceId,
    required String clientId,
    required String wsToken,
  }) async {
    final url = '$_baseUrl/ws/vehicle/$deviceId?token=$wsToken';
    await _connect(url);
  }

  // ─── Conectar WebSocket FLOTA ─────────────────────────
  Future<void> connectFleet({
    required String clientId,
    required String wsToken,
  }) async {
    final url = '$_baseUrl/ws/fleet/$clientId?token=$wsToken';
    await _connect(url);
  }

  Future<void> _connect(String url) async {
    _intentionalClose = false;
    _lastWsUrl = url;
    _positionController?.close();
    _positionController = StreamController<PositionUpdate>.broadcast();
    _connectionController ??= StreamController<bool>.broadcast();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connectionController?.add(true);

      _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['type'] == 'position_update') {
              final update = PositionUpdate.fromJson(data);
              _positionController?.add(update);
            }
          } catch (_) {}
        },
        onDone: () {
          _stopPing();
          _connectionController?.add(false);
          if (!_intentionalClose) _scheduleReconnect();
        },
        onError: (_) {
          _stopPing();
          _connectionController?.add(false);
          if (!_intentionalClose) _scheduleReconnect();
        },
      );

      _startPing();
    } catch (e) {
      _connectionController?.add(false);
      if (!_intentionalClose) _scheduleReconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _channel?.sink.add('ping');
      } catch (_) {}
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_lastWsUrl != null && !_intentionalClose) {
        _connect(_lastWsUrl!);
      }
    });
  }

  void disconnect() {
    _intentionalClose = true;
    _stopPing();
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _positionController?.close();
    _channel = null;
    _positionController = null;
  }

  // Alias de disconnect para compatibilidad con home_screen.dart
  void dispose() {
    disconnect();
    _connectionController?.close();
    _connectionController = null;
  }
}