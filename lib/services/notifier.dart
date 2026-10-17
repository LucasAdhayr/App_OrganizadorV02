import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminders.dart';

/// Situação das notificações, para a tela de diagnóstico.
class NotifierStatus {
  const NotifierStatus({
    this.notificationsEnabled,
    this.exactAlarms,
    this.pending = 0,
    this.error,
  });

  /// null = não deu para saber.
  final bool? notificationsEnabled;
  final bool? exactAlarms;
  final int pending;
  final String? error;
}

/// O que o app precisa das notificações. Fica atrás de uma interface para as
/// regras serem testadas sem Android.
abstract class Notifier {
  /// Troca TODOS os lembretes agendados por [reminders].
  Future<void> replace(List<Reminder> reminders);

  Future<NotifierStatus> status();
  Future<void> requestPermission();
  Future<void> requestExactAlarms();
  Future<void> showTest();
  Future<void> scheduleTest(Duration after);

  /// Agenda um teste que toca como alarme (o mesmo dos remédios).
  Future<void> scheduleAlarmTest(Duration after);
}

/// Implementação Android (flutter_local_notifications). Os lembretes são
/// alarmes do sistema: continuam valendo com o app fechado e (pelo receiver
/// de boot) depois de reiniciar o celular.
class LocalNotifier implements Notifier {
  LocalNotifier._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'lembretes';
  static const int _testId = 1;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Lembretes de tarefas',
      channelDescription: 'Avisos de prazos e horários das tarefas.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const String _alarmChannelId = 'alarmes';
  static const String _alarmChannelName = 'Alarmes';
  static const String _alarmChannelDesc =
      'Remédios e tarefas marcadas com alarme. Tocam como despertador.';
  static const String _alarmSound = 'content://settings/system/alarm_alert';

  static final Int64List _alarmVibration =
      Int64List.fromList(<int>[0, 800, 500, 800, 500, 800]);

  /// Alarme: canal de som "alarme" (ignora o volume de toque e passa pelo
  /// modo Não perturbe dos alarmes), tela acesa, som repetido até você tocar
  /// ou deslizar a notificação (no máximo 5 minutos).
  static final NotificationDetails _alarmDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const UriAndroidNotificationSound(_alarmSound),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _alarmVibration,
      // 4 = FLAG_INSISTENT: o som se repete até a notificação ser atendida.
      additionalFlags: Int32List.fromList(<int>[4]),
      timeoutAfter: 300000,
      autoCancel: true,
      ongoing: false,
    ),
  );

  Future<void> _queue = Future<void>.value();
  String? _lastError;

  static Future<LocalNotifier> create() async {
    final n = LocalNotifier._();
    tzdata.initializeTimeZones();
    await n._plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = n._android;
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Lembretes de tarefas',
      description: 'Avisos de prazos e horários das tarefas.',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(AndroidNotificationChannel(
      _alarmChannelId,
      _alarmChannelName,
      description: _alarmChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: const UriAndroidNotificationSound(_alarmSound),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _alarmVibration,
    ));
    // Android 13+: pede a permissão na primeira vez. Antes disso, é automática.
    // Sem await: no Android 13+ isto abre um diálogo e não deve travar a abertura.
    if (android != null) unawaited(android.requestNotificationsPermission());
    return n;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  // Os horários são instantes absolutos; o fuso usado aqui não muda quando tocam.
  tz.TZDateTime _instant(DateTime at) => tz.TZDateTime.from(at, tz.getLocation('UTC'));

  /// [alarm] usa o agendamento "despertador" do sistema, o mais confiável
  /// contra a economia de bateria (aparece o ícone de alarme na barra).
  Future<AndroidScheduleMode> _mode({bool alarm = false}) async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    if (!exact) return AndroidScheduleMode.inexactAllowWhileIdle;
    return alarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle;
  }

  @override
  Future<void> replace(List<Reminder> reminders) {
    // Em fila: duas trocas seguidas nunca se misturam.
    _queue = _queue.then((_) async {
      try {
        await _plugin.cancelAll();
        final mode = await _mode();
        final alarmMode = await _mode(alarm: true);
        for (final r in reminders) {
          await _plugin.zonedSchedule(
            r.id,
            r.title,
            r.body,
            _instant(r.at),
            r.alarm ? _alarmDetails : _details,
            androidScheduleMode: r.alarm ? alarmMode : mode,
            payload: r.taskId,
          );
        }
        _lastError = null;
      } catch (e) {
        _lastError = '$e';
      }
    });
    return _queue;
  }

  @override
  Future<NotifierStatus> status() async {
    try {
      final android = _android;
      final enabled = await android?.areNotificationsEnabled();
      final exact = await android?.canScheduleExactNotifications();
      final pending = await _plugin.pendingNotificationRequests();
      return NotifierStatus(
        notificationsEnabled: enabled,
        exactAlarms: exact,
        pending: pending.length,
        error: _lastError,
      );
    } catch (e) {
      return NotifierStatus(error: '$e');
    }
  }

  @override
  Future<void> requestPermission() async {
    await _android?.requestNotificationsPermission();
  }

  @override
  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> showTest() => _plugin.show(
        _testId,
        'Teste de notificação',
        'Se você está vendo isto, as notificações funcionam.',
        _details,
      );

  @override
  Future<void> scheduleTest(Duration after) async {
    await _plugin.zonedSchedule(
      _testId,
      'Teste agendado',
      'Chegou no horário, com o app fechado ou aberto.',
      _instant(DateTime.now().add(after)),
      _details,
      androidScheduleMode: await _mode(),
    );
  }

  @override
  Future<void> scheduleAlarmTest(Duration after) async {
    await _plugin.zonedSchedule(
      _testId + 1,
      'Teste de alarme',
      'Assim vão tocar os remédios e as tarefas com alarme.',
      _instant(DateTime.now().add(after)),
      _alarmDetails,
      androidScheduleMode: await _mode(alarm: true),
    );
  }
}
