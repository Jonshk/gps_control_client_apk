import 'package:flutter/foundation.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

enum GpsCommand {
  locate,
  stopEngine,
  resumeEngine,
  moveAlert,
  speedAlert,
  online,
  monitor,
}

extension GpsCommandExt on GpsCommand {
  String get label => switch (this) {
        GpsCommand.locate       => 'Localizar',
        GpsCommand.stopEngine   => 'Apagar motor',
        GpsCommand.resumeEngine => 'Encender motor',
        GpsCommand.moveAlert    => 'Alerta movimiento',
        GpsCommand.speedAlert   => 'Alerta velocidad',
        GpsCommand.online       => 'Modo activo',
        GpsCommand.monitor      => 'Micrófono',
      };

  String smsMessage(String password) => switch (this) {
        GpsCommand.locate       => 'check$password',
        GpsCommand.stopEngine   => 'stop$password',
        GpsCommand.resumeEngine => 'resume$password',
        GpsCommand.moveAlert    => 'move$password',
        GpsCommand.speedAlert   => 'speed$password 080',
        GpsCommand.online       => 'online$password',
        GpsCommand.monitor      => 'monitor$password',
      };
}

enum SmsResult { sent, openedApp, failed }

extension SmsResultExt on SmsResult {
  String get message => switch (this) {
        SmsResult.sent      => 'Comando enviado.',
        SmsResult.openedApp => 'Se abrió la app de mensajes. Confirma el envío.',
        SmsResult.failed    => 'No se pudo enviar. Verifica permisos de SMS.',
      };
  bool get isSuccess => this != SmsResult.failed;
}

class SmsService {
  static Future<SmsResult> sendCommand(GpsCommand cmd, String simNumber) async {
    final msg = cmd.smsMessage(kGpsPassword);
    debugPrint('[SMS] → $simNumber : $msg');

    // Intentar envío silencioso con flutter_sms
    try {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        final result = await sendSMS(message: msg, recipients: [simNumber]);
        if (result == 'SMS Sent!') return SmsResult.sent;
      }
    } catch (e) {
      debugPrint('[SMS] flutter_sms error: $e');
    }

    // Fallback: abrir app de mensajes nativa
    try {
      final uri = Uri(
        scheme: 'sms',
        path: simNumber,
        queryParameters: {'body': msg},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return SmsResult.openedApp;
      }
    } catch (e) {
      debugPrint('[SMS] url_launcher error: $e');
    }

    return SmsResult.failed;
  }
}
