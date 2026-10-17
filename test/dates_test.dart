import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/core/reminders.dart';
import 'package:organizador/core/special_dates.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

// Quarta-feira, 14/10/2026, 10:00.
final DateTime _now = DateTime(2026, 10, 14, 10, 0);

SpecialDate _d(String id, int month, int day,
        {int? year, DateKind kind = DateKind.birthday, String title = 'Ana'}) =>
    SpecialDate(
      id: id,
      title: title,
      kind: kind,
      month: month,
      day: day,
      year: year,
      createdAt: _now,
    );

void main() {
  group('próxima ocorrência', () {
    test('hoje conta como próxima', () {
      expect(nextOccurrence(10, 14, _now), DateTime(2026, 10, 14));
    });

    test('já passou este ano: vai para o ano que vem', () {
      expect(nextOccurrence(10, 13, _now), DateTime(2027, 10, 13));
      expect(nextOccurrence(1, 1, _now), DateTime(2027, 1, 1));
    });

    test('ainda não chegou: este ano', () {
      expect(nextOccurrence(12, 25, _now), DateTime(2026, 12, 25));
    });

    test('29/02 cai em 28/02 nos anos não bissextos e em 29/02 nos bissextos', () {
      expect(nextOccurrence(2, 29, _now), DateTime(2027, 2, 28));
      expect(nextOccurrence(2, 29, DateTime(2027, 10, 1)), DateTime(2028, 2, 29));
    });
  });

  group('idade e descrição', () {
    test('com ano mostra a idade que faz', () {
      final d = _d('a', 12, 25, year: 1990);
      expect(d.turningAge(_now), 36);
      expect(d.describe(_now), 'faz 36 anos');
    });

    test('hoje é aniversário: a idade é a de hoje', () {
      expect(_d('a', 10, 14, year: 2000).describe(_now), 'faz 26 anos');
    });

    test('sem ano mostra só o tipo', () {
      expect(_d('a', 12, 25).describe(_now), 'aniversário');
      expect(_d('a', 12, 25, kind: DateKind.date).describe(_now), 'data');
    });

    test('data com ano mostra há quantos anos', () {
      expect(_d('a', 12, 25, year: 2020, kind: DateKind.date).describe(_now), '6 anos');
    });
  });

  group('lembretes de datas', () {
    test('véspera e dia às 09:00', () {
      final r = planReminders(const <Task>[], _now, dates: [_d('a', 10, 16, year: 1990)]);
      expect(r.map((x) => x.at), [DateTime(2026, 10, 15, 9), DateTime(2026, 10, 16, 9)]);
      expect(r.first.body, 'Faz 36 anos amanhã');
      expect(r.last.body, 'Faz 36 anos hoje');
      expect(r.first.title, 'Ana');
    });

    test('hoje depois das 09:00: nada de hoje, nada do ano que vem ainda', () {
      final r = planReminders(const <Task>[], _now, dates: [_d('a', 10, 14)]);
      expect(r, isEmpty);
    });

    test('hoje antes das 09:00 ainda avisa', () {
      final early = DateTime(2026, 10, 14, 7, 0);
      final r = planReminders(const <Task>[], early, dates: [_d('a', 10, 14)]);
      expect(r.single.at, DateTime(2026, 10, 14, 9));
    });

    test('data comum diz "Data importante"', () {
      final r = planReminders(const <Task>[], _now,
          dates: [_d('a', 10, 20, kind: DateKind.date, title: 'Prova')]);
      expect(r.last.body, 'Data importante hoje');
    });

    test('ids diferentes por data e por tipo de aviso', () {
      final r = planReminders(const <Task>[], _now,
          dates: [_d('a', 10, 20), _d('b', 10, 20)]);
      expect(r.map((x) => x.id).toSet().length, 4);
    });
  });

  group('AppState', () {
    test('ordena pela próxima ocorrência e filtra as próximas', () {
      final s = AppState(clock: () => _now);
      s.saveDate(_d('longe', 12, 25), isNew: true);
      s.saveDate(_d('hoje', 10, 14), isNew: true);
      s.saveDate(_d('passou', 10, 1), isNew: true);
      s.saveDate(_d('amanha', 10, 15), isNew: true);
      expect(s.datesByNext().map((d) => d.id), ['hoje', 'amanha', 'longe', 'passou']);
      expect(s.upcomingDates().map((d) => d.id), ['hoje', 'amanha']);
    });

    test('apagar e desfazer devolvem na mesma posição', () {
      final s = AppState(clock: () => _now);
      final a = _d('a', 10, 20);
      final b = _d('b', 10, 21);
      s.saveDate(a, isNew: true);
      s.saveDate(b, isNew: true);
      final i = s.removeDate(a);
      expect(s.dates, [b]);
      s.insertDate(i, a);
      expect(s.dates, [a, b]);
    });

    test('editar nota troca o texto e persiste', () async {
      final store = FakeStore();
      final s = AppState(clock: () => _now, store: store);
      final n = s.addNote('rascunho');
      s.editNote(n, 'versão final');
      await Future<void>.delayed(Duration.zero);
      expect(store.notes[n.id]!.text, 'versão final');
    });

    test('datas persistem e voltam ao reabrir; apagar remove do banco', () async {
      final store = FakeStore();
      final a = AppState(clock: () => _now, store: store);
      final d = _d('x', 3, 8, year: 1980);
      a.saveDate(d, isNew: true);
      await Future<void>.delayed(Duration.zero);

      final b = AppState(clock: () => _now, store: store);
      await b.load();
      expect(b.dates.single.title, 'Ana');
      expect(b.dates.single.year, 1980);

      b.removeDate(b.dates.single);
      await Future<void>.delayed(Duration.zero);
      expect(store.dates, isEmpty);
    });

    test('dados de exemplo incluem datas', () {
      final s = AppState(clock: () => _now)..loadSampleData();
      expect(s.dates, isNotEmpty);
    });

    test('lembretes consideram as datas', () {
      final s = AppState(clock: () => _now)..waterReminders = false;
      s.saveDate(_d('a', 10, 20), isNew: true);
      expect(s.plannedReminders.length, 2);
    });
  });

  group('codec e backup', () {
    test('ida e volta de uma data', () {
      final back = dateFromMap(dateToMap(_d('a', 2, 29, year: 1992)));
      expect(back.month, 2);
      expect(back.day, 29);
      expect(back.year, 1992);
      expect(back.kind, DateKind.birthday);
    });

    test('rejeita dia/mês impossível', () {
      final m = dateToMap(_d('a', 10, 14))..['month'] = 13;
      expect(() => dateFromMap(m), throwsFormatException);
    });

    test('backup leva as datas e restaura', () {
      final s = AppState(clock: () => _now);
      s.saveDate(_d('a', 5, 5, year: 2001), isNew: true);
      final data = decodeBackup(encodeBackup(s.exportSnapshot(), _now));
      expect(data.dateCount, 1);
      expect(data.snapshot.dates.single.year, 2001);
    });

    test('backup antigo, sem a chave "dates", ainda abre', () {
      final s = AppState(clock: () => _now);
      var text = encodeBackup(s.exportSnapshot(), _now);
      text = text.replaceAll(RegExp(r',\s*"dates": \[\s*\]'), '');
      expect(text.contains('"dates": ['), isFalse); // o resumo counts ainda tem dates: 0
      expect(decodeBackup(text).dateCount, 0);
    });

    test('restaurar troca as datas', () async {
      final s = AppState(clock: () => _now, store: FakeStore());
      s.saveDate(_d('velha', 1, 1), isNew: true);
      final other = AppState(clock: () => _now);
      other.saveDate(_d('nova', 2, 2), isNew: true);
      await s.restoreFrom(other.exportSnapshot());
      expect(s.dates.map((d) => d.id), ['nova']);
    });
  });
}
