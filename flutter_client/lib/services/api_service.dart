import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/models.dart';

class ApiService {
  static Future<SessionModel> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/app/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return SessionModel.fromJson(body);
    throw Exception(body['detail'] ?? 'Error al iniciar sesión');
  }

  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$kApiBase/app/logout'),
        headers: {'x-app-token': token},
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<VehicleStatus> getStatus(String token) async {
    final res = await http.get(
      Uri.parse('$kApiBase/app/status'),
      headers: {'x-app-token': token},
    ).timeout(const Duration(seconds: 12));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return VehicleStatus.fromJson(body);
    throw Exception(body['detail'] ?? 'Error al obtener estado');
  }

  // ── Persistencia ──────────────────────────────────────────────────────
  static Future<void> saveSession(SessionModel s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token',        s.token);
    await p.setString('client_name',  s.clientName);
    await p.setString('vehicle_name', s.vehicleName);
    await p.setString('vehicle_id',   s.vehicleId);
    await p.setString('sim_number',   s.simNumber);
  }

  static Future<SessionModel?> loadSession() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token');
    if (token == null) return null;
    return SessionModel(
      token:       token,
      clientName:  p.getString('client_name')  ?? '',
      vehicleName: p.getString('vehicle_name') ?? '',
      vehicleId:   p.getString('vehicle_id')   ?? '',
      simNumber:   p.getString('sim_number')   ?? '',
    );
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
