import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';

enum _Period { today, week, all }

extension on _Period {
  String get label => switch (this) {
        _Period.today => 'HOJE',
        _Period.week => '7 DIAS',
        _Period.all => 'TUDO',
      };
}

/// Histórico com filtros por período e tipo de ação. Tocar em um registro
/// abre a tarefa, onde dá para reabrir ou editar (corrigir um engano).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Period _period = _Period.week;
  HistoryKind? _kind;

  bool _inPeriod(HistoryEvent e, DateTime now) {
    switch (_period) {
      case _Period.today:
        return sameDay(e.at, now);
      case _Period.week:
        return daysBetween(dateOnly(e.at), dateOnly(now)) < 7;
      case _Period.all:
        return true;
    }
  }

  String _dayLabel(DateTime at, DateTime now) {
    final diff = daysBetween(dateOnly(at), dateOnly(now));
    if (diff == 0) return 'HOJE';
    if (diff == 1) return 'ONTEM';
    return fmtDateShort(at);
  }

  void _open(BuildContext context, AppState s, HistoryEvent e) {
    final task = s.taskById(e.taskId);
    if (task == null) {
      showToast(context, 'Essa tarefa não existe mais.');
      return;
    }
    showTaskDetail(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;

    final events = s.history
        .where((e) => _inPeriod(e, now) && (_kind == null || e.kind == _kind))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));

    final groups = <String, List<HistoryEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(_dayLabel(e.at, now), () => <HistoryEvent>[]).add(e);
    }

    return TermScaffold(
      title: 'Histórico',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const FieldLabel('Período'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in _Period.values)
                TermButton(
                  label: period.label,
                  dense: true,
                  selected: _period == period,
                  onPressed: () => setState(() => _period = period),
                ),
            ],
          ),
          const FieldLabel('Ação'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TermButton(
                label: 'Todas',
                dense: true,
                selected: _kind == null,
                onPressed: () => setState(() => _kind = null),
              ),
              for (final k in HistoryKind.values)
                TermButton(
                  label: k.label,
                  dense: true,
                  selected: _kind == k,
                  onPressed: () => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Text(
                '> Nenhum registro neste filtro.',
                style: TextStyle(color: p.dim, fontSize: 14),
              ),
            )
          else
            for (final entry in groups.entries) ...[
              SectionHeader(entry.key, count: entry.value.length),
              for (final e in entry.value)
                TermRow(
                  key: ValueKey('hist-${e.id}'),
                  title: e.taskTitle,
                  subtitle: e.detail.isEmpty ? e.kind.label : '${e.kind.label} · ${e.detail}',
                  trailing: '${two(e.at.hour)}:${two(e.at.minute)}',
                  onTap: () => _open(context, s, e),
                ),
            ],
        ],
      ),
    );
  }
}
