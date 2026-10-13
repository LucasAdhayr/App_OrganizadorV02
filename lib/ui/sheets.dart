import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../core/dates.dart';
import '../core/labels.dart';
import '../core/models.dart';
import '../modules/registry.dart';
import 'actions.dart';
import 'screens/task_form_screen.dart';
import 'term_widgets.dart';

// ------------------------------------------------------------ folhas e caixas

Future<T?> showTermSheet<T>(BuildContext context, WidgetBuilder builder) {
  final p = AppScope.read(context).palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: p.dim),
    ),
    builder: builder,
  );
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: p.fg,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const TermDivider(),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

Widget gap([double h = 8]) => SizedBox(height: h);

Future<bool> confirmTerm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool danger = false,
}) async {
  final p = AppScope.read(context).palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: p.dim),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: p.fg,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            gap(12),
            Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
            gap(16),
            Row(
              children: [
                Expanded(
                  child: TermButton(
                    label: 'Cancelar',
                    onPressed: () => Navigator.of(c).pop(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TermButton(
                    label: confirmLabel,
                    danger: danger,
                    primary: !danger,
                    onPressed: () => Navigator.of(c).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

// ------------------------------------------------------------------- adiar

Future<DateTime?> showSnoozeSheet(BuildContext context) {
  final n = AppScope.read(context).now;
  final options = <(String, DateTime)>[
    ('+10 min', n.add(const Duration(minutes: 10))),
    ('+1 hora', n.add(const Duration(hours: 1))),
    if (n.hour < 20) ('Hoje à noite (20:00)', DateTime(n.year, n.month, n.day, 20)),
    ('Amanhã (09:00)', DateTime(n.year, n.month, n.day + 1, 9)),
  ];
  return showTermSheet<DateTime>(
    context,
    (c) => SheetFrame(
      title: 'Adiar para quando?',
      children: [
        for (final o in options) ...[
          TermButton(
            label: o.$1,
            expand: true,
            onPressed: () => Navigator.of(c).pop(o.$2),
          ),
          gap(),
        ],
      ],
    ),
  );
}

// ------------------------------------------------------------------ botão "+"

Future<void> showAddSheet(BuildContext context) async {
  final choice = await showTermSheet<String>(context, (c) {
    void pick(String id) => Navigator.of(c).pop(id);
    final withForm = kModules.where((m) => m.addLabel != null && m.form != null);
    final soon = kModules.where((m) => m.addLabel != null && m.form == null);
    return SheetFrame(
      title: 'O que você quer registrar?',
      children: [
        for (final m in withForm) ...[
          TermButton(
            label: m.addLabel!,
            icon: m.icon,
            expand: true,
            primary: true,
            onPressed: () => pick(m.id),
          ),
          gap(),
        ],
        TermButton(
          label: 'Nota ou ideia',
          icon: Icons.edit_note,
          expand: true,
          onPressed: () => pick('nota'),
        ),
        gap(16),
        Text(
          'EM BREVE',
          style: TextStyle(color: c.pal.dim, fontSize: 12, letterSpacing: 1.5),
        ),
        gap(),
        for (final m in soon) ...[
          TermButton(label: m.addLabel!, icon: m.icon, expand: true),
          gap(),
        ],
      ],
    );
  });
  if (choice == null || !context.mounted) return;
  if (choice == 'nota') {
    await showQuickNote(context);
    return;
  }
  final module = kModules.firstWhere((m) => m.id == choice);
  if (module.form != null) {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: module.form!));
  }
}

Future<void> showQuickNote(BuildContext context) {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  return showTermSheet<void>(context, (c) {
    void save({required bool idea}) {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      s.addNote(text, idea: idea);
      Navigator.of(c).pop();
      toast(m, s.palette, idea ? 'Ideia guardada.' : 'Anotado.');
    }

    return SheetFrame(
      title: 'Nota rápida',
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: termInput(c, hint: 'Escreva do jeito que veio à cabeça'),
          style: const TextStyle(fontSize: 15),
          cursorColor: c.pal.fg,
        ),
        gap(12),
        Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Salvar nota',
                primary: true,
                onPressed: () => save(idea: false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TermButton(
                label: 'Salvar ideia',
                onPressed: () => save(idea: true),
              ),
            ),
          ],
        ),
      ],
    );
  });
}

// ----------------------------------------------------------------- detalhes

void showTaskDetail(BuildContext host, Task task) {
  showTermSheet<void>(host, (c) => _TaskDetail(task: task, host: host));
}

class _TaskDetail extends StatelessWidget {
  const _TaskDetail({required this.task, required this.host});

  final Task task;

  /// Contexto da linha que abriu a folha (ainda montado quando o usuário toca).
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final t = task;
    final label = dueLabel(t, s.now);
    final active = s.isActive(t);

    Widget info(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(k, style: TextStyle(color: p.dim, fontSize: 12, letterSpacing: 1)),
              ),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 14))),
            ],
          ),
        );

    void closeThen(void Function() action) {
      Navigator.of(context).pop();
      action();
    }

    final doneAgo = t.lastDoneAt == null
        ? null
        : daysBetween(dateOnly(t.lastDoneAt!), dateOnly(s.now));

    return SheetFrame(
      title: t.title,
      children: [
        info('TIPO', t.kind.label),
        if (t.recurrence != null) info('REPETE', t.recurrence!.label),
        if (t.due != null)
          info(
            t.kind == TaskKind.recurring ? 'PRÓXIMA' : 'PRAZO',
            '${fmtDateShort(t.due!)}${t.time == null ? '' : ' ${fmtTime(t.time!)}'}'
            '${label.overdue ? '  (atrasada)' : ''}',
          ),
        if (t.status == TaskStatus.snoozed && t.snoozedUntil != null)
          info('ADIADA ATÉ', fmtWhen(t.snoozedUntil!, s.now)),
        if (doneAgo != null)
          info('ÚLTIMA VEZ', doneAgo == 0 ? 'hoje' : 'há $doneAgo dia${doneAgo == 1 ? '' : 's'}'),
        info('CRIADA EM', fmtDateFull(t.createdAt)),
        if (t.notes.isNotEmpty) info('NOTAS', t.notes),
        gap(12),
        if (active) ...[
          TermButton(
            label: 'Concluir',
            icon: Icons.check,
            expand: true,
            primary: true,
            onPressed: () => closeThen(() => completeTask(host, t)),
          ),
          gap(),
          TermButton(
            label: 'Adiar',
            expand: true,
            onPressed: () => closeThen(() => snoozeTask(host, t)),
          ),
          if (t.kind == TaskKind.recurring) ...[
            gap(),
            TermButton(
              label: 'Pular só esta vez',
              expand: true,
              onPressed: () => closeThen(() => skipTask(host, t)),
            ),
          ],
          gap(),
          TermButton(
            label: 'Editar',
            expand: true,
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push<Task>(MaterialPageRoute<Task>(
                builder: (_) => TaskFormScreen(edit: t),
              ));
            },
          ),
          gap(),
          TermButton(
            label: 'Descartar',
            expand: true,
            danger: true,
            onPressed: () async {
              final nav = Navigator.of(context);
              final m = ScaffoldMessenger.of(host);
              final ok = await confirmTerm(
                context,
                title: 'Descartar tarefa',
                message: t.kind == TaskKind.recurring
                    ? '"${t.title}" deixa de se repetir. O histórico é mantido.'
                    : '"${t.title}" sai da lista. O histórico é mantido.',
                confirmLabel: 'Descartar',
                danger: true,
              );
              if (!ok) return;
              s.discard(t);
              nav.pop();
              toast(m, s.palette, 'Tarefa descartada.', onUndo: s.undo);
            },
          ),
        ] else
          TermButton(
            label: t.kind == TaskKind.reusable ? 'Preciso de novo' : 'Reabrir',
            expand: true,
            primary: true,
            onPressed: () => closeThen(() => reopenTask(host, t)),
          ),
      ],
    );
  }
}
