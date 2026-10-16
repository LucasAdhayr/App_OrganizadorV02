import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../actions.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

/// Registra um copo (usado pelo "+" e pela tela de água).
void logGlass(BuildContext context) {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  final e = s.addEntry(kModWater);
  final n = s.glassesOn(s.now);
  toast(m, s.palette, 'Copo registrado: $n/${s.waterGoal}.', onUndo: () => s.removeEntry(e));
}

/// ÁGUA: conta copos, não mililitros. Meta diária ajustável.
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final today = s.glassesOn(now);
    final goal = s.waterGoal;
    final reached = today >= goal;

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
                label: 'Tirar 1',
                dense: true,
                onPressed: today == 0
                    ? null
                    : () {
                        final m = ScaffoldMessenger.of(context);
                        final removed = s.removeLastGlass();
                        if (removed != null) {
                          toast(m, s.palette, 'Copo removido.',
                              onUndo: () => s.insertEntry(s.entries.length, removed));
                        }
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TermButton(
                label: '+1 copo',
                icon: Icons.water_drop_outlined,
                expand: true,
                primary: true,
                onPressed: () => logGlass(context),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '$today / $goal copos',
            style: TextStyle(color: p.fg, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          BlockBar(value: goal == 0 ? 0 : (today / goal).clamp(0, 1).toDouble(), cells: 16),
          const SizedBox(height: 8),
          Text(
            reached ? '[OK] Meta de hoje batida.' : 'Faltam ${goal - today} para a meta.',
            style: TextStyle(color: reached ? p.fg : p.dim, fontSize: 14),
          ),
          const FieldLabel('Meta diária'),
          Row(
            children: [
              TermButton(
                label: '-',
                dense: true,
                onPressed: goal <= 1 ? null : () => s.setWaterGoal(goal - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$goal copos', style: TextStyle(color: p.fg, fontSize: 15)),
              ),
              TermButton(
                label: '+',
                dense: true,
                onPressed: goal >= 30 ? null : () => s.setWaterGoal(goal + 1),
              ),
            ],
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
                    value: (s.glassesOn(d) / goal).clamp(0, 1).toDouble(),
                    cells: 10,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s.glassesOn(d)}${s.glassesOn(d) >= goal ? ' [OK]' : ''}',
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
