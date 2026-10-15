import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../term_widgets.dart';
import 'task_form_screen.dart';

/// Revisão de tarefas antigas: no máximo 3 por vez, sem culpa e sem apagar
/// nada sozinho.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  static const int _perPage = 3;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final queue = s.reviewQueue;
    final shown = queue.take(_perPage).toList();
    final rest = queue.length - shown.length;

    return TermScaffold(
      title: 'Revisão',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (shown.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(child: WireGlobe(size: 120)),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '> Nada para decidir agora.',
                style: TextStyle(color: p.fg, fontSize: 15),
              ),
            ),
          ] else ...[
            Text(
              '> Estas tarefas ficaram um tempo sem atualização. '
              'Nada foi apagado: você decide o que fazer com cada uma.',
              style: TextStyle(color: p.dim, fontSize: 13, height: 1.4),
            ),
            for (final t in shown) _ReviewCard(key: ValueKey('rev-${t.id}'), task: t),
            if (rest > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Mais $rest ${rest == 1 ? 'tarefa' : 'tarefas'} depois destas.',
                  style: TextStyle(color: p.dim, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({super.key, required this.task});

  final Task task;

  String _age(AppState s) {
    final due = task.dueDate;
    if (task.kind == TaskKind.recurring && due != null) {
      return 'Atrasada há ${daysBetween(due, s.now)} dias';
    }
    return 'Sem atualização há ${s.now.difference(task.updatedAt).inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final t = task;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: p.dim)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_age(s), style: TextStyle(color: p.dim, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          const Text('Essa tarefa ainda está nos seus planos?', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          TermButton(
            label: 'Sim, continua pendente',
            expand: true,
            primary: true,
            onPressed: () => keepTask(context, t),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TermButton(
                  label: 'Adiar',
                  dense: true,
                  onPressed: () => snoozeTask(context, t),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TermButton(
                  label: 'Reorganizar',
                  dense: true,
                  onPressed: () => Navigator.of(context).push<Task>(
                    MaterialPageRoute<Task>(builder: (_) => TaskFormScreen(edit: t)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TermButton(
            label: 'Não vou mais fazer',
            expand: true,
            danger: true,
            dense: true,
            onPressed: () => discardTask(context, t),
          ),
        ],
      ),
    );
  }
}
