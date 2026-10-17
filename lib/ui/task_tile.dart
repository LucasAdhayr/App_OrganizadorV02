import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/entry.dart';
import '../core/labels.dart';
import '../core/models.dart';
import 'actions.dart';
import 'sheets.dart';
import 'term_widgets.dart';

/// Linha de tarefa: título e prazo. Gestos:
/// toque em [ ] ou deslizar à direita = concluir; deslizar à esquerda = adiar
/// (+10 min, +1 hora ou escolher data e hora);
/// toque no texto = detalhes (onde ficam editar e descartar).
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final t = task;
    final label = dueLabel(t, s.now);

    final tags = [
      if (t.module == kModExercise) 'EXERCÍCIO',
      if (t.alarm) 'ALARME',
    ].join(' · ');

    final row = TermRow(
      title: t.title,
      subtitle: tags.isEmpty ? null : tags,
      leading: TermMarker(
        overdue: label.overdue,
        onTap: () => completeTask(context, t),
      ),
      trailing: label.text.isEmpty ? null : label.text,
      trailingColor: label.overdue ? p.warn : null,
      onTap: () => showTaskDetail(context, t),
    );

    return Dismissible(
      // A chave inclui o estado: quando a tarefa muda (ex.: próxima ocorrência),
      // a linha antiga sai e uma nova entra.
      key: ValueKey('${t.id}|${t.status.name}|${t.due}|${t.snoozedUntil}'),
      background: _SwipeBackground(
        label: 'CONCLUIR',
        icon: Icons.check,
        alignment: Alignment.centerLeft,
        color: p.fg,
        textColor: p.bg,
      ),
      secondaryBackground: _SwipeBackground(
        label: 'ADIAR',
        icon: Icons.schedule,
        alignment: Alignment.centerRight,
        color: p.dim,
        textColor: p.bg,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Recorrente ainda não vencida: o cartão volta e aparece um aviso.
          return ensureCanComplete(context, t);
        }
        // Adiar nunca tira a linha da tela por gesto: a ação roda aqui e o
        // cartão volta; a lista se reorganiza sozinha. (Antes, a linha era
        // "dispensada" mas continuava na árvore e o Flutter acusava erro.)
        await snoozeTask(context, t);
        return false;
      },
      onDismissed: (direction) => completeTask(context, t),
      child: row,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.label,
    required this.icon,
    required this.alignment,
    required this.color,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              shadows: const <Shadow>[],
            ),
          ),
        ],
      ),
    );
  }
}
