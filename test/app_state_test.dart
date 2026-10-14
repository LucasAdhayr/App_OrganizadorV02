import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/models.dart';

// Terça-feira, 13/10/2026, 10:00.
final DateTime _now = DateTime(2026, 10, 13, 10, 0);

AppState _state() => AppState(clock: () => _now, seed: false);

Task _task(
  AppState s, {
  required TaskKind kind,
  DateTime? due,
  TimeOfDay? time,
  Recurrence? rule,
  DateTime? createdAt,
}) {
  final t = Task(
    id: s.newId('t'),
    title: 'Tarefa',
    kind: kind,
    createdAt: createdAt ?? _now,
    due: due,
    time: time,
    recurrence: rule,
  );
  s.tasks.add(t);
  return t;
}

void main() {
  const daily = Recurrence(type: RecurrenceType.daily);

  group('concluir', () {
    test('tarefa única fica concluída e entra no histórico', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 13));
      s.complete(t);
      expect(t.status, TaskStatus.done);
      expect(s.history.single.kind, HistoryKind.done);
    });

    test('desfazer restaura a tarefa e remove o registro do histórico', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 13));
      s.complete(t);
      s.undo();
      expect(t.status, TaskStatus.pending);
      expect(s.history, isEmpty);
    });

    test('recorrente concluída hoje passa para a próxima ocorrência', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring, rule: daily, due: DateTime(2026, 10, 13));
      s.complete(t);
      expect(t.status, TaskStatus.pending);
      expect(t.due, DateTime(2026, 10, 14));
    });

    test('ocorrências perdidas não contaminam as futuras', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring, rule: daily, due: DateTime(2026, 10, 10));
      s.complete(t);
      expect(t.due, DateTime(2026, 10, 14));
    });

    test('recorrente não pode ser concluída antes do dia da ocorrência', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring, rule: daily, due: DateTime(2026, 10, 15));
      expect(s.canComplete(t), isFalse);
      expect(s.complete(t), isFalse);
      expect(s.skip(t), isFalse);
      expect(t.due, DateTime(2026, 10, 15));
      expect(s.history, isEmpty);
    });

    test('cliques repetidos em concluir não fazem a recorrente andar', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring, rule: daily, due: DateTime(2026, 10, 13));
      expect(s.complete(t), isTrue);
      expect(s.complete(t), isFalse);
      expect(s.complete(t), isFalse);
      expect(t.due, DateTime(2026, 10, 14));
      expect(s.history.length, 1);
    });

    test('única e reutilizável não têm a trava', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.single, due: DateTime(2026, 12, 1));
      expect(s.canComplete(t), isTrue);
    });

    test('pular só avança a ocorrência e registra no histórico', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring, rule: daily, due: DateTime(2026, 10, 13));
      s.skip(t);
      expect(t.due, DateTime(2026, 10, 14));
      expect(s.history.single.kind, HistoryKind.skipped);
    });

    test('doneToday conta as conclusões do dia', () {
      final s = _state();
      s.complete(_task(s, kind: TaskKind.single));
      s.complete(_task(s, kind: TaskKind.single));
      expect(s.doneToday(), 2);
    });
  });

  group('reutilizável', () {
    test('concluir e "preciso de novo" mantêm cada passo no histórico', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.reusable);
      s.complete(t);
      expect(t.status, TaskStatus.done);
      expect(t.lastDoneAt, _now);
      s.reopen(t);
      expect(t.status, TaskStatus.pending);
      expect(s.history.map((e) => e.kind),
          [HistoryKind.done, HistoryKind.reopened]);
    });

    test('pendente e sem data aparece em HOJE', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.reusable);
      expect(s.todayView().hoje, [t]);
    });
  });

  group('tela Hoje', () {
    test('separa AGORA, HOJE e EM BREVE', () {
      final s = _state();
      final late = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 11));
      final soon = _task(s,
          kind: TaskKind.single,
          due: DateTime(2026, 10, 13),
          time: const TimeOfDay(hour: 10, minute: 30));
      final today = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 13));
      final coming = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 15));
      _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 18)); // longe demais

      final v = s.todayView();
      expect(v.agora, containsAll([late, soon]));
      expect(v.agora.length, 2);
      expect(v.hoje, [today]);
      expect(v.breve, [coming]);
    });

    test('tarefa adiada para depois some até a hora de voltar', () {
      final s = _state();
      final t = _task(s, kind: TaskKind.single, due: DateTime(2026, 10, 13));
      s.snooze(t, DateTime(2026, 10, 13, 20));
      expect(t.status, TaskStatus.snoozed);
      expect(s.todayView().isEmpty, isTrue);
    });
  });

  group('revisão de tarefas antigas', () {
    test('única sem atualização entra na fila e sai ao manter pendente', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.single, createdAt: _now.subtract(const Duration(days: 20)));
      expect(s.needsReview(t), isTrue);
      expect(s.reviewQueue, [t]);
      s.keepPending(t);
      expect(s.needsReview(t), isFalse);
    });

    test('recorrente muito atrasada sai da fila ao manter pendente', () {
      final s = _state();
      final t = _task(s,
          kind: TaskKind.recurring,
          rule: daily,
          due: DateTime(2026, 9, 23),
          createdAt: _now.subtract(const Duration(days: 20)));
      expect(s.needsReview(t), isTrue);
      s.keepPending(t);
      expect(s.needsReview(t), isFalse);
      expect(t.due, DateTime(2026, 9, 23)); // nada é apagado nem reescrito
    });

    test('tarefa em revisão não aparece no Hoje', () {
      final s = _state();
      _task(s,
          kind: TaskKind.single, createdAt: _now.subtract(const Duration(days: 20)));
      expect(s.todayView().isEmpty, isTrue);
    });
  });
}
