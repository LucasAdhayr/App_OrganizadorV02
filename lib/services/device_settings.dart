import 'package:flutter/services.dart';

/// Atalhos para configurações do Android de que os alarmes dependem. Qualquer
/// falha vira null/false: a tela de diagnóstico continua funcionando.
class DeviceSettings {
  DeviceSettings._();

  static const MethodChannel _channel = MethodChannel('br.pessoal.organizador/device');

  /// true = o app está livre da economia de bateria. null = não deu para saber.
  static Future<bool?> batteryUnrestricted() async {
    try {
      return await _channel.invokeMethod<bool>('batteryUnrestricted');
    } catch (_) {
      return null;
    }
  }

  static Future<void> openBatterySettings() => _call('openBatterySettings');

  static Future<void> openAppSettings() => _call('openAppSettings');

  /// Configurações de um canal de notificação (som, volume, importância).
  static Future<void> openChannelSettings(String channel) =>
      _call('openChannelSettings', <String, Object?>{'channel': channel});

  static Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {}
  }
}
