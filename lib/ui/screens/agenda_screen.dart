import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../task_tile.dart';
import '../term_widgets.dart';

/// Tudo o que tem data, agrupado por dia. Recorrentes aparecem na próxima
/// ocorrência.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  static int _compare(Task a, Task b) {
    final byDay = dateOnly(a.dueDate!).compareTo(dateOnly(b.dueDate!));
    if (byDay != 0) return byDay;
    final ta = a.dueTime, tb = b.dueTime;
    final ma = ta == null ? 1440 : ta.hour * 60 + ta.minute;
    final mb = tb == null ? 1440 : tb.hour * 60 + tb.minute;
    final byTime = ma.compareTo(mb);
    if (byTime != 0) return byTime;
    return a.title.compareTo(b.title);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final today = dateOnly(s.now);

    final items = s.tasks.where((t) => s.isActive(t) && t.dueDate != null).toList()
      ..sort(_compare);

    final groups = <String, List<Task>>{};
    for (final t in items) {
      final d = dateOnly(t.dueDate!);
      final diff = daysBetween(today, d);
      final key = diff < 0
          ? 'ATRASADAS'
          : diff == 0
              ? 'HOJE'
              : diff == 1
                  ? 'AMANHÃ'
                  : fmtDateShort(d);
      groups.putIfAbsent(key, () => <Task>[]).add(t);
    }

    if (groups.isEmpty) {
      return const EmptyState(
        title: '> Nada com data marcada.',
        subtitle: 'Tarefas com prazo ou repetição aparecem aqui.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        for (final entry in groups.entries) ...[
          SectionHeader(entry.key, count: entry.value.length),
          for (final t in entry.value) TaskTile(key: ValueKey('agenda-${t.id}'), task: t),
        ],
      ],
    );
  }
}
