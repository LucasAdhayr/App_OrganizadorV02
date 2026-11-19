import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/palette.dart';

// ----------------------------------------------------------------- divisores

class TermDivider extends StatelessWidget {
  const TermDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(p.dim.withValues(alpha: 0.5))),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 4, size.width), 0.5), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Friso grego (meandro): faixa decorativa sob o título de cada tela.
class MeanderDivider extends StatelessWidget {
  const MeanderDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: 10,
      width: double.infinity,
      child: CustomPaint(painter: _MeanderPainter(p.dim.withValues(alpha: 0.75))),
    );
  }
}

class _MeanderPainter extends CustomPainter {
  _MeanderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.miter;
    const w = 14.0;
    final h = size.height - 1;
    canvas.drawLine(Offset(0, h), Offset(size.width, h), paint);
    for (var x = 0.0; x + w <= size.width; x += w + 4) {
      final path = Path()
        ..moveTo(x, h)
        ..lineTo(x, 0.5)
        ..lineTo(x + w, 0.5)
        ..lineTo(x + w, h * 0.7)
        ..lineTo(x + w * 0.35, h * 0.7)
        ..lineTo(x + w * 0.35, h * 0.38)
        ..lineTo(x + w * 0.7, h * 0.38);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MeanderPainter old) => old.color != color;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == null ? '> $label' : '> $label ($count)',
            style: TextStyle(
              color: p.fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const TermDivider(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- títulos

/// Título de tela. No nível COMPLETO ganha aberração cromática estática
/// (sem animação, para não distrair).
class GlitchTitle extends StatelessWidget {
  const GlitchTitle(this.text, {super.key, this.size = 20});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
      color: s.palette.fg,
    );
    final label = text.toUpperCase();
    if (!s.effects.strong) {
      return Text(label, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    const noGlow = <Shadow>[];
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(-1.6, 0),
          child: Text(label,
              maxLines: 1,
              style: base.copyWith(color: const Color(0xAAFF2D55), shadows: noGlow)),
        ),
        Transform.translate(
          offset: const Offset(1.6, 0),
          child: Text(label,
              maxLines: 1,
              style: base.copyWith(color: const Color(0xAA2DE2FF), shadows: noGlow)),
        ),
        Text(label, style: base, maxLines: 1),
      ],
    );
  }
}

class TermTopBar extends StatelessWidget {
  const TermTopBar({
    super.key,
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(width: 56, child: Center(child: leading)),
              Expanded(child: Center(child: GlitchTitle(title))),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56),
                child: Center(child: trailing),
              ),
            ],
          ),
        ),
        const MeanderDivider(),
      ],
    );
  }
}

/// Moldura das telas empilhadas (histórico, configurações, formulários...).
class TermScaffold extends StatelessWidget {
  const TermScaffold({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? action;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TermTopBar(
              leading: IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: title,
              trailing: action ?? const SizedBox(width: 48),
            ),
            Expanded(child: body),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- linhas

class TermMarker extends StatelessWidget {
  const TermMarker({super.key, this.checked = false, this.overdue = false, this.onTap});

  final bool checked;
  final bool overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final text = checked ? '[x]' : (overdue ? '[!]' : '[ ]');
    return Semantics(
      button: true,
      label: checked ? 'Concluída' : 'Concluir',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: overdue ? p.warn : p.fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de lista em estilo terminal. Pressionada, vira vídeo invertido.
class TermRow extends StatefulWidget {
  const TermRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.trailingColor,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  State<TermRow> createState() => _TermRowState();
}

class _TermRowState extends State<TermRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    const noGlow = <Shadow>[];
    final titleColor = _down ? p.bg : p.fg;
    final dimColor = _down ? p.bg : p.dim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        color: _down ? p.fg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            ?widget.leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      height: 1.25,
                      shadows: _down ? noGlow : null,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dimColor,
                        fontSize: 12,
                        shadows: _down ? noGlow : null,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  widget.trailing!,
                  style: TextStyle(
                    color: _down ? p.bg : (widget.trailingColor ?? p.dim),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: _down ? noGlow : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- botões

class TermButton extends StatefulWidget {
  const TermButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.selected = false,
    this.expand = false,
    this.dense = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final bool selected;
  final bool expand;
  final bool dense;
  final IconData? icon;

  @override
  State<TermButton> createState() => _TermButtonState();
}

class _TermButtonState extends State<TermButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = widget.onPressed != null;
    final accent = widget.danger ? p.alert : p.fg;
    final filled = enabled && (widget.primary || widget.selected || _down);
    final border = !enabled
        ? p.dim.withValues(alpha: 0.4)
        : (widget.danger ? p.alert : (widget.primary || widget.selected ? p.fg : p.dim));
    final textColor = !enabled
        ? p.dim.withValues(alpha: 0.6)
        : (filled ? p.bg : accent);

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: widget.dense ? 12 : 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              shadows: filled || !enabled ? const <Shadow>[] : null,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.dense ? 44 : 48),
          padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 14, vertical: 8),
          decoration: BoxDecoration(
            color: filled ? (widget.danger ? p.alert : p.fg) : Colors.transparent,
            border: Border.all(color: border),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Barra de progresso em blocos: [■■■■□□□□□□].
class BlockBar extends StatelessWidget {
  const BlockBar({super.key, required this.value, this.cells = 10});

  final double value;
  final int cells;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final v = (value.isNaN ? 0.0 : value.clamp(0.0, 1.0)).toDouble();
    final filled = (v * cells).round();
    return Text(
      '[${'■' * filled}${'□' * (cells - filled)}]',
      style: TextStyle(color: p.fg, fontSize: 13, letterSpacing: 1),
    );
  }
}

// ---------------------------------------------------------------- decoração

/// Esfera em wireframe desenhada por código (sem arte de terceiros).
class WireGlobe extends StatelessWidget {
  const WireGlobe({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dim = context.pal.dim;
    // A esfera guarda o Μ de Mnemosine.
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _GlobePainter(dim)),
          Text(
            'Μ',
            style: TextStyle(
              color: dim,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, r, paint);
    for (final k in const [0.35, 0.7]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: 2 * r * k, height: 2 * r), paint);
      canvas.drawOval(Rect.fromCenter(center: c, width: 2 * r, height: 2 * r * k), paint);
    }
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
  }

  @override
  bool shouldRepaint(_GlobePainter old) => old.color != color;
}

/// Scanlines, vinheta e (no GRANULADO) ruído por cima de tudo. Estático: não
/// consome bateria e nada pisca.
class CrtOverlay extends StatelessWidget {
  const CrtOverlay({super.key, required this.level});

  final EffectLevel level;

  @override
  Widget build(BuildContext context) {
    if (level == EffectLevel.off) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _CrtPainter(level),
              // Granulado: uma camada própria, que só é redesenhada se a tela
              // ou o efeito mudar (ruído fixo: não pisca nem consome bateria).
              foregroundPainter: level.hasGrain ? _GrainPainter(warm: level.isAntique) : null,
            ),
            if (level.hasTape) const CustomPaint(size: Size.infinite, painter: _TapePainter()),
            if (level.isAntique) const CustomPaint(size: Size.infinite, painter: _AgedPainter()),
          ],
        ),
      ),
    );
  }
}

class _CrtPainter extends CustomPainter {
  _CrtPainter(this.level);

  final EffectLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final full = level.strong;
    final line = Paint()
      ..color = Colors.black.withValues(alpha: full ? 0.22 : (level.isAntique ? 0.06 : 0.12));
    final step = full ? 3.0 : 4.0;
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), line);
    }
    final rect = Offset.zero & size;
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [Colors.transparent, Colors.black.withValues(alpha: full ? 0.45 : (level.isAntique ? 0.6 : 0.28))],
        stops: const [0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(_CrtPainter old) => old.level != level;
}

/// Granulado de filme: pontos claros e escuros espalhados de forma fixa
/// (semente constante), em três intensidades. Discreto o bastante para não
/// atrapalhar a leitura de texto pequeno.
class _GrainPainter extends CustomPainter {
  const _GrainPainter({this.warm = false});

  /// true = pontos cor de papel velho (efeito ANTIGO).
  final bool warm;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(20261017);
    final count = (size.width * size.height / 70).round().clamp(0, 12000);
    final tones = <(Color, double)>[
      (warm ? const Color(0x16E6C48A) : const Color(0x14FFFFFF), 1.3),
      (warm ? const Color(0x0EE6C48A) : const Color(0x0DFFFFFF), 1.8),
      (const Color(0x24000000), 1.5),
    ];
    final buckets = [for (final _ in tones) <Offset>[]];
    for (var i = 0; i < count; i++) {
      buckets[rnd.nextInt(tones.length)]
          .add(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height));
    }
    for (var t = 0; t < tones.length; t++) {
      final paint = Paint()
        ..color = tones[t].$1
        ..strokeWidth = tones[t].$2
        ..strokeCap = StrokeCap.square;
      canvas.drawPoints(PointMode.points, buckets[t], paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.warm != warm;
}

/// Fita de vídeo (FITA): faixas claras de rastreamento, riscos horizontais e o
/// ruído de cabeçote no pé da tela. Tudo parado (semente fixa).
class _TapePainter extends CustomPainter {
  const _TapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(19841984);
    // Faixas largas e suaves.
    for (final f in const [0.16, 0.52, 0.81]) {
      final y = size.height * f;
      final h = 14 + rnd.nextDouble() * 14;
      final rect = Rect.fromLTWH(0, y, size.width, h);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00FFFFFF), Color(0x0FFFFFFF), Color(0x00FFFFFF)],
          ).createShader(rect),
      );
    }
    // Riscos curtos.
    final streak = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    for (var i = 0; i < 34; i++) {
      final y = rnd.nextDouble() * size.height;
      final x = rnd.nextDouble() * size.width;
      final len = 30 + rnd.nextDouble() * 190;
      canvas.drawLine(Offset(x, y), Offset(math.min(x + len, size.width), y), streak);
    }
    // Ruído de cabeçote no rodapé.
    final foot = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = 1;
    final top = size.height * 0.955;
    for (var i = 0; i < 70; i++) {
      final y = top + rnd.nextDouble() * (size.height - top);
      final x = rnd.nextDouble() * size.width;
      final len = 10 + rnd.nextDouble() * 120;
      canvas.drawLine(Offset(x, y), Offset(math.min(x + len, size.width), y), foot);
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) => false;
}

/// Papel envelhecido (ANTIGO): véu cor de papiro, manchas, fibras e riscos.
class _AgedPainter extends CustomPainter {
  const _AgedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(1453);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0x0DC8A064));
    // Manchas de umidade.
    for (var i = 0; i < 6; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 70 + rnd.nextDouble() * 120;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x14B48250), Color(0x00B48250)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    // Fibras do papel.
    final fiber = Paint()
      ..color = const Color(0x18F0DCB4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 110; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final a = rnd.nextDouble() * math.pi * 2;
      final len = 8 + rnd.nextDouble() * 26;
      final end = Offset(x + math.cos(a) * len, y + math.sin(a) * len);
      final ctrl = Offset((x + end.dx) / 2 + rnd.nextDouble() * 8 - 4, (y + end.dy) / 2 + rnd.nextDouble() * 8 - 4);
      canvas.drawPath(Path()..moveTo(x, y)..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy), fiber);
    }
    // Riscos verticais de desgaste.
    final scratch = Paint()
      ..color = const Color(0x12FFFFFF)
      ..strokeWidth = 0.8;
    for (var i = 0; i < 3; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.5;
      canvas.drawLine(Offset(x, y), Offset(x + rnd.nextDouble() * 4 - 2, y + size.height * (0.2 + rnd.nextDouble() * 0.4)), scratch);
    }
  }

  @override
  bool shouldRepaint(_AgedPainter old) => false;
}

// ------------------------------------------------------------------- campos

InputDecoration termInput(BuildContext context, {String? hint}) {
  final p = AppScope.read(context).palette;
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.dim.withValues(alpha: 0.7)),
    counterText: '',
    isDense: true,
    contentPadding: const EdgeInsets.all(14),
    enabledBorder: border(p.dim),
    focusedBorder: border(p.fg),
    border: border(p.dim),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.pal.dim,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Tela vazia: globo, título e dica, centralizados e com quebra de linha
/// (a largura total evita que o texto fique encostado ou cortado na borda).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle, this.globe = 132});

  final String title;
  final String subtitle;
  final double globe;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            WireGlobe(size: globe),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.fg, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.dim, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
