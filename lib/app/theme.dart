import 'package:flutter/material.dart';

import 'palette.dart';

/// Fonte do sistema (monoespaçada, com acentos). Em uma etapa futura dá para
/// embutir IBM Plex Mono em assets/fonts e trocar só esta constante.
const String kFont = 'monospace';

ThemeData buildTheme(AppPalette p, EffectLevel fx) {
  final glow = fx == EffectLevel.off
      ? <Shadow>[]
      : <Shadow>[
          Shadow(
            color: p.fg.withValues(alpha: fx == EffectLevel.full ? 0.55 : 0.30),
            blurRadius: fx == EffectLevel.full ? 8 : 5,
          ),
        ];

  final scheme = ColorScheme.dark(
    primary: p.fg,
    onPrimary: p.bg,
    secondary: p.dim,
    onSecondary: p.bg,
    error: p.alert,
    onError: p.bg,
    surface: p.surface,
    onSurface: p.fg,
    outline: p.dim,
    outlineVariant: p.line,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.surface,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: kFont,
  );
  final tt = base.textTheme.apply(bodyColor: p.fg, displayColor: p.fg);
  TextStyle? g(TextStyle? s) => s?.copyWith(shadows: glow);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    dividerColor: p.line,
    iconTheme: IconThemeData(color: p.fg),
    textTheme: tt.copyWith(
      bodyLarge: g(tt.bodyLarge),
      bodyMedium: g(tt.bodyMedium),
      bodySmall: g(tt.bodySmall),
      titleLarge: g(tt.titleLarge),
      titleMedium: g(tt.titleMedium),
      titleSmall: g(tt.titleSmall),
      labelLarge: g(tt.labelLarge),
      labelMedium: g(tt.labelMedium),
    ),
  );
}
