import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/entry.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/core/money.dart';
import 'package:organizador/core/reminders.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

// Terça-feira, 20/10/2026, 10:00.
DateTime _clock = DateTime(2026, 10, 20, 10, 0);

AppState _app([FakeStore? store]) => AppState(clock: () => _clock, store: store);

Task _bill({
  String id = 'b1',
  int? cents = 12990,
  TaskKind kind = TaskKind.recurring,
  DateTime? due,
  bool alarm = false,
}) =>
    Task(
      id: id,
      title: 'Internet',
      kind: kind,
      createdAt: _clock,
      due: due ?? DateTime(2026, 10, 25),
      recurrence: kind == TaskKind.recurring
          ? const Recurrence(type: RecurrenceType.monthDay, dayOfMonth: 25)
          : null,
      module: kModFinance,
      amountCents: cents,
      alarm: alarm,
    );

void main() {
  setUp(() => _clock = DateTime(2026, 10, 20, 10, 0));

  group('dinheiro', () {
    test('formata em reais', () {
      expect(fmtMoney(0), 'R\$ 0,00');
      expect(fmtMoney(5), 'R\$ 0,05');
      expect(fmtMoney(12990), 'R\$ 129,90');
      expect(fmtMoney(123456), 'R\$ 1.234,56');
      expect(fmtMoney(100000000), 'R\$ 1.000.000,00');
      expect(fmtMoney(-250), '-R\$ 2,50');
    });

    test('lê o que a pessoa digita', () {
      expect(parseMoney('12'), 1200);
      expect(parseMoney('12,5'), 1250);
      expect(parseMoney('12,50'), 1250);
      expect(parseMoney('12.50'), 1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1.234'), 123400);
      expect(parseMoney('R\$ 89,90'), 8990);
      expect(parseMoney(' 0,05 '), 5);
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('1,2,3'), isNull);
      expect(parseMoney('12,505'), isNull);
    });

    test('ida e volta', () {
      for (final c in [0, 1, 99, 100, 12345, 99999999]) {
        expect(parseMoney(fmtMoney(c)), c);
      }
    });
  });

  group('contas a pagar', () {
    test('pagar adiantada registra o pagamento e vai para o mês seguinte', () {
      final s = _app();
      final b = _bill();
      s.saveTask(b, isNew: true);
      expect(s.canComplete(b), isTrue);
      expect(s.complete(b), isTrue);
      // Não pode ficar no mesmo mês (25/10 de novo).
      expect(b.due, DateTime(2026, 11, 25));
      final e = s.expenses.single;
      expect(e.number('cents'), 12990);
      expect(e.text('cat'), kBillCategory);
      expect(e.text('desc'), 'Internet');
      expect(e.data['bill'], 'b1');
    });

    test('desfazer devolve a conta e apaga o pagamento', () {
      final s = _app();
      final b = _bill();
      s.saveTask(b, isNew: true);
      s.complete(b);
      s.undo();
      expect(b.due, DateTime(2026, 10, 25));
      expect(s.expenses, isEmpty);
    });

    test('conta única paga some da lista', () {
      final s = _app();
      final b = _bill(kind: TaskKind.single);
      s.saveTask(b, isNew: true);
      s.complete(b);
      expect(b.status, TaskStatus.done);
      expect(s.bills, isEmpty);
      expect(s.totalCents(s.expenses), 12990);
    });

    test('paga depois do vencimento avança a partir de hoje', () {
      final s = _app();
      final b = _bill(due: DateTime(2026, 10, 10));
      s.saveTask(b, isNew: true);
      s.complete(b);
      expect(b.due, DateTime(2026, 10, 25));
    });

    test('pular uma conta adiantada também não repete o mês', () {
      final s = _app();
      final b = _bill();
      s.saveTask(b, isNew: true);
      expect(s.skip(b), isTrue);
      expect(b.due, DateTime(2026, 11, 25));
    });

    test('tarefa comum recorrente continua sem poder concluir antes da hora', () {
      final s = _app();
      final t = Task(
        id: 't',
        title: 'Aula',
        kind: TaskKind.recurring,
        createdAt: _clock,
        due: DateTime(2026, 10, 25),
        recurrence: const Recurrence(type: RecurrenceType.daily),
      );
      expect(s.canComplete(t), isFalse);
    });

    test('falta pagar no mês: vencidas e do mês, não as do mês seguinte', () {
      final s = _app();
      s.saveTask(_bill(id: 'a', cents: 10000, due: DateTime(2026, 10, 5)), isNew: true);
      s.saveTask(_bill(id: 'b', cents: 5000, due: DateTime(2026, 10, 31)), isNew: true);
      s.saveTask(_bill(id: 'c', cents: 7000, due: DateTime(2026, 11, 1)), isNew: true);
      s.saveTask(_bill(id: 'd', cents: null, due: DateTime(2026, 10, 12)), isNew: true);
      expect(s.billsDueCents(_clock), 15000);
    });

    test('conta não aparece como tarefa comum, mas aparece em HOJE/AGENDA', () {
      final s = _app();
      final b = _bill(due: DateTime(2026, 10, 20));
      s.saveTask(b, isNew: true);
      expect(s.todayView().total, 1);
      expect(s.bills.single, b);
    });
  });

  group('gastos', () {
    test('total do mês e por categoria; meses diferentes não se misturam', () {
      final s = _app();
      s.addEntry(kModFinance,
          at: DateTime(2026, 10, 3), data: {'desc': 'x', 'cents': 5000, 'cat': 'Mercado'});
      s.addEntry(kModFinance,
          at: DateTime(2026, 10, 9), data: {'desc': 'y', 'cents': 2500, 'cat': 'Mercado'});
      s.addEntry(kModFinance,
          at: DateTime(2026, 10, 9), data: {'desc': 'z', 'cents': 1000, 'cat': 'Lazer'});
      s.addEntry(kModFinance,
          at: DateTime(2026, 9, 30), data: {'desc': 'w', 'cents': 9999, 'cat': 'Casa'});
      final month = s.expensesIn(_clock);
      expect(s.totalCents(month), 8500);
      expect(s.byCategory(month).map((e) => '${e.key}:${e.value}'), ['Mercado:7500', 'Lazer:1000']);
      expect(s.totalCents(s.expensesIn(DateTime(2026, 9, 1))), 9999);
    });

    test('lançamento sem categoria vai para Outros', () {
      final s = _app();
      s.addEntry(kModFinance, data: {'desc': 'x', 'cents': 100});
      expect(s.byCategory(s.expenses).single.key, kOtherCategory);
    });
  });

  group('avisos e persistência', () {
    test('conta só com vencimento avisa na véspera e no dia, às 09:00', () {
      final r = planReminders([_bill(kind: TaskKind.single)], _clock);
      expect(r.map((x) => x.at), [DateTime(2026, 10, 24, 9), DateTime(2026, 10, 25, 9)]);
      expect(r.every((x) => !x.alarm), isTrue);
    });

    test('conta com alarme avisa como alarme', () {
      final r = planReminders([_bill(kind: TaskKind.single, alarm: true)], _clock);
      expect(r.length, 2);
      expect(r.every((x) => x.alarm), isTrue);
    });

    test('conta mensal também agenda o mês seguinte se estiver na janela', () {
      final t = _bill(due: DateTime(2026, 10, 25));
      final r = planReminders([t], DateTime(2026, 10, 22, 8));
      // Dentro de 7 dias só há a de 25/10 (véspera e dia).
      expect(r.map((x) => x.at.day), [24, 25]);
    });

    test('valor sobrevive ao codec, ao banco simulado e ao backup', () async {
      final store = FakeStore();
      final a = _app(store);
      a.saveTask(_bill(alarm: true), isNew: true);
      await Future<void>.delayed(Duration.zero);

      expect(taskFromMap(taskToMap(_bill())).amountCents, 12990);

      final b = _app(store);
      await b.load();
      final t = b.tasks.single;
      expect(t.amountCents, 12990);
      expect(t.module, kModFinance);
      expect(t.alarm, isTrue);

      final back = decodeBackup(encodeBackup(b.exportSnapshot(), _clock));
      expect(back.snapshot.tasks.single.amountCents, 12990);
    });

    test('backup antigo sem valor abre com valor nulo', () {
      final m = taskToMap(_bill())..remove('amount_cents');
      expect(taskFromMap(m).amountCents, isNull);
    });

    test('conta com horário avisa no horário', () {
      final t = _bill(kind: TaskKind.single);
      t.time = const TimeOfDay(hour: 8, minute: 30);
      final r = planReminders([t], _clock);
      expect(r.single.at, DateTime(2026, 10, 25, 8, 30));
    });
  });
}
