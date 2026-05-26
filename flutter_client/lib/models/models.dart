import 'package:flutter/material.dart';

// ─── Sesión del cliente ───────────────────────────────────────────────────

class SessionModel {
  final String token;
  final String clientName;
  final String vehicleName;
  final String vehicleId;
  final String simNumber;

  const SessionModel({
    required this.token,
    required this.clientName,
    required this.vehicleName,
    required this.vehicleId,
    required this.simNumber,
  });

  factory SessionModel.fromJson(Map<String, dynamic> j) => SessionModel(
        token:       j['token']        ?? '',
        clientName:  j['client_name']  ?? '',
        vehicleName: j['vehicle_name'] ?? '',
        vehicleId:   j['vehicle_id']   ?? '',
        simNumber:   j['sim_number']   ?? '',
      );

  Map<String, dynamic> toJson() => {
        'token':        token,
        'client_name':  clientName,
        'vehicle_name': vehicleName,
        'vehicle_id':   vehicleId,
        'sim_number':   simNumber,
      };
}

// ─── Estado del vehículo ──────────────────────────────────────────────────

class VehicleStatus {
  final double lat;
  final double lng;
  final double speed;
  final String status;
  final String? geofence;

  const VehicleStatus({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.status,
    this.geofence,
  });

  factory VehicleStatus.fromJson(Map<String, dynamic> j) => VehicleStatus(
        lat:      (j['lat']   ?? -2.1704).toDouble(),
        lng:      (j['lng']   ?? -79.8895).toDouble(),
        speed:    (j['speed'] ?? 0).toDouble(),
        status:   j['status'] ?? 'offline',
        geofence: j['geofence'],
      );

  String get statusLabel => switch (status) {
        'active' => 'En ruta',
        'idle'   => 'En espera',
        _        => 'Sin señal',
      };

  Color get statusColor => switch (status) {
        'active' => const Color(0xFF2DD4BF),
        'idle'   => const Color(0xFF60A5FA),
        _        => const Color(0xFFF87171),
      };
}

// ─── Comandos GPS ─────────────────────────────────────────────────────────

enum GpsCommand {
  locate,
  stopEngine,
  resumeEngine,
  moveAlert,
  speedAlert,
  online,
  monitor,
}

extension GpsCommandX on GpsCommand {
  /// Clave que se envía al backend en /app/command
  String get apiKey => switch (this) {
        GpsCommand.locate       => 'locate',
        GpsCommand.stopEngine   => 'stop_engine',
        GpsCommand.resumeEngine => 'start_engine',
        GpsCommand.moveAlert    => 'move_alert',
        GpsCommand.speedAlert   => 'speed_alert',
        GpsCommand.online       => 'online',
        GpsCommand.monitor      => 'monitor',
      };

  String get label => switch (this) {
        GpsCommand.locate       => 'Localizar',
        GpsCommand.stopEngine   => 'Cortar\nmotor',
        GpsCommand.resumeEngine => 'Reanudar\nmotor',
        GpsCommand.moveAlert    => 'Alerta\nmovimiento',
        GpsCommand.speedAlert   => 'Alerta\nvelocidad',
        GpsCommand.online       => 'Modo\nactivo',
        GpsCommand.monitor      => 'Escucha\nremota',
      };
}

// ─── Resultado de envío de comando ───────────────────────────────────────

class SmsResult {
  final bool isSuccess;
  final String message;
  const SmsResult({required this.isSuccess, required this.message});
}

// ─── Respuesta recibida del GPS ───────────────────────────────────────────

class GpsResponse {
  final String raw;
  final DateTime timestamp;
  final String parsed;

  const GpsResponse({
    required this.raw,
    required this.timestamp,
    required this.parsed,
  });

  factory GpsResponse.fromRaw(String raw) {
    final t = raw.toLowerCase();
    String parsed;

    if (t.contains('lat:') || t.contains('speed:') || t.contains('http')) {
      final latReg = RegExp(r'lat[:\s]*([\-\d\.]+)', caseSensitive: false);
      final lngReg = RegExp(r'lon(?:g)?[:\s]*([\-\d\.]+)', caseSensitive: false);
      final lat = latReg.firstMatch(raw)?.group(1);
      final lng = lngReg.firstMatch(raw)?.group(1);
      parsed = (lat != null && lng != null)
          ? '📍 Posición: $lat, $lng'
          : '📍 Posición recibida';
    } else if (t.contains('stop engine') || t.contains('acc off')) {
      parsed = '🔴 Motor cortado correctamente';
    } else if (t.contains('resume') || t.contains('acc on')) {
      parsed = '🟢 Motor reanudado correctamente';
    } else if (t.contains('move') && t.contains('alarm')) {
      parsed = '⚠️ Alerta de movimiento activada';
    } else if (t.contains('speed') && t.contains('alarm')) {
      parsed = '⚡ Alerta de velocidad activada';
    } else if (t.contains('tracker') || t.contains('online')) {
      parsed = '✅ GPS en modo activo';
    } else if (t.contains('monitor')) {
      parsed = '🎙️ Modo escucha activado';
    } else if (t.contains('low battery')) {
      parsed = '🔋 Batería baja del GPS';
    } else if (t.contains('power off')) {
      parsed = '⭕ GPS apagado';
    } else {
      parsed = '📨 Respuesta GPS: $raw';
    }

    return GpsResponse(raw: raw, timestamp: DateTime.now(), parsed: parsed);
  }
}
