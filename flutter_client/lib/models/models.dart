// lib/models/models.dart

class SessionData {
  final String clientId;
  final String clientName;
  final String username;
  final String accountType;   // "individual" | "fleet"
  final String wsToken;       // para WebSocket
  final String token;         // token de sesión para API
  final String? phone;        // teléfono WhatsApp del cliente
  final String? deviceId;     // ID dispositivo
  final String? simNumber;    // SIM del GPS
  final String? vehicleId;    // ID del vehículo
  final List<FleetVehicle> vehicles;

  SessionData({
    required this.clientId,
    required this.clientName,
    required this.username,
    required this.accountType,
    required this.wsToken,
    required this.token,
    this.phone,
    this.deviceId,
    this.simNumber,
    this.vehicleId,
    this.vehicles = const [],
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      clientId:    json['client_id']?.toString() ?? '',
      clientName:  json['client_name'] ?? '',
      username:    json['username'] ?? '',
      accountType: json['account_type'] ?? 'individual',
      wsToken:     json['ws_token'] ?? '',
      token:       json['token'] ?? '',
      phone:       json['phone'],
      deviceId:    json['device_id'],
      simNumber:   json['sim_number'],
      vehicleId:   json['vehicle_id'],
      vehicles: (json['vehicles'] as List<dynamic>? ?? [])
          .map((v) => FleetVehicle.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isFleet => accountType == 'fleet';
}

class FleetVehicle {
  final String id;
  final String deviceId;
  final String name;
  final String plate;
  final String? phone;
  final double? lat;
  final double? lng;
  final double? speed;
  final double? heading;
  final double? battery;
  final String? status;

  FleetVehicle({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.plate,
    this.phone,
    this.lat,
    this.lng,
    this.speed,
    this.heading,
    this.battery,
    this.status,
  });

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    return FleetVehicle(
      id:       json['id']?.toString() ?? '',
      deviceId: json['device_id'] ?? '',
      name:     json['name'] ?? '',
      plate:    json['plate'] ?? '',
      phone:    json['phone'],
      lat:      (json['lat'] as num?)?.toDouble(),
      lng:      (json['lng'] as num?)?.toDouble(),
      speed:    (json['speed'] as num?)?.toDouble(),
      heading:  (json['heading'] as num?)?.toDouble(),
      battery:  (json['battery'] as num?)?.toDouble(),
      status:   json['status'] ?? 'offline',
    );
  }

  FleetVehicle copyWith({
    double? lat,
    double? lng,
    double? speed,
    double? heading,
    double? battery,
    String? status,
  }) {
    return FleetVehicle(
      id: id, deviceId: deviceId, name: name, plate: plate, phone: phone,
      lat:     lat     ?? this.lat,
      lng:     lng     ?? this.lng,
      speed:   speed   ?? this.speed,
      heading: heading ?? this.heading,
      battery: battery ?? this.battery,
      status:  status  ?? this.status,
    );
  }
}