import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../actions.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

/// Registra 200 ml (usado pelo "+" e pela tela de água).
void logWater(BuildContext context) {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  final e = s.addWater();
  toast(
    m,
    s.palette,
    '+${AppState.waterStepMl} ml: ${fmtLiters(s.waterMlOn(s.now))} de ${fmtLiters(s.waterGoalMl)}.',
    onUndo: () => s.removeEntry(e),
  );
}

/// ÁGUA: registra de 200 em 200 ml, meta diária em litros, avisos às 6h, 12h,
/// 18h e 21h (só quando a meta parcial ainda não foi atingida).
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final goal = s.waterGoalMl;
    final today = s.waterMlOn(now);
    final reached = today >= goal;
    final percent = (today * 100 / goal).round();

    final days = [
      for (var i = 0; i < 7; i++) DateTime(now.year, now.month, now.day - i),
    ];

    return TermScaffold(
      title: 'Água',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Tirar',
                dense: true,
                expand: true,
                onPressed: today == 0
                    ? null
                    : () {
                        final m = ScaffoldMessenger.of(context);
                        final removed = s.removeLastWater();
                        if (removed != null) {
                          toast(m, s.palette, 'Registro removido.',
                              onUndo: () => s.insertEntry(s.entries.length, removed));
                        }
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TermButton(
                label: '+${AppState.waterStepMl} ml',
                icon: Icons.water_drop_outlined,
                expand: true,
                primary: true,
                onPressed: () => logWater(context),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '${fmtLiters(today)} / ${fmtLiters(goal)}',
            style: TextStyle(color: p.fg, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          BlockBar(value: (today / goal).clamp(0, 1).toDouble(), cells: 16),
          const SizedBox(height: 8),
          Text(
            reached
                ? '[OK] Meta de hoje batida ($percent%).'
                : '$percent% da meta. Faltam ${fmtLiters(goal - today)}.',
            style: TextStyle(color: reached ? p.fg : p.dim, fontSize: 14),
          ),
          const FieldLabel('Meta diária'),
          Row(
            children: [
              TermButton(
                label: '-',
                dense: true,
                onPressed: goal <= 500 ? null : () => s.setWaterGoalMl(goal - 250),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(fmtLiters(goal), style: TextStyle(color: p.fg, fontSize: 15)),
              ),
              TermButton(
                label: '+',
                dense: true,
                onPressed: goal >= 6000 ? null : () => s.setWaterGoalMl(goal + 250),
              ),
            ],
          ),
          const FieldLabel('Avisos'),
          TermButton(
            label: s.waterReminders ? 'Avisos: LIGADOS' : 'Avisos: DESLIGADOS',
            expand: true,
            selected: s.waterReminders,
            onPressed: () => s.setWaterReminders(!s.waterReminders),
          ),
          const SizedBox(height: 6),
          Text(
            '06:00 primeiro gole · 12:00 se estiver abaixo de 30% · '
            '18:00 se abaixo de 70% · 21:00 se ainda não completou. '
            'Quando você registra água, o aviso que já não faz sentido some.',
            style: TextStyle(color: p.dim, fontSize: 12, height: 1.4),
          ),
          const FieldLabel('Últimos 7 dias'),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(dayLabel(d, now), style: TextStyle(color: p.dim, fontSize: 13)),
                  ),
                  BlockBar(
                    value: (s.waterMlOn(d) / goal).clamp(0, 1).toDouble(),
                    cells: 10,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmtLiters(s.waterMlOn(d))}${s.waterMlOn(d) >= goal ? ' [OK]' : ''}',
                    style: TextStyle(color: p.fg, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
