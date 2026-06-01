import 'package:telephony/telephony.dart';
import '../config.dart';

class SmsService {
  static final _telephony = Telephony.instance;
  static bool _listening = false;
  static void Function(String body, String from)? _onIncoming;
  static String? _gpsSimNumber;

  // ── Iniciar escucha SMS entrantes ─────────────────────────────────────
  static Future<void> startListening({
    required String simNumber,
    required void Function(String body, String from) onIncoming,
  }) async {
    _gpsSimNumber = _normalize(simNumber);
    _onIncoming   = onIncoming;
    if (_listening) return;
    _listening = true;

    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) return;

    _telephony.listenIncomingSms(
      onNewMessage: _handle,
      onBackgroundMessage: _bgHandler,
      listenInBackground: false,
    );
  }

  static void stopListening() {
    _listening     = false;
    _onIncoming    = null;
    _gpsSimNumber  = null;
  }

  static void _handle(SmsMessage message) {
    final from = _normalize(message.address ?? '');
    final body = message.body ?? '';
    if (_gpsSimNumber != null && from.endsWith(_gpsSimNumber!.takeLast(7))) {
      _onIncoming?.call(body, from);
    }
  }

  // ── Enviar comando SMS ─────────────────────────────────────────────────
  // Llamar con: SmsService.sendCommand(phone: sim, command: 'DW1')
  static Future<bool> sendCommand({
    required String phone,
    required String command,
  }) async {
    try {
      final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
      if (!granted) return false;
      await _telephony.sendSms(to: phone, message: command);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _normalize(String n) =>
      n.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
}

@pragma('vm:entry-point')
void _bgHandler(SmsMessage message) {}

extension on String {
  String takeLast(int n) => length <= n ? this : substring(length - n);
}