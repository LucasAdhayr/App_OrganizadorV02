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
/// permite abrir a tarefa, corrigir a data/hora ou apagar o registro.
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

  /// Toque em um registro: abrir a tarefa, corrigir quando aconteceu ou apagar
  /// o registro (a tarefa em si não muda).
  Future<void> _open(BuildContext context, AppState s, HistoryEvent e) async {
    final m = ScaffoldMessenger.of(context);
    final task = s.taskById(e.taskId);
    final choice = await showTermSheet<String>(
      context,
      (c) => SheetFrame(
        title: e.taskTitle,
        children: [
          Text(
            '${e.kind.label} · ${fmtWhen(e.at, s.now)}',
            style: TextStyle(color: s.palette.dim, fontSize: 13),
          ),
          gap(12),
          if (task != null) ...[
            TermButton(
              label: 'Abrir tarefa',
              expand: true,
              onPressed: () => Navigator.of(c).pop('open'),
            ),
            gap(),
          ],
          TermButton(
            label: 'Mudar data e hora',
            icon: Icons.event,
            expand: true,
            onPressed: () => Navigator.of(c).pop('time'),
          ),
          gap(),
          TermButton(
            label: 'Apagar registro',
            expand: true,
            danger: true,
            onPressed: () => Navigator.of(c).pop('delete'),
          ),
          gap(),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'open':
        if (task != null) showTaskDetail(context, task);
      case 'time':
        final date = await showDatePicker(
          context: context,
          initialDate: e.at,
          firstDate: DateTime(2020),
          lastDate: dateOnly(s.now),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: e.at.hour, minute: e.at.minute),
        );
        if (time == null) return;
        final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (at.isAfter(s.now)) {
          toast(m, s.palette, 'Esse horário ainda não chegou.');
          return;
        }
        final old = e.at;
        s.changeHistoryTime(e, at);
        toast(m, s.palette, 'Registro atualizado.',
            onUndo: () => s.changeHistoryTime(e, old));
      case 'delete':
        final ok = await confirmTerm(
          context,
          title: 'Apagar registro',
          message: 'Só o registro some do histórico. A tarefa continua como está.',
          confirmLabel: 'Apagar',
          danger: true,
        );
        if (!ok) return;
        final index = s.removeHistoryEvent(e);
        toast(m, s.palette, 'Registro apagado.',
            onUndo: () => s.insertHistoryEvent(index, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
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
            const EmptyState(
              title: '> Nenhum registro neste filtro.',
              subtitle: 'O que você concluir, adiar ou descartar aparece aqui.',
              globe: 96,
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
