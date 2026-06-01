import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/models.dart';

class ApiService {
  static Future<SessionData> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/app/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return SessionData.fromJson(body);
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

  static Future<Map<String, dynamic>> getStatus(String token) async {
    final res = await http.get(
      Uri.parse('$kApiBase/app/status'),
      headers: {'x-app-token': token},
    ).timeout(const Duration(seconds: 12));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw Exception(body['detail'] ?? 'Error al obtener estado');
  }

  static Future<void> saveSession(SessionData s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('session_json', jsonEncode({
      'client_id':    s.clientId,
      'client_name':  s.clientName,
      'username':     s.username,
      'account_type': s.accountType,
      'ws_token':     s.wsToken,
      'token':        s.token,
      'phone':        s.phone ?? '',
      'vehicle_id':   s.vehicleId ?? '',
      'sim_number':   s.simNumber ?? '',
    }));
  }

  static Future<SessionData?> loadSession() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('session_json');
    if (raw == null) return null;
    try {
      return SessionData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}