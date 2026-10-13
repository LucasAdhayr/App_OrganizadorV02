import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'task_form_screen.dart';

/// Módulo TAREFAS: tudo o que existe, separado por tipo.
class TasksModuleScreen extends StatefulWidget {
  const TasksModuleScreen({super.key});

  @override
  State<TasksModuleScreen> createState() => _TasksModuleScreenState();
}

class _TasksModuleScreenState extends State<TasksModuleScreen> {
  bool _showClosed = false;

  static int _byDue(Task a, Task b) {
    final da = a.due == null ? DateTime(9999) : dateOnly(a.due!);
    final db = b.due == null ? DateTime(9999) : dateOnly(b.due!);
    final byDay = da.compareTo(db);
    if (byDay != 0) return byDay;
    return a.title.compareTo(b.title);
  }

  String _doneAgo(AppState s, Task t) {
    final last = t.lastDoneAt;
    if (last == null) return 'feito';
    final days = daysBetween(dateOnly(last), dateOnly(s.now));
    if (days == 0) return 'feito hoje';
    return 'feito há $days dia${days == 1 ? '' : 's'}';
  }

  Widget _row(BuildContext context, AppState s, Task t) {
    final p = s.palette;
    final label = dueLabel(t, s.now);
    String? subtitle;
    String? trailing;
    Color? trailingColor;
    Widget marker;

    if (!s.isActive(t) && !(t.kind == TaskKind.reusable && t.status == TaskStatus.done)) {
      // Encerrada (concluída ou descartada).
      final done = t.status == TaskStatus.done;
      subtitle = done ? 'concluída' : 'descartada';
      marker = TermMarker(checked: done, onTap: () => reopenTask(context, t));
    } else if (t.kind == TaskKind.reusable) {
      final done = t.status == TaskStatus.done;
      subtitle = done ? _doneAgo(s, t) : 'pendente';
      marker = TermMarker(
        checked: done,
        onTap: () {
          if (done) {
            reopenTask(context, t);
          } else {
            completeTask(context, t);
          }
        },
      );
    } else {
      subtitle = t.recurrence?.label;
      trailing = label.text.isEmpty ? null : label.text;
      trailingColor = label.overdue ? p.warn : null;
      marker = TermMarker(
        overdue: label.overdue,
        onTap: () => completeTask(context, t),
      );
    }

    return TermRow(
      key: ValueKey('mod-${t.id}-${t.status.name}-${t.due}'),
      title: t.title,
      subtitle: subtitle,
      leading: marker,
      trailing: trailing,
      trailingColor: trailingColor,
      onTap: () => showTaskDetail(context, t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;

    List<Task> pick(bool Function(Task) test) => s.tasks.where(test).toList()..sort(_byDue);

    final recurring = pick((t) => t.kind == TaskKind.recurring && s.isActive(t));
    final single = pick((t) => t.kind == TaskKind.single && s.isActive(t));
    final reusable = pick((t) => t.kind == TaskKind.reusable && t.status != TaskStatus.discarded);
    final closed = pick((t) =>
        !s.isActive(t) && !(t.kind == TaskKind.reusable && t.status == TaskStatus.done));

    final sections = <(String, List<Task>)>[
      ('RECORRENTES', recurring),
      ('ÚNICAS', single),
      ('REUTILIZÁVEIS', reusable),
    ];

    return TermScaffold(
      title: 'Tarefas',
      action: IconButton(
        tooltip: 'Nova tarefa',
        icon: const Icon(Icons.add),
        onPressed: () => Navigator.of(context).push<Task>(
          MaterialPageRoute<Task>(builder: (_) => const TaskFormScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          for (final sec in sections)
            if (sec.$2.isNotEmpty) ...[
              SectionHeader(sec.$1, count: sec.$2.length),
              for (final t in sec.$2) _row(context, s, t),
            ],
          if (recurring.isEmpty && single.isEmpty && reusable.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                '> Nenhuma tarefa ativa. Toque em + para criar.',
                style: TextStyle(color: p.dim, fontSize: 14),
              ),
            ),
          if (closed.isNotEmpty) ...[
            const SizedBox(height: 20),
            TermButton(
              label: _showClosed
                  ? 'Ocultar encerradas'
                  : 'Mostrar encerradas (${closed.length})',
              expand: true,
              onPressed: () => setState(() => _showClosed = !_showClosed),
            ),
            if (_showClosed) ...[
              SectionHeader('ENCERRADAS', count: closed.length),
              for (final t in closed) _row(context, s, t),
            ],
          ],
        ],
      ),
    );
  }
}
