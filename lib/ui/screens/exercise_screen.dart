import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../../core/labels.dart';
import '../../core/dates.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';
import 'task_form_screen.dart';

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

/// Abre o formulário de uma nova rotina de exercício (repete e avisa 1 h antes).
Future<void> newExerciseRoutine(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TaskFormScreen(module: kModExercise)),
    );

/// "+" > EXERCÍCIO: rotina que se repete ou treino já feito.
Future<void> addExerciseChoice(BuildContext context) async {
  final choice = await showTermSheet<String>(
    context,
    (c) => SheetFrame(
      title: 'Exercício',
      children: [
        TermButton(
          label: 'Nova rotina (repete)',
          icon: Icons.repeat,
          expand: true,
          primary: true,
          onPressed: () => Navigator.of(c).pop('routine'),
        ),
        gap(),
        TermButton(
          label: 'Registrar treino feito',
          icon: Icons.check,
          expand: true,
          onPressed: () => Navigator.of(c).pop('log'),
        ),
        gap(),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'routine') {
    await newExerciseRoutine(context);
  } else {
    await showExerciseSheet(context);
  }
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

    final routines = s.tasks.where((t) => t.module == kModExercise && s.isActive(t)).toList()
      ..sort((a, b) {
        final da = a.dueDate ?? DateTime(9999);
        final db = b.dueDate ?? DateTime(9999);
        final byDay = da.compareTo(db);
        return byDay != 0 ? byDay : a.title.compareTo(b.title);
      });

    return TermScaffold(
      title: 'Exercícios',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Feito',
                icon: Icons.check,
                dense: true,
                expand: true,
                onPressed: () => showExerciseSheet(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TermButton(
                label: 'Nova rotina',
                icon: Icons.repeat,
                expand: true,
                primary: true,
                onPressed: () => newExerciseRoutine(context),
              ),
            ),
          ],
        ),
      ),
      body: (list.isEmpty && routines.isEmpty)
          ? const EmptyHint(
              '> Nenhum exercício ainda.',
              'Crie uma rotina que se repete ou registre um treino feito.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (routines.isNotEmpty) ...[
                  SectionHeader('ROTINAS', count: routines.length),
                  for (final t in routines)
                    TermRow(
                      key: ValueKey('routine-${t.id}-${t.due}-${t.snoozedUntil}'),
                      title: t.title,
                      subtitle: '${t.recurrence?.label ?? ''}'
                          '${t.dueTime == null ? '' : ' · ${fmtTime(t.dueTime!)}'}',
                      trailing: dueLabel(t, now).text,
                      trailingColor: dueLabel(t, now).overdue ? p.warn : null,
                      onTap: () => showTaskDetail(context, t),
                    ),
                  const SizedBox(height: 8),
                ],
                if (list.isNotEmpty)
                  Text(
                  'Esta semana: ${week.length} ${week.length == 1 ? 'treino' : 'treinos'}'
                  '${weekMinutes > 0 ? ' · $weekMinutes min' : ''}',
                  style: TextStyle(color: p.fg, fontSize: 14),
                ),
                const SizedBox(height: 4),
                if (list.isNotEmpty) const TermDivider(),
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
