import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/app/palette.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

final DateTime _now = DateTime(2026, 10, 13, 10, 0);

AppState _open(FakeStore store) =>
    AppState(clock: () => _now, store: store);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('codec', () {
    test('tarefa recorrente faz ida e volta', () {
      final t = Task(
        id: 't-1',
        title: 'Academia',
        kind: TaskKind.recurring,
        createdAt: _now,
        due: DateTime(2026, 10, 14),
        time: const TimeOfDay(hour: 7, minute: 30),
        recurrence: const Recurrence(
          type: RecurrenceType.weekdays,
          weekdays: {1, 3, 5},
        ),
        notes: 'levar toalha',
      );
      final back = taskFromMap(taskToMap(t));
      expect(back.title, 'Academia');
      expect(back.kind, TaskKind.recurring);
      expect(back.due, DateTime(2026, 10, 14));
      expect(back.time, const TimeOfDay(hour: 7, minute: 30));
      expect(back.recurrence!.type, RecurrenceType.weekdays);
      expect(back.recurrence!.weekdays, {1, 3, 5});
      expect(back.notes, 'levar toalha');
    });

    test('tarefa sem prazo nem regra faz ida e volta', () {
      final t = Task(id: 't-2', title: 'X', kind: TaskKind.single, createdAt: _now);
      final back = taskFromMap(taskToMap(t));
      expect(back.due, isNull);
      expect(back.time, isNull);
      expect(back.recurrence, isNull);
    });

    test('nota faz ida e volta', () {
      final n = Note(id: 'n-1', text: 'ideia', createdAt: _now, isIdea: true);
      final back = noteFromMap(noteToMap(n));
      expect(back.isIdea, isTrue);
      expect(back.converted, isFalse);
      expect(back.text, 'ideia');
    });
  });

  group('persistência', () {
    test('tarefa criada e concluída volta depois de reabrir', () async {
      final store = FakeStore();
      final a = _open(store);
      final t = Task(
        id: a.newId('t'),
        title: 'Pagar conta',
        kind: TaskKind.single,
        createdAt: _now,
        due: DateTime(2026, 10, 13),
      );
      a.saveTask(t, isNew: true);
      a.complete(t);
      await _settle();

      final b = _open(store);
      await b.load();
      expect(b.tasks.single.status, TaskStatus.done);
      expect(b.history.map((e) => e.kind),
          [HistoryKind.created, HistoryKind.done]);
    });

    test('desfazer também desfaz no banco', () async {
      final store = FakeStore();
      final a = _open(store);
      final t = Task(
          id: a.newId('t'), title: 'X', kind: TaskKind.single, createdAt: _now);
      a.saveTask(t, isNew: true);
      a.complete(t);
      a.undo();
      await _settle();
      expect(store.tasks[t.id]!.status, TaskStatus.pending);
      expect(store.history.length, 1); // só o "criada"
    });

    test('notas: apagar é lógico e desfazer traz de volta', () async {
      final store = FakeStore();
      final a = _open(store);
      final n = a.addNote('lembrar');
      final i = a.removeNote(n);
      await _settle();
      expect((await store.load()).notes, isEmpty);
      a.insertNote(i, n);
      await _settle();
      expect((await store.load()).notes.length, 1);
    });

    test('configurações voltam ao abrir', () async {
      final store = FakeStore();
      final a = _open(store);
      a.setPalette(AppPalette.amber);
      a.setEffects(EffectLevel.off);
      a.setReviewAfterDays(21);
      await _settle();

      final b = _open(store);
      await b.load();
      expect(b.palette, AppPalette.amber);
      expect(b.effects, EffectLevel.off);
      expect(b.reviewAfterDays, 21);
    });

    test('dados de exemplo só entram com o app vazio', () async {
      final store = FakeStore();
      final a = _open(store);
      a.loadSampleData();
      final count = a.tasks.length;
      expect(count, greaterThan(0));
      a.loadSampleData();
      expect(a.tasks.length, count);
      await _settle();
      expect(store.tasks.length, count);
    });
  });
}
