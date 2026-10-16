import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/dates.dart';
import 'package:organizador/core/entry.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

// Quinta-feira, 15/10/2026, 15:00.
DateTime _clock = DateTime(2026, 10, 15, 15, 0);

AppState _app([FakeStore? store]) => AppState(clock: () => _clock, store: store);

void main() {
  setUp(() => _clock = DateTime(2026, 10, 15, 15, 0));

  group('registros (codec)', () {
    test('ida e volta com campos de texto e número', () {
      final e = Entry(
        id: 'e1',
        module: kModBook,
        at: DateTime(2026, 10, 1, 8),
        data: {'title': 'Livro', 'page': 12, 'total': 300},
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final back = entryFromMap(entryToMap(e));
      expect(back.module, kModBook);
      expect(back.text('title'), 'Livro');
      expect(back.number('page'), 12);
      expect(back.number('total'), 300);
      expect(back.number('ausente'), isNull);
      expect(back.text('ausente'), '');
    });

    test('aceita data como objeto (formato do backup)', () {
      final m = entryToMap(Entry(
        id: 'e1',
        module: kModFood,
        at: _clock,
        data: {'text': 'arroz'},
        createdAt: _clock,
      ))
        ..['data'] = {'text': 'arroz'};
      expect(entryFromMap(m).text('text'), 'arroz');
    });

    test('rejeita data que não é objeto', () {
      final m = entryToMap(Entry(id: 'e', module: kModFood, at: _clock, createdAt: _clock))
        ..['data'] = '[1,2]';
      expect(() => entryFromMap(m), throwsFormatException);
    });
  });

  group('AppState', () {
    test('lista por módulo, mais recente primeiro', () {
      final s = _app();
      s.addEntry(kModFood, at: DateTime(2026, 10, 14, 12), data: {'text': 'a'});
      s.addEntry(kModFood, at: DateTime(2026, 10, 15, 8), data: {'text': 'b'});
      s.addEntry(kModExercise, data: {'kind': 'x'});
      expect(s.entriesOf(kModFood).map((e) => e.text('text')), ['b', 'a']);
      expect(s.entriesOf(kModExercise).length, 1);
    });

    test('água: conta só os ml do dia (registro antigo vale 200 ml)', () {
      final s = _app();
      s.addWater();
      s.addWater();
      s.addEntry(kModWater, at: DateTime(2026, 10, 14, 20));
      expect(s.waterMlOn(_clock), 400);
      expect(s.waterMlOn(DateTime(2026, 10, 14)), 200);
    });

    test('água: tirar o último gole de hoje, e desfazer', () {
      final s = _app();
      s.addWater();
      final removed = s.removeLastWater();
      expect(removed, isNotNull);
      expect(s.waterMlOn(_clock), 0);
      expect(s.removeLastWater(), isNull);
      s.insertEntry(s.entries.length, removed!);
      expect(s.waterMlOn(_clock), 200);
    });

    test('meta de água fica entre 0,5 e 6 litros', () {
      final s = _app();
      s.setWaterGoalMl(0);
      expect(s.waterGoalMl, 500);
      s.setWaterGoalMl(99999);
      expect(s.waterGoalMl, 6000);
    });

    test('editar muda campos e horário; apagar e desfazer', () {
      final s = _app();
      final e = s.addEntry(kModFood, data: {'text': 'antes'});
      s.updateEntry(e, at: DateTime(2026, 10, 14, 9), data: {'text': 'depois'});
      expect(e.text('text'), 'depois');
      expect(e.at, DateTime(2026, 10, 14, 9));
      final i = s.removeEntry(e);
      expect(s.entries, isEmpty);
      s.insertEntry(i, e);
      expect(s.entries, [e]);
    });

    test('persiste e volta ao reabrir; apagar remove do banco', () async {
      final store = FakeStore();
      final a = _app(store);
      final e = a.addEntry(kModBook, data: {'title': 'T', 'page': 3});
      a.setWaterGoalMl(3000);
      a.updateEntry(e, data: {'title': 'T', 'page': 50});
      await Future<void>.delayed(Duration.zero);

      final b = _app(store);
      await b.load();
      expect(b.entries.single.number('page'), 50);
      expect(b.waterGoalMl, 3000);

      b.removeEntry(b.entries.single);
      await Future<void>.delayed(Duration.zero);
      expect(store.entries, isEmpty);
    });

    test('dados de exemplo incluem os módulos', () {
      final s = _app()..loadSampleData();
      for (final m in [kModWater, kModFood, kModExercise, kModBook]) {
        expect(s.entriesOf(m), isNotEmpty, reason: m);
      }
    });
  });

  group('backup', () {
    test('leva os registros (data como objeto legível) e a meta de água', () {
      final s = _app();
      s.addEntry(kModBook, data: {'title': 'T', 'page': 7});
      s.setWaterGoalMl(2500);
      final text = encodeBackup(s.exportSnapshot(), _clock);
      final map = jsonDecode(text) as Map<String, dynamic>;
      expect((map['entries'] as List).single['data'], {'title': 'T', 'page': 7});
      expect((map['settings'] as Map)['waterGoalMl'], '2500');

      final back = decodeBackup(text);
      expect(back.entryCount, 1);
      expect(back.snapshot.entries.single.number('page'), 7);
      expect(back.snapshot.settings['waterGoalMl'], '2500');
    });

    test('formata litros', () {
      expect(fmtLiters(2000), '2,0 L');
      expect(fmtLiters(1250), '1,25 L');
    });

    test('rotina de módulo sobrevive ao backup', () {
      final s = _app();
      s.saveTask(
        Task(
          id: 'ex',
          title: 'Corrida',
          kind: TaskKind.recurring,
          createdAt: _clock,
          due: DateTime(2026, 10, 16),
          recurrence: const Recurrence(type: RecurrenceType.daily),
          module: kModExercise,
        ),
        isNew: true,
      );
      final back = decodeBackup(encodeBackup(s.exportSnapshot(), _clock));
      expect(back.snapshot.tasks.single.module, kModExercise);
    });

    test('backup antigo, sem "entries", ainda abre', () {
      final s = _app();
      final map = jsonDecode(encodeBackup(s.exportSnapshot(), _clock)) as Map<String, dynamic>;
      map.remove('entries');
      expect(decodeBackup(jsonEncode(map)).entryCount, 0);
    });

    test('registro corrompido no backup é recusado', () {
      final s = _app();
      final map = jsonDecode(encodeBackup(s.exportSnapshot(), _clock)) as Map<String, dynamic>;
      map['entries'] = [
        {'id': 'x'}
      ];
      expect(() => decodeBackup(jsonEncode(map)), throwsA(isA<BackupFormatException>()));
    });

    test('restaurar troca os registros e a meta', () async {
      final s = _app(FakeStore());
      s.addEntry(kModFood, data: {'text': 'velho'});
      final other = _app();
      other.addEntry(kModFood, data: {'text': 'novo'});
      other.setWaterGoalMl(4000);
      await s.restoreFrom(other.exportSnapshot());
      expect(s.entries.map((e) => e.text('text')), ['novo']);
      expect(s.waterGoalMl, 4000);
    });
  });
}
