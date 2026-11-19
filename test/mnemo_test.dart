import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/entry.dart';

import 'fake_store.dart';

void main() {
  group('anotações de livro', () {
    test('ficam ligadas ao livro e persistem', () async {
      final store = FakeStore();
      final a = AppState(store: store);
      final book = a.addEntry(kModBook, data: {'title': 'Odisseia', 'status': 'lendo'});
      final other = a.addEntry(kModBook, data: {'title': 'Ilíada', 'status': 'lendo'});
      a.addEntry(kModBookNote, data: {'book': book.id, 'text': 'Calipso', 'page': 40});
      a.addEntry(kModBookNote, data: {'book': other.id, 'text': 'Aquiles'});
      await Future<void>.delayed(Duration.zero);

      final b = AppState(store: store);
      await b.load();
      final mine = b.entriesOf(kModBookNote).where((n) => n.text('book') == book.id).toList();
      expect(mine.length, 1);
      expect(mine.first.text('text'), 'Calipso');
      expect(mine.first.number('page'), 40);
    });
  });

  group('doses persistem', () {
    test('marcação sobrevive ao recarregar', () async {
      final store = FakeStore();
      final a = AppState(store: store);
      a.addEntry(kModDose, data: {'med': 'm1', 'key': 'm1|2026-10-13 08:00', 'status': 'taken'});
      await Future<void>.delayed(Duration.zero);
      final b = AppState(store: store);
      await b.load();
      expect(b.resolvedDoseKeys, {'m1|2026-10-13 08:00'});
    });
  });
}
