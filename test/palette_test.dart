import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/app/palette.dart';

import 'fake_store.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('paletas', () {
    test('ids e nomes são únicos', () {
      expect(AppPalette.all.map((p) => p.id).toSet().length, AppPalette.all.length);
      expect(AppPalette.all.map((p) => p.name).toSet().length, AppPalette.all.length);
      expect(AppPalette.all.length, 5);
    });

    test('todas têm contraste legível (texto principal e secundário)', () {
      for (final p in AppPalette.all) {
        expect(_contrast(p.fg, p.bg), greaterThanOrEqualTo(7), reason: '${p.id} fg/bg');
        expect(_contrast(p.dim, p.bg), greaterThanOrEqualTo(4.5), reason: '${p.id} dim/bg');
        expect(_contrast(p.dim, p.surface), greaterThanOrEqualTo(4.5),
            reason: '${p.id} dim/surface');
        expect(_contrast(p.warn, p.bg), greaterThanOrEqualTo(4.5), reason: '${p.id} warn');
        expect(_contrast(p.alert, p.bg), greaterThanOrEqualTo(4.5), reason: '${p.id} alert');
      }
    });
  });

  group('efeitos', () {
    test('granulado é um nível próprio, com brilho forte e textura', () {
      expect(EffectLevel.grain.label, 'GRANULADO');
      expect(EffectLevel.grain.strong, isTrue);
      expect(EffectLevel.grain.hasGrain, isTrue);
      expect(EffectLevel.full.hasGrain, isFalse);
      expect(EffectLevel.soft.strong, isFalse);
      expect(EffectLevel.off.strong, isFalse);
    });

    test('paleta e efeito novos persistem', () async {
      final store = FakeStore();
      final a = AppState(store: store);
      a.setPalette(AppPalette.pink);
      a.setEffects(EffectLevel.grain);
      await Future<void>.delayed(Duration.zero);

      final b = AppState(store: store);
      await b.load();
      expect(b.palette.id, 'rosa');
      expect(b.effects, EffectLevel.grain);

      a.setPalette(AppPalette.ice);
      await Future<void>.delayed(Duration.zero);
      final c = AppState(store: store);
      await c.load();
      expect(c.palette.id, 'gelo');
    });
  });
}
