import 'package:flutter/material.dart';

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
        token: j['token'] as String,
        clientName: j['client_name'] as String,
        vehicleName: j['vehicle_name'] as String? ?? '',
        vehicleId: j['vehicle_id'] as String? ?? '',
        simNumber: j['sim_number'] as String,
      );
}

class VehicleStatus {
  final String vehicleId;
  final String vehicleName;
  final String status;
  final double lat;
  final double lng;
  final double speed;
  final String? geofence;
  final String updatedAt;

  const VehicleStatus({
    required this.vehicleId,
    required this.vehicleName,
    required this.status,
    required this.lat,
    required this.lng,
    required this.speed,
    this.geofence,
    required this.updatedAt,
  });

  factory VehicleStatus.fromJson(Map<String, dynamic> j) => VehicleStatus(
        vehicleId: j['vehicle_id'] as String? ?? '',
        vehicleName: j['vehicle_name'] as String? ?? '',
        status: j['status'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        speed: (j['speed'] as num).toDouble(),
        geofence: j['geofence'] as String?,
        updatedAt: j['updated_at'] as String? ?? '',
      );

  String get statusLabel => switch (status) {
        'active' => 'En ruta',
        'idle' => 'En espera',
        'offline' => 'Sin señal',
        _ => status,
      };

  Color get statusColor => switch (status) {
        'active' => const Color(0xFF00D4A0),
        'idle' => const Color(0xFF60A5FA),
        _ => const Color(0xFFF87171),
      };
}
