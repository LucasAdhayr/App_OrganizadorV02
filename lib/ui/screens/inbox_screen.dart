import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'task_form_screen.dart';

/// ENTRADA: notas rápidas, salvas sem escolher nada. Podem virar tarefa.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, this.ideasOnly = false});

  /// Usado pelo módulo IDEIAS: mostra só ideias e esconde o filtro.
  final bool ideasOnly;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _onlyIdeas = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final onlyIdeas = widget.ideasOnly || _onlyIdeas;
    final q = _query.trim().toLowerCase();
    final notes = s.notes
        .where((n) => (!onlyIdeas || n.isIdea) && (q.isEmpty || n.text.toLowerCase().contains(q)))
        .toList()
        .reversed
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        TermButton(
          label: 'Nova nota',
          icon: Icons.edit_note,
          expand: true,
          primary: true,
          onPressed: () => showQuickNote(context),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14),
          cursorColor: p.fg,
          decoration: termInput(context, hint: 'Buscar nas notas'),
        ),
        if (!widget.ideasOnly) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              TermButton(
                label: 'Todas',
                dense: true,
                selected: !_onlyIdeas,
                onPressed: () => setState(() => _onlyIdeas = false),
              ),
              const SizedBox(width: 8),
              TermButton(
                label: 'Ideias',
                dense: true,
                selected: _onlyIdeas,
                onPressed: () => setState(() => _onlyIdeas = true),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const TermDivider(),
        if (notes.isEmpty)
          EmptyState(
            title: q.isNotEmpty
                ? '> Nada encontrado.'
                : onlyIdeas
                    ? '> Nenhuma ideia guardada.'
                    : '> Nenhuma nota ainda.',
            subtitle: q.isNotEmpty
                ? 'Tente outra palavra.'
                : 'Escreva do jeito que veio à cabeça.',
            globe: 96,
          )
        else
          for (final n in notes)
            TermRow(
              key: ValueKey('note-${n.id}-${n.isIdea}-${n.converted}'),
              title: firstLine(n.text),
              subtitle: '${fmtDateShort(n.createdAt)}${n.converted ? ' · virou tarefa' : ''}',
              trailing: n.isIdea ? 'IDEIA' : null,
              onTap: () => _openNote(context, n),
            ),
      ],
    );
  }

  void _openNote(BuildContext host, Note n) {
    showTermSheet<void>(host, (c) => _NoteSheet(note: n, host: host));
  }
}

class _NoteSheet extends StatelessWidget {
  const _NoteSheet({required this.note, required this.host});

  final Note note;

  /// Contexto da tela ENTRADA (continua montado depois que a folha fecha).
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final n = note;

    return SheetFrame(
      title: n.isIdea ? 'Ideia' : 'Nota',
      children: [
        SelectableText(n.text, style: const TextStyle(fontSize: 15, height: 1.4)),
        gap(8),
        Text(fmtDateFull(n.createdAt), style: TextStyle(color: p.dim, fontSize: 12)),
        gap(16),
        TermButton(
          label: 'Virar tarefa',
          icon: Icons.add_task,
          expand: true,
          primary: true,
          onPressed: () async {
            final hostNav = Navigator.of(host);
            final state = AppScope.read(host);
            final title = firstLine(n.text, max: 120);
            Navigator.of(context).pop();
            final created = await hostNav.push<Task>(
              MaterialPageRoute<Task>(
                builder: (_) => TaskFormScreen(
                  initialTitle: title,
                  initialNotes: n.text.trim() == title ? null : n.text.trim(),
                ),
              ),
            );
            if (created != null) state.markConverted(n);
          },
        ),
        gap(),
        TermButton(
          label: 'Editar texto',
          icon: Icons.edit_outlined,
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            _editNote(host, n);
          },
        ),
        gap(),
        TermButton(
          label: n.isIdea ? 'Marcar como nota' : 'Marcar como ideia',
          expand: true,
          onPressed: () {
            s.toggleIdea(n);
            Navigator.of(context).pop();
          },
        ),
        gap(),
        TermButton(
          label: 'Apagar',
          expand: true,
          danger: true,
          onPressed: () {
            final messenger = ScaffoldMessenger.of(host);
            final index = s.removeNote(n);
            Navigator.of(context).pop();
            toast(messenger, s.palette, 'Nota apagada.',
                onUndo: () => s.insertNote(index, n));
          },
        ),
      ],
    );
  }
}

/// Edita o texto de uma nota numa folha.
Future<void> _editNote(BuildContext host, Note n) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final controller = TextEditingController(text: n.text);
  return showTermSheet<void>(host, (c) {
    void save() {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      final old = n.text;
      s.editNote(n, text);
      Navigator.of(c).pop();
      toast(m, s.palette, 'Nota atualizada.', onUndo: () => s.editNote(n, old));
    }

    return SheetFrame(
      title: 'Editar nota',
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15),
          cursorColor: s.palette.fg,
          decoration: termInput(c),
        ),
        gap(12),
        TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
      ],
    );
  });
}

/// Módulo IDEIAS: só as notas marcadas como ideia.
class IdeasScreen extends StatelessWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TermScaffold(title: 'Ideias', body: InboxScreen(ideasOnly: true));
}
