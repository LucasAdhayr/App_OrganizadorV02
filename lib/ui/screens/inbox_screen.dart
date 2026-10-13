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
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _onlyIdeas = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final notes = s.notes.where((n) => !_onlyIdeas || n.isIdea).toList().reversed.toList();

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
        const SizedBox(height: 8),
        const TermDivider(),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              _onlyIdeas ? '> Nenhuma ideia guardada.' : '> Nenhuma nota ainda.',
              style: TextStyle(color: p.dim, fontSize: 14),
            ),
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
