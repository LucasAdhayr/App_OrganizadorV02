import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/entry.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/core/reminders.dart';
import 'package:organizador/services/notifier.dart';

// Terça-feira, 13/10/2026, 10:00.
final DateTime _now = DateTime(2026, 10, 13, 10, 0);

Task _t(
  String id, {
  DateTime? due,
  TimeOfDay? time,
  TaskKind kind = TaskKind.single,
  TaskStatus status = TaskStatus.pending,
  DateTime? snoozedUntil,
}) =>
    Task(
      id: id,
      title: 'Tarefa $id',
      kind: kind,
      createdAt: _now,
      due: due,
      time: time,
      status: status,
      snoozedUntil: snoozedUntil,
      recurrence: kind == TaskKind.recurring
          ? const Recurrence(type: RecurrenceType.daily)
          : null,
    );

class _FakeNotifier implements Notifier {
  final List<List<Reminder>> calls = [];

  @override
  Future<void> replace(List<Reminder> reminders) async => calls.add(reminders);
  @override
  Future<NotifierStatus> status() async => const NotifierStatus();
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> requestExactAlarms() async {}
  @override
  Future<void> showTest() async {}
  @override
  Future<void> scheduleTest(Duration after) async {}
}

void main() {
  group('planReminders', () {
    test('com horário: um lembrete na hora marcada', () {
      final r = planReminders([
        _t('a', due: DateTime(2026, 10, 13), time: const TimeOfDay(hour: 15, minute: 30)),
      ], _now);
      expect(r.single.at, DateTime(2026, 10, 13, 15, 30));
      expect(r.single.body, 'Hoje às 15:30');
    });

    test('só data: véspera e dia, às 09:00', () {
      final r = planReminders([_t('a', due: DateTime(2026, 10, 15))], _now);
      expect(r.map((x) => x.at), [DateTime(2026, 10, 14, 9), DateTime(2026, 10, 15, 9)]);
      expect(r.first.body, 'Vence amanhã');
      expect(r.last.body, 'Vence hoje');
    });

    test('só data para amanhã: o de hoje às 09:00 já passou e é ignorado', () {
      final r = planReminders([_t('a', due: DateTime(2026, 10, 14))], _now);
      expect(r.map((x) => x.at), [DateTime(2026, 10, 14, 9)]);
    });

    test('silêncio 00:00–05:00 empurra para as 05:00', () {
      final r = planReminders([
        _t('a', due: DateTime(2026, 10, 14), time: const TimeOfDay(hour: 2, minute: 0)),
        _t('b', due: DateTime(2026, 10, 14), time: const TimeOfDay(hour: 5, minute: 0)),
        _t('c', due: DateTime(2026, 10, 14), time: const TimeOfDay(hour: 4, minute: 59)),
      ], _now);
      expect(r.map((x) => x.at.hour), [5, 5, 5]);
    });

    test('adiada: vale o horário do adiamento', () {
      final r = planReminders([
        _t('a',
            due: DateTime(2026, 10, 13),
            snoozedUntil: DateTime(2026, 10, 14, 18, 15)),
      ], _now);
      expect(r.single.at, DateTime(2026, 10, 14, 18, 15));
    });

    test('ignora passado, sem data e tarefas encerradas', () {
      final r = planReminders([
        _t('a', due: DateTime(2026, 10, 12), time: const TimeOfDay(hour: 9, minute: 0)),
        _t('b'),
        _t('c', due: DateTime(2026, 10, 20), status: TaskStatus.done),
        _t('d', due: DateTime(2026, 10, 20), status: TaskStatus.discarded),
      ], _now);
      expect(r, isEmpty);
    });

    test('recorrente: só a ocorrência atual', () {
      final r = planReminders([
        _t('a',
            kind: TaskKind.recurring,
            due: DateTime(2026, 10, 14),
            time: const TimeOfDay(hour: 8, minute: 0)),
      ], _now);
      expect(r.length, 1);
    });

    test('ids são estáveis e distintos por tipo', () {
      final a = planReminders([_t('x', due: DateTime(2026, 10, 15))], _now);
      final b = planReminders([_t('x', due: DateTime(2026, 10, 15))], _now);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      expect(a[0].id, isNot(a[1].id));
    });

    test('respeita o limite, mantendo os mais próximos', () {
      final tasks = [
        for (var i = 0; i < 80; i++)
          _t('t$i',
              due: DateTime(2026, 10, 14),
              time: TimeOfDay(hour: 6 + i % 10, minute: i % 60)),
      ];
      final r = planReminders(tasks, _now);
      expect(r.length, kMaxReminders);
      for (var i = 1; i < r.length; i++) {
        expect(r[i].at.isBefore(r[i - 1].at), isFalse);
      }
    });
  });

  group('água e exercícios', () {
    // Terça 13/10/2026, 10:00 — 6h já passou; faltam 12h, 18h e 21h.
    List<Reminder> water(int mlToday, {int goal = 2000}) => planReminders(
          const [],
          _now,
          water: WaterPlan(
            goalMl: goal,
            mlOn: (d) => d.day == 13 ? mlToday : 0,
          ),
        ).where((r) => r.taskId == 'water').toList();

    test('sem beber nada: avisos de 12h, 18h e 21h hoje', () {
      final r = water(0).where((x) => x.at.day == 13).toList();
      expect(r.map((x) => x.at.hour), [12, 18, 21]);
      expect(r.first.body, 'Beba mais água');
      expect(r.last.body, 'Ainda falta beber água');
    });

    test('30% atingido some o aviso das 12h; 70% some o das 18h; 100% some todos', () {
      expect(water(600).where((x) => x.at.day == 13).map((x) => x.at.hour), [18, 21]);
      expect(water(1400).where((x) => x.at.day == 13).map((x) => x.at.hour), [21]);
      expect(water(2000).where((x) => x.at.day == 13), isEmpty);
    });

    test('dias seguintes começam com o aviso das 6h', () {
      final r = water(0).where((x) => x.at.day == 14).toList();
      expect(r.first.at.hour, 6);
      expect(r.first.body, 'Beba seu primeiro gole d\'água');
    });

    test('rotina de exercício avisa 1 hora antes', () {
      final t = Task(
        id: 'ex',
        title: 'Corrida',
        kind: TaskKind.recurring,
        createdAt: _now,
        due: DateTime(2026, 10, 14),
        time: const TimeOfDay(hour: 18, minute: 30),
        recurrence: const Recurrence(type: RecurrenceType.daily),
        module: kModExercise,
      );
      final r = planReminders([t], _now);
      expect(r.first.at, DateTime(2026, 10, 14, 17, 30));
      expect(r.first.body, contains('18:30'));
    });

    test('concluir rotina registra um treino; desfazer remove', () {
      final s = AppState(clock: () => _now);
      final t = Task(
        id: 'ex',
        title: 'Corrida',
        kind: TaskKind.recurring,
        createdAt: _now,
        due: DateTime(2026, 10, 13),
        time: const TimeOfDay(hour: 18, minute: 0),
        recurrence: const Recurrence(type: RecurrenceType.daily),
        module: kModExercise,
      );
      s.saveTask(t, isNew: true);
      expect(s.complete(t), isTrue);
      expect(s.entriesOf(kModExercise).single.text('kind'), 'Corrida');
      s.undo();
      expect(s.entriesOf(kModExercise), isEmpty);
    });
  });

  group('AppState + notificações', () {
    test('salvar, adiar e concluir refazem os lembretes', () async {
      final n = _FakeNotifier();
      final s = AppState(clock: () => _now)..attachNotifier(n);
      await Future<void>.delayed(Duration.zero);
      n.calls.clear();

      final t = _t('a', due: DateTime(2026, 10, 15), time: const TimeOfDay(hour: 9, minute: 0));
      s.saveTask(t, isNew: true);
      await Future<void>.delayed(Duration.zero);
      expect(n.calls.last.single.at, DateTime(2026, 10, 15, 9));

      s.snooze(t, DateTime(2026, 10, 16, 10));
      await Future<void>.delayed(Duration.zero);
      expect(n.calls.last.single.at, DateTime(2026, 10, 16, 10));

      s.discard(t);
      await Future<void>.delayed(Duration.zero);
      expect(n.calls.last, isEmpty);
    });

    test('vários salvamentos seguidos viram uma troca só', () async {
      final n = _FakeNotifier();
      final s = AppState(clock: () => _now)..attachNotifier(n);
      await Future<void>.delayed(Duration.zero);
      n.calls.clear();
      s.loadSampleData();
      await Future<void>.delayed(Duration.zero);
      expect(n.calls.length, 1);
    });
  });

  group('histórico editável', () {
    test('apagar e desfazer devolvem o registro à mesma posição', () {
      final s = AppState(clock: () => _now);
      final t = _t('a');
      s.saveTask(t, isNew: true);
      s.complete(t);
      final e = s.history.last;
      final i = s.removeHistoryEvent(e);
      expect(s.history.any((x) => x.id == e.id), isFalse);
      s.insertHistoryEvent(i, e);
      expect(s.history.last.id, e.id);
    });

    test('mudar data e hora corrige o registro e a contagem do dia', () {
      final s = AppState(clock: () => _now);
      final t = _t('a');
      s.saveTask(t, isNew: true);
      s.complete(t);
      expect(s.doneToday(), 1);
      s.changeHistoryTime(
          s.history.last, DateTime(2026, 10, 12, 22, 0));
      expect(s.doneToday(), 0);
      expect(s.history.last.at, DateTime(2026, 10, 12, 22, 0));
    });
  });
}
