import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../task_tile.dart';
import '../term_widgets.dart';
import 'dates_screen.dart';
import 'review_screen.dart';

/// Visão geral: o que importa agora, sem expor tudo de uma vez.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const int _limit = 7;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final n = s.now;
    final v = s.todayView();
    final reviewCount = s.reviewQueue.length;
    final soonDates = s.upcomingDates();

    final planned = s.doneToday() + v.agora.length + v.hoje.length;
    final done = s.doneToday();

    final sections = <(String, List<Task>)>[
      ('AGORA', v.agora),
      ('HOJE', v.hoje),
      ('EM BREVE', v.breve),
    ];
    var remaining = _expanded ? 1 << 30 : _limit;
    var hidden = 0;
    final rows = <Widget>[];
    for (final sec in sections) {
      if (sec.$2.isEmpty) continue;
      final shown = sec.$2.take(remaining).toList();
      hidden += sec.$2.length - shown.length;
      if (shown.isEmpty) continue;
      remaining -= shown.length;
      rows.add(SectionHeader(sec.$1, count: sec.$2.length));
      rows.addAll(shown.map((t) => TaskTile(key: ValueKey('tile-${t.id}'), task: t)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Text(
              '${weekdayShort(n.weekday)} ${two(n.day)}/${two(n.month)} · ${two(n.hour)}:${two(n.minute)}',
              style: TextStyle(color: p.dim, fontSize: 13, letterSpacing: 1),
            ),
            const Spacer(),
            if (planned > 0) ...[
              BlockBar(value: done / planned),
              const SizedBox(width: 6),
              Text('$done/$planned', style: TextStyle(color: p.dim, fontSize: 12)),
            ],
          ],
        ),
        if (reviewCount > 0) ...[
          const SizedBox(height: 12),
          TermButton(
            label: '$reviewCount ${reviewCount == 1 ? 'tarefa pede' : 'tarefas pedem'} uma decisão',
            icon: Icons.priority_high,
            expand: true,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
            ),
          ),
        ],
        if (soonDates.isNotEmpty) ...[
          SectionHeader('DATAS', count: soonDates.length),
          for (final d in soonDates) DateRow(key: ValueKey('today-date-${d.id}'), date: d),
        ],
        if (v.isEmpty)
          (soonDates.isEmpty ? _EmptyState(hasReview: reviewCount > 0) : const SizedBox.shrink())
        else
          ...rows,
        if (hidden > 0) ...[
          const SizedBox(height: 12),
          TermButton(
            label: 'Ver mais ($hidden)',
            expand: true,
            onPressed: () => setState(() => _expanded = true),
          ),
        ] else if (_expanded && v.total > _limit) ...[
          const SizedBox(height: 12),
          TermButton(
            label: 'Ver menos',
            expand: true,
            onPressed: () => setState(() => _expanded = false),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasReview});

  final bool hasReview;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: hasReview ? '> Nada para agora.' : '> Nada pendente agora.',
        subtitle: 'Toque em + para registrar algo.',
      );
}
