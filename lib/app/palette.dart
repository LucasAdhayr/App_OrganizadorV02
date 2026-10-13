import 'package:flutter/material.dart';

enum EffectLevel { off, soft, full }

extension EffectLevelX on EffectLevel {
  String get label => switch (this) {
        EffectLevel.off => 'OFF',
        EffectLevel.soft => 'SUAVE',
        EffectLevel.full => 'COMPLETO',
      };
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

  static const List<AppPalette> all = [green, amber, cyan];
}
