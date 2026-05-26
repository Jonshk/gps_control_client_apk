import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../config.dart';

typedef GpsResponseCallback = void Function(GpsResponse response);

class SmsService {
  static GpsResponseCallback? _onResponse;
  static String? _authToken;
  static Timer? _pollTimer;

  // ─── Iniciar polling de respuestas del GPS via backend ───────────────────
  static void startListening({
    required String token,
    required GpsResponseCallback onResponse,
  }) {
    _authToken = token;
    _onResponse = onResponse;

    // Poll cada 5 segundos para respuestas del GPS
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchResponses());
  }

  static void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onResponse = null;
    _authToken = null;
  }

  static Future<void> _fetchResponses() async {
    if (_authToken == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/app/responses'),
        headers: {'x-app-token': _authToken!},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        for (final item in list) {
          final body = item['body'] as String? ?? '';
          final response = GpsResponse.fromRaw(body);
          _onResponse?.call(response);
        }
      }
    } catch (e) {
      debugPrint('[sms] poll error: $e');
    }
  }

  // ─── Enviar comando via backend → Gateway → GPS ──────────────────────────
  // No necesita permisos de SMS, no necesita app predeterminada,
  // funciona con pantalla bloqueada, funciona solo con internet.
  static Future<SmsResult> sendCommand(GpsCommand cmd, String token) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/app/command'),
        headers: {
          'Content-Type': 'application/json',
          'x-app-token': token,
        },
        body: jsonEncode({'command': cmd.apiKey}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return SmsResult(
          isSuccess: true,
          message: 'Comando enviado: ${cmd.label.replaceAll('\n', ' ')}',
        );
      } else {
        final body = jsonDecode(res.body);
        return SmsResult(
          isSuccess: false,
          message: body['detail'] ?? 'Error al enviar comando',
        );
      }
    } catch (e) {
      return SmsResult(isSuccess: false, message: 'Error de conexión: $e');
    }
  }
}
