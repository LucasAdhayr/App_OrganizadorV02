import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/entry.dart';
import 'package:organizador/core/medication.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/core/reminders.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

// Terça-feira, 13/10/2026, 10:00.
DateTime _clock = DateTime(2026, 10, 13, 10, 0);

AppState _app([FakeStore? store]) => AppState(clock: () => _clock, store: store);

Medication _med({
  String times = '08:00,20:00',
  int perDose = 1,
  int stock = 10,
  DateTime? stockAt,
  bool active = true,
}) {
  final at = stockAt ?? DateTime(2026, 10, 13, 7, 0);
  return Medication(Entry(
    id: 'm1',
    module: kModMed,
    at: at,
    createdAt: at,
    data: <String, Object?>{
      'name': 'Vitamina',
      'times': times,
      'perDose': perDose,
      'stock': stock,
      'stockAt': at.millisecondsSinceEpoch,
      'active': active,
    },
  ));
}

void main() {
  setUp(() => _clock = DateTime(2026, 10, 13, 10, 0));

  group('estoque', () {
    test('desce sozinho a cada horário que passa', () {
      final m = _med();
      // Passou só o das 08:00.
      expect(m.remaining(_clock), 9);
      expect(m.remaining(DateTime(2026, 10, 13, 21, 0)), 8);
      expect(m.remaining(DateTime(2026, 10, 14, 9, 0)), 7);
    });

    test('dia em que acaba e quantos dias faltam', () {
      final m = _med();
      expect(m.lastDay(_clock), DateTime(2026, 10, 17));
      expect(m.daysLeft(_clock), 5);
      expect(m.isLow(_clock), isTrue);
      expect(m.warning(_clock), contains('falta'));
    });

    test('estoque grande não é baixo', () {
      final m = _med(stock: 100);
      expect(m.isLow(_clock), isFalse);
    });

    test('acabou', () {
      final m = _med(stock: 2, stockAt: DateTime(2026, 10, 12, 7, 0));
      expect(m.isOut(_clock), isTrue);
      expect(m.lastDay(_clock), isNull);
      expect(m.stockText(_clock), 'ACABOU');
      expect(m.warning(_clock), contains('acabou'));
    });

    test('um horário por dia, duas unidades por vez', () {
      final m = _med(times: '09:00', perDose: 2, stock: 6, stockAt: DateTime(2026, 10, 13, 8, 0));
      // 09:00 de hoje já passou: restam 4 unidades = 2 doses (14 e 15).
      expect(m.remaining(_clock), 4);
      expect(m.lastDay(_clock), DateTime(2026, 10, 15));
      expect(m.perDay, 2);
    });

    test('parado não consome nem tem aviso', () {
      final m = _med(active: false);
      expect(m.remaining(DateTime(2026, 10, 30)), 10);
      expect(m.isLow(_clock), isFalse);
      expect(m.stockText(_clock), 'PARADO');
    });

    test('horários inválidos são ignorados e ordenados', () {
      final ts = parseMedTimes('20:00, 8:05,xx,25:00,08:05');
      expect(ts.map((t) => '${t.hour}:${t.minute}'), ['8:5', '20:0']);
    });
  });

  group('AppState', () {
    test('adicionar estoque soma ao que resta', () {
      final s = _app();
      final m = s.addMedication(
        name: 'A',
        times: const [TimeOfDay(hour: 20, minute: 0)],
        perDose: 1,
        stock: 5,
      );
      _clock = DateTime(2026, 10, 15, 12, 0); // passaram 20:00 de 13 e 14
      expect(m.remaining(_clock), 3);
      s.addMedicationStock(m, 30);
      expect(Medication(m.entry).remaining(_clock), 33);
      _clock = DateTime(2026, 10, 15, 21, 0);
      expect(Medication(m.entry).remaining(_clock), 32);
    });

    test('mudar o horário não refaz o consumo passado', () {
      final s = _app();
      final m = s.addMedication(
        name: 'A',
        times: const [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
        perDose: 1,
        stock: 20,
      );
      _clock = DateTime(2026, 10, 14, 21, 0); // 3 doses passaram -> 17
      s.editMedication(m,
          name: 'A', times: const [TimeOfDay(hour: 9, minute: 0)], perDose: 2);
      final after = Medication(m.entry);
      expect(after.remaining(_clock), 17);
      expect(after.perDay, 2);
    });

    test('parei de tomar congela o estoque e volta a contar ao retomar', () {
      final s = _app();
      final m = s.addMedication(
        name: 'A',
        times: const [TimeOfDay(hour: 20, minute: 0)],
        perDose: 1,
        stock: 10,
      );
      _clock = DateTime(2026, 10, 15, 12, 0); // 2 doses -> 8
      s.stopMedication(m);
      expect(s.medications.single.active, isFalse);
      _clock = DateTime(2026, 10, 25, 12, 0);
      expect(Medication(m.entry).remaining(_clock), 8);
      s.resumeMedication(m);
      expect(Medication(m.entry).active, isTrue);
      _clock = DateTime(2026, 10, 25, 21, 0);
      expect(Medication(m.entry).remaining(_clock), 7);
    });

    test('persiste e volta ao reabrir', () async {
      final store = FakeStore();
      final a = _app(store);
      a.addMedication(
        name: 'A',
        times: const [TimeOfDay(hour: 8, minute: 0)],
        perDose: 1,
        stock: 9,
      );
      await Future<void>.delayed(Duration.zero);
      final b = _app(store);
      await b.load();
      expect(b.medications.single.name, 'A');
      expect(b.medications.single.stockBase, 9);
    });

    test('lowMedications lista só os que estão acabando', () {
      final s = _app();
      s.addMedication(
          name: 'Pouco', times: const [TimeOfDay(hour: 20, minute: 0)], perDose: 1, stock: 3);
      s.addMedication(
          name: 'Muito', times: const [TimeOfDay(hour: 20, minute: 0)], perDose: 1, stock: 90);
      expect(s.lowMedications.map((m) => m.name), ['Pouco']);
    });
  });

  group('alarmes', () {
    test('todo remédio ativo gera alarmes pelos próximos 7 dias', () {
      final r = planReminders(const <Task>[], _clock, meds: [_med()]);
      expect(r.every((x) => x.alarm), isTrue);
      expect(r.first.at, DateTime(2026, 10, 13, 20, 0));
      // Hoje: só 20:00. Mais 6 dias com 2 horários.
      expect(r.length, 1 + 6 * 2);
      expect(r.first.title, 'Vitamina');
      expect(r.map((x) => x.id).toSet().length, r.length);
    });

    test('remédio parado não toca', () {
      expect(planReminders(const <Task>[], _clock, meds: [_med(active: false)]), isEmpty);
    });

    test('alarme de remédio não é cortado pelo limite', () {
      final tasks = [
        for (var i = 0; i < kMaxReminders + 20; i++)
          Task(
            id: 't$i',
            title: 'T$i',
            kind: TaskKind.single,
            createdAt: _clock,
            due: DateTime(2026, 10, 14),
            time: TimeOfDay(hour: 6 + i % 10, minute: i % 60),
          ),
      ];
      final r = planReminders(tasks, _clock, meds: [_med()]);
      expect(r.where((x) => x.alarm).length, 13);
      expect(r.length, kMaxReminders + 13);
    });

    test('silêncio vale também para alarmes', () {
      final r = planReminders(const <Task>[], _clock, meds: [_med(times: '03:00')]);
      expect(r.first.at.hour, 5);
    });

    test('tarefa com alarme avisa como alarme; sem, como notificação', () {
      Task t(String id, bool alarm) => Task(
            id: id,
            title: id,
            kind: TaskKind.single,
            createdAt: _clock,
            due: DateTime(2026, 10, 14),
            time: const TimeOfDay(hour: 9, minute: 0),
            alarm: alarm,
          );
      final r = planReminders([t('com', true), t('sem', false)], _clock);
      expect(r.singleWhere((x) => x.title == 'com').alarm, isTrue);
      expect(r.singleWhere((x) => x.title == 'sem').alarm, isFalse);
    });
  });

  group('codec e backup', () {
    test('a marca de alarme sobrevive ao codec e ao backup', () {
      final t = Task(
        id: 'a',
        title: 'Reunião',
        kind: TaskKind.single,
        createdAt: _clock,
        due: DateTime(2026, 10, 14),
        time: const TimeOfDay(hour: 9, minute: 0),
        alarm: true,
      );
      expect(taskFromMap(taskToMap(t)).alarm, isTrue);

      final s = _app();
      s.saveTask(t, isNew: true);
      s.addMedication(
        name: 'A',
        times: const [TimeOfDay(hour: 8, minute: 0)],
        perDose: 1,
        stock: 9,
      );
      final back = decodeBackup(encodeBackup(s.exportSnapshot(), _clock));
      expect(back.snapshot.tasks.single.alarm, isTrue);
      final e = back.snapshot.entries.single;
      expect(Medication(e).name, 'A');
      expect(Medication(e).active, isTrue);
    });

    test('backup antigo sem "alarm" abre com alarme desligado', () {
      final t = Task(id: 'a', title: 'x', kind: TaskKind.single, createdAt: _clock);
      final m = taskToMap(t)..remove('alarm');
      expect(taskFromMap(m).alarm, isFalse);
    });
  });
}
