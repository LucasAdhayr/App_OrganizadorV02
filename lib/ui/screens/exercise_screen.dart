import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

const List<String> _quick = ['Caminhada', 'Corrida', 'Musculação', 'Bicicleta', 'Alongamento'];

/// Registra um exercício (ou edita [edit]).
Future<void> showExerciseSheet(BuildContext host, {Entry? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final kind = TextEditingController(text: edit?.text('kind') ?? '');
  final minutes = TextEditingController(text: edit?.number('minutes')?.toString() ?? '');
  final notes = TextEditingController(text: edit?.text('notes') ?? '');
  var when = edit?.at ?? s.now;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        void save() {
          final k = kind.text.trim();
          if (k.isEmpty) return;
          final mins = int.tryParse(minutes.text.trim());
          final data = <String, Object?>{
            'kind': k,
            if (mins != null && mins > 0) 'minutes': mins,
            'notes': notes.text.trim(),
          };
          if (edit == null) {
            s.addEntry(kModExercise, at: when, data: data);
          } else {
            s.updateEntry(edit, at: when, data: data);
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Exercício registrado.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'Novo exercício' : 'Editar exercício',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quick)
                  TermButton(
                    label: q,
                    dense: true,
                    selected: kind.text.trim() == q,
                    onPressed: () => setSheet(() => kind.text = q),
                  ),
              ],
            ),
            gap(12),
            TextField(
              controller: kind,
              onChanged: (_) => setSheet(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Atividade'),
            ),
            gap(8),
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Minutos (opcional)'),
            ),
            gap(8),
            TextField(
              controller: notes,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Notas (opcional)'),
            ),
            gap(12),
            WhenButton(when: when, onChanged: (v) => setSheet(() => when = v)),
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

/// EXERCÍCIOS: treinos e esportes, com o resumo da semana (começa na segunda).
class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final list = s.entriesOf(kModExercise);

    final start = weekStart(now);
    final week = list.where((e) => !e.at.isBefore(start)).toList();
    final weekMinutes = week.fold<int>(0, (sum, e) => sum + (e.number('minutes') ?? 0));

    final groups = <String, List<Entry>>{};
    for (final e in list) {
      groups.putIfAbsent(dayLabel(e.at, now), () => <Entry>[]).add(e);
    }

    return TermScaffold(
      title: 'Exercícios',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Registrar exercício',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => showExerciseSheet(context),
        ),
      ),
      body: list.isEmpty
          ? const EmptyHint('> Nenhum exercício ainda.', 'Registre treinos e esportes.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Esta semana: ${week.length} ${week.length == 1 ? 'treino' : 'treinos'}'
                  '${weekMinutes > 0 ? ' · $weekMinutes min' : ''}',
                  style: TextStyle(color: p.fg, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const TermDivider(),
                for (final g in groups.entries) ...[
                  SectionHeader(g.key, count: g.value.length),
                  for (final e in g.value)
                    TermRow(
                      key: ValueKey('ex-${e.id}-${e.updatedAt.millisecondsSinceEpoch}'),
                      title: e.text('kind'),
                      subtitle: e.text('notes').isEmpty ? null : e.text('notes'),
                      trailing: e.number('minutes') == null
                          ? hm(e.at)
                          : '${e.number('minutes')} min · ${hm(e.at)}',
                      onTap: () => showEntryActions(
                        context,
                        e,
                        title: e.text('kind'),
                        top: [
                          Text(
                            '${dayLabel(e.at, now)} ${hm(e.at)}'
                            '${e.number('minutes') == null ? '' : ' · ${e.number('minutes')} min'}',
                            style: TextStyle(color: p.dim, fontSize: 13),
                          ),
                          if (e.text('notes').isNotEmpty) ...[
                            gap(6),
                            Text(e.text('notes'), style: const TextStyle(fontSize: 14)),
                          ],
                        ],
                        onEdit: () => showExerciseSheet(context, edit: e),
                        deletedMessage: 'Exercício apagado.',
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
