import 'package:flutter/material.dart';

/// Efeitos de tela. `grain` é o COMPLETO mais granulado (ruído fixo de filme).
enum EffectLevel { off, soft, full, grain }

extension EffectLevelX on EffectLevel {
  String get label => switch (this) {
        EffectLevel.off => 'OFF',
        EffectLevel.soft => 'SUAVE',
        EffectLevel.full => 'COMPLETO',
        EffectLevel.grain => 'GRANULADO',
      };

  /// Brilho forte, linhas mais marcadas e vinheta (COMPLETO e GRANULADO).
  bool get strong => this == EffectLevel.full || this == EffectLevel.grain;

  /// Textura de granulado por cima de tudo.
  bool get hasGrain => this == EffectLevel.grain;
}

/// Todas as cores do app vêm daqui. Para criar um tema novo, basta
/// adicionar mais uma paleta em [AppPalette.all].
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.bg,
    required this.surface,
    required this.fg,
    required this.dim,
    required this.line,
    required this.warn,
    required this.alert,
  });

  final String id;
  final String name;

  /// Fundo.
  final Color bg;

  /// Painéis, barras e folhas.
  final Color surface;

  /// Texto e destaques (fósforo).
  final Color fg;

  /// Texto secundário.
  final Color dim;

  /// Linhas muito discretas.
  final Color line;

  /// Atenção (atrasos). Sempre acompanhada de "!".
  final Color warn;

  /// Erro e ações destrutivas.
  final Color alert;

  static const AppPalette green = AppPalette(
    id: 'verde',
    name: 'VERDE',
    bg: Color(0xFF040A06),
    surface: Color(0xFF0A140D),
    fg: Color(0xFF3DFF7A),
    dim: Color(0xFF1FA050),
    line: Color(0xFF16351F),
    warn: Color(0xFFFFB84D),
    alert: Color(0xFFFF6B6B),
  );

  static const AppPalette amber = AppPalette(
    id: 'ambar',
    name: 'ÂMBAR',
    bg: Color(0xFF0A0703),
    surface: Color(0xFF140E05),
    fg: Color(0xFFFFB000),
    dim: Color(0xFFB87A00),
    line: Color(0xFF3A2A08),
    warn: Color(0xFFFF8A4D),
    alert: Color(0xFFFF6B6B),
  );

  static const AppPalette cyan = AppPalette(
    id: 'ciano',
    name: 'CIANO',
    bg: Color(0xFF030A0D),
    surface: Color(0xFF081319),
    fg: Color(0xFF33E6FF),
    dim: Color(0xFF1E93A8),
    line: Color(0xFF0F3440),
    warn: Color(0xFFFFB84D),
    alert: Color(0xFFFF6B6B),
  );

  /// Rosa neon. O "dim" é claro o bastante para texto pequeno.
  static const AppPalette pink = AppPalette(
    id: 'rosa',
    name: 'ROSA',
    bg: Color(0xFF0D040B),
    surface: Color(0xFF170A14),
    fg: Color(0xFFFF5FD2),
    dim: Color(0xFFD04DAA),
    line: Color(0xFF3A1730),
    warn: Color(0xFFFFB84D),
    alert: Color(0xFFFF6B6B),
  );

  /// Branco-gelo, quase monocromático: o mais discreto e confortável à noite.
  static const AppPalette ice = AppPalette(
    id: 'gelo',
    name: 'GELO',
    bg: Color(0xFF05080B),
    surface: Color(0xFF0C1218),
    fg: Color(0xFFE6F4FF),
    dim: Color(0xFF8FA8BA),
    line: Color(0xFF1D2A35),
    warn: Color(0xFFFFB84D),
    alert: Color(0xFFFF6B6B),
  );

  static const List<AppPalette> all = [green, amber, cyan, pink, ice];
}
