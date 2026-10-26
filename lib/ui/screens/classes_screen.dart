import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/course.dart';
import '../../core/dates.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

String _leadLabel(int lead) => switch (lead) {
      -1 => 'Sem aviso',
      0 => 'Na hora',
      60 => '1 h antes',
      _ => '$lead min antes',
    };

String _firstNote(Task t) => firstLine(t.notes, 60);

// ------------------------------------------------------------ disciplina (form)

/// Cadastra uma disciplina (ou edita [edit]).
Future<void> showCourseSheet(BuildContext host, {Course? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final name = TextEditingController(text: edit?.name ?? '');
  final maxAbs = TextEditingController(
    text: edit == null || edit.maxAbsences == 0 ? '' : '${edit.maxAbsences}',
  );
  final pass = TextEditingController(text: fmtGrade(edit?.pass ?? kDefaultPass));
  final slots = <ClassSlot>[...?edit?.slots];
  var weekday = 2;
  var lead = edit?.lead ?? 30;
  var alarm = edit?.alarm ?? false;
  String? error;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        Future<void> addSlot() async {
          final picked = await showTimePicker(
            context: c,
            initialTime: const TimeOfDay(hour: 7, minute: 0),
          );
          if (picked == null) return;
          setSheet(() {
            final all = sortedSlots([...slots, ClassSlot(weekday, picked)]);
            slots
              ..clear()
              ..addAll(all);
            error = null;
          });
        }

        void save() {
          final n = name.text.trim();
          if (n.isEmpty) return setSheet(() => error = 'Dê um nome à disciplina.');
          final limit = int.tryParse(maxAbs.text.trim()) ?? 0;
          final passText = pass.text.trim();
          final passGrade = passText.isEmpty ? kDefaultPass : parseGrade(passText);
          if (passGrade == null) {
            return setSheet(() => error = 'Média para passar inválida. Exemplo: 6,0');
          }
          if (edit == null) {
            s.addCourse(
              name: n,
              slots: slots,
              lead: lead,
              alarm: alarm,
              maxAbsences: limit,
              pass: passGrade,
            );
          } else {
            s.editCourse(
              edit,
              name: n,
              slots: slots,
              lead: lead,
              alarm: alarm,
              maxAbsences: limit,
              pass: passGrade,
            );
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Disciplina adicionada.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'Nova disciplina' : 'Editar disciplina',
          children: [
            TextField(
              controller: name,
              autofocus: edit == null,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Ex.: Máquinas de Fluxo'),
            ),
            const FieldLabel('Horários (repetem toda semana)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sl in slots)
                  TermButton(
                    label: '${weekdayShort(sl.weekday)} ${fmtTime(sl.time)}',
                    icon: Icons.close,
                    dense: true,
                    selected: true,
                    onPressed: () => setSheet(() => slots.remove(sl)),
                  ),
              ],
            ),
            gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  TermButton(
                    label: weekdayShort(d),
                    dense: true,
                    selected: weekday == d,
                    onPressed: () => setSheet(() => weekday = d),
                  ),
              ],
            ),
            gap(8),
            TermButton(
              label: 'Adicionar horário de ${weekdayShort(weekday)}',
              icon: Icons.add,
              expand: true,
              onPressed: addSlot,
            ),
            const FieldLabel('Aviso'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in kClassLeads)
                  TermButton(
                    label: _leadLabel(l),
                    dense: true,
                    selected: lead == l,
                    onPressed: () => setSheet(() => lead = l),
                  ),
              ],
            ),
            if (lead >= 0) ...[
              gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TermButton(
                    label: 'Notificação',
                    dense: true,
                    selected: !alarm,
                    onPressed: () => setSheet(() => alarm = false),
                  ),
                  TermButton(
                    label: 'Tocar alarme',
                    icon: Icons.alarm,
                    dense: true,
                    selected: alarm,
                    onPressed: () => setSheet(() => alarm = true),
                  ),
                ],
              ),
            ],
            const FieldLabel('Máximo de faltas (0 = não controlar)'),
            TextField(
              controller: maxAbs,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Ex.: 12'),
            ),
            const FieldLabel('Média para passar'),
            TextField(
              controller: pass,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Ex.: 6,0'),
            ),
            if (error != null) ...[
              gap(8),
              Text('! $error', style: TextStyle(color: s.palette.warn, fontSize: 13)),
            ],
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

// --------------------------------------------------------- prova ou trabalho

/// Cadastra uma prova ou um trabalho da disciplina [course].
Future<void> showAssignmentSheet(BuildContext host, Course course) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final desc = TextEditingController();
  var type = 'Prova';
  DateTime? due;
  TimeOfDay? time;
  var alarm = false;
  String? error;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        Future<void> pickDate() async {
          final today = dateOnly(s.now);
          final picked = await showDatePicker(
            context: c,
            initialDate: due ?? today.add(const Duration(days: 7)),
            firstDate: today,
            lastDate: DateTime(today.year + 2, 12, 31),
          );
          if (picked != null) setSheet(() => due = dateOnly(picked));
        }

        Future<void> pickTime() async {
          final picked = await showTimePicker(
            context: c,
            initialTime: time ?? const TimeOfDay(hour: 8, minute: 0),
          );
          if (picked != null) setSheet(() => time = picked);
        }

        void save() {
          final d = due;
          if (d == null) return setSheet(() => error = 'Escolha a data.');
          s.addAssignment(
            course,
            type: type,
            description: desc.text.trim(),
            due: d,
            time: time,
            alarm: alarm,
          );
          Navigator.of(c).pop();
          toast(m, s.palette, '$type adicionada.');
        }

        return SheetFrame(
          title: 'Prova ou trabalho · ${course.name}',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const ['Prova', 'Trabalho'])
                  TermButton(
                    label: t,
                    dense: true,
                    selected: type == t,
                    onPressed: () => setSheet(() => type = t),
                  ),
              ],
            ),
            gap(12),
            TextField(
              controller: desc,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Descrição (ex.: capítulos 1 a 3)'),
            ),
            gap(12),
            TermButton(
              label: due == null ? 'Escolher data' : fmtDateShort(due!),
              icon: Icons.event,
              expand: true,
              selected: due != null,
              onPressed: pickDate,
            ),
            gap(),
            TermButton(
              label: time == null ? 'Horário (opcional)' : fmtTime(time!),
              icon: Icons.schedule,
              expand: true,
              selected: time != null,
              onPressed: pickTime,
            ),
            gap(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TermButton(
                  label: 'Notificação',
                  dense: true,
                  selected: !alarm,
                  onPressed: () => setSheet(() => alarm = false),
                ),
                TermButton(
                  label: 'Tocar alarme',
                  icon: Icons.alarm,
                  dense: true,
                  selected: alarm,
                  onPressed: () => setSheet(() => alarm = true),
                ),
              ],
            ),
            gap(4),
            Text(
              time == null
                  ? 'Sem horário: avisa na véspera e no dia, às 09:00.'
                  : 'Avisa no horário marcado.',
              style: TextStyle(color: s.palette.dim, fontSize: 12),
            ),
            if (error != null) ...[
              gap(8),
              Text('! $error', style: TextStyle(color: s.palette.warn, fontSize: 13)),
            ],
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

// --------------------------------------------------------------------- nota

Future<void> showGradeSheet(BuildContext host, Course course, String key) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final label = key.toUpperCase();
  final current = key == 'p1' ? course.p1 : course.p2;
  final field = TextEditingController(text: current == null ? '' : fmtGrade(current));
  String? error;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        void save() {
          final v = parseGrade(field.text);
          if (v == null) {
            setSheet(() => error = 'Nota de 0 a 10. Exemplo: 7,5');
            return;
          }
          s.setGrade(course, key, v);
          Navigator.of(c).pop();
          toast(m, s.palette, '$label: ${fmtGrade(v)}.');
        }

        return SheetFrame(
          title: 'Nota da $label · ${course.name}',
          children: [
            TextField(
              controller: field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: const TextStyle(fontSize: 18),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Nota (0 a 10)'),
            ),
            if (error != null) ...[
              gap(8),
              Text('! $error', style: TextStyle(color: s.palette.warn, fontSize: 13)),
            ],
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
            if (current != null) ...[
              gap(),
              TermButton(
                label: 'Apagar nota',
                expand: true,
                danger: true,
                onPressed: () {
                  s.setGrade(course, key, null);
                  Navigator.of(c).pop();
                  toast(m, s.palette, 'Nota apagada.');
                },
              ),
            ],
          ],
        );
      },
    );
  });
}

// --------------------------------------------------------- tela da disciplina

void openCourse(BuildContext context, Course c) => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CourseScreen(courseId: c.id)),
    );

/// Uma disciplina: horários, notas, faltas, provas e trabalhos.
class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final course = s.courseById(courseId);
    if (course == null) {
      return const TermScaffold(
        title: 'Disciplina',
        body: EmptyHint('> Disciplina não encontrada.', 'Ela foi apagada.'),
      );
    }

    final open = s.assignmentsOf(course.id);
    final closed = s
        .assignmentsOf(course.id, includeClosed: true)
        .where((t) => t.status == TaskStatus.done)
        .toList()
        .reversed
        .take(5)
        .toList();

    String needText() {
      final need = course.neededOnP2;
      if (need == null) return '';
      if (need == 0) return 'Com a P1, a média de ${fmtGrade(course.pass)} já está garantida.';
      if (need > 1000) {
        return '[!] Mesmo com 10 na P2 a média não chega a ${fmtGrade(course.pass)}.';
      }
      return 'Precisa de ${fmtGrade(need)} na P2 para média ${fmtGrade(course.pass)}.';
    }

    final need = needText();

    return TermScaffold(
      title: course.name,
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Editar',
                icon: Icons.edit_outlined,
                dense: true,
                expand: true,
                onPressed: () => showCourseSheet(context, edit: course),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TermButton(
                label: 'Prova ou trabalho',
                icon: Icons.add,
                expand: true,
                primary: true,
                onPressed: () => showAssignmentSheet(context, course),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(course.scheduleText, style: TextStyle(color: p.fg, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            course.lead < 0
                ? 'Sem aviso de aula.'
                : 'Aviso: ${_leadLabel(course.lead).toLowerCase()}'
                    '${course.alarm ? ' · toca alarme' : ''}.',
            style: TextStyle(color: p.dim, fontSize: 12),
          ),
          const FieldLabel('Notas'),
          Row(
            children: [
              Expanded(
                child: TermButton(
                  label: 'P1: ${course.p1 == null ? '--' : fmtGrade(course.p1!)}',
                  expand: true,
                  selected: course.p1 != null,
                  onPressed: () => showGradeSheet(context, course, 'p1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TermButton(
                  label: 'P2: ${course.p2 == null ? '--' : fmtGrade(course.p2!)}',
                  expand: true,
                  selected: course.p2 != null,
                  onPressed: () => showGradeSheet(context, course, 'p2'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            course.average == null
                ? 'Média: lança as duas notas para calcular.'
                : 'Média: ${fmtGrade(course.average!)} '
                    '(${course.average! >= course.pass ? '[OK] passou' : '[!] abaixo de ${fmtGrade(course.pass)}'})',
            style: TextStyle(color: p.fg, fontSize: 14),
          ),
          if (need.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(need, style: TextStyle(color: p.dim, fontSize: 13)),
          ],
          const FieldLabel('Faltas'),
          Text(
            '${course.absencesWarn ? '[!] ' : ''}${course.absencesText}',
            style: TextStyle(
              color: course.absencesWarn ? p.warn : p.fg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (course.tracksAbsences) ...[
            const SizedBox(height: 8),
            BlockBar(
              value: (course.absences / course.maxAbsences).clamp(0, 1).toDouble(),
              cells: 16,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TermButton(
                  label: '−1',
                  expand: true,
                  onPressed: course.absences == 0 ? null : () => s.addAbsence(course, -1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TermButton(
                  label: '+1 falta',
                  icon: Icons.event_busy_outlined,
                  expand: true,
                  onPressed: () {
                    final m = ScaffoldMessenger.of(context);
                    s.addAbsence(course, 1);
                    toast(m, s.palette, 'Falta registrada.', onUndo: () => s.addAbsence(course, -1));
                  },
                ),
              ),
            ],
          ),
          if (!course.tracksAbsences) ...[
            const SizedBox(height: 6),
            Text('Defina o máximo de faltas em Editar para ver quantas restam.',
                style: TextStyle(color: p.dim, fontSize: 12)),
          ],
          SectionHeader('PROVAS E TRABALHOS', count: open.length),
          if (open.isEmpty)
            Text('> Nada marcado.', style: TextStyle(color: p.dim, fontSize: 13))
          else
            for (final t in open)
              TermRow(
                key: ValueKey('asg-${t.id}-${t.due}-${t.snoozedUntil}-${t.updatedAt.millisecondsSinceEpoch}'),
                title: t.title,
                subtitle: _firstNote(t).isEmpty ? null : _firstNote(t),
                trailing: dueLabel(t, now).text,
                trailingColor: dueLabel(t, now).overdue ? p.warn : null,
                onTap: () => showTaskDetail(context, t),
              ),
          if (closed.isNotEmpty) ...[
            const SectionHeader('JÁ FEITOS'),
            for (final t in closed)
              TermRow(
                key: ValueKey('asg-done-${t.id}'),
                title: t.title,
                subtitle: _firstNote(t).isEmpty ? null : _firstNote(t),
                trailing: 'FEITO',
                onTap: () => showTaskDetail(context, t),
              ),
          ],
          const SizedBox(height: 24),
          TermButton(
            label: 'Apagar disciplina',
            expand: true,
            danger: true,
            onPressed: () async {
              final nav = Navigator.of(context);
              final m = ScaffoldMessenger.of(context);
              final ok = await confirmTerm(
                context,
                title: 'Apagar disciplina',
                message: '"${course.name}" sai da lista, com notas e faltas. '
                    'As provas e trabalhos pendentes são descartados.',
                confirmLabel: 'Apagar',
                danger: true,
              );
              if (!ok) return;
              s.deleteCourse(course);
              nav.pop();
              toast(m, s.palette, 'Disciplina apagada.');
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ tela do módulo

/// "+" > AULAS: nova disciplina, ou prova/trabalho de uma disciplina.
Future<void> addClassChoice(BuildContext context) async {
  final s = AppScope.read(context);
  final choice = await showTermSheet<String>(
    context,
    (c) => SheetFrame(
      title: 'Aulas',
      children: [
        TermButton(
          label: 'Nova disciplina',
          icon: Icons.school_outlined,
          expand: true,
          primary: true,
          onPressed: () => Navigator.of(c).pop('course'),
        ),
        gap(),
        TermButton(
          label: 'Prova ou trabalho',
          icon: Icons.assignment_outlined,
          expand: true,
          onPressed: () => Navigator.of(c).pop('assignment'),
        ),
        gap(),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'course') {
    await showCourseSheet(context);
    return;
  }
  final list = s.courses;
  if (list.isEmpty) {
    showToast(context, 'Cadastre uma disciplina primeiro.');
    return;
  }
  final picked = await showTermSheet<Course>(
    context,
    (c) => SheetFrame(
      title: 'De qual disciplina?',
      children: [
        for (final course in list) ...[
          TermButton(
            label: course.name,
            expand: true,
            onPressed: () => Navigator.of(c).pop(course),
          ),
          gap(),
        ],
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  await showAssignmentSheet(context, picked);
}

/// AULAS: todas as disciplinas, as aulas de hoje e as próximas provas.
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final courses = s.courses;
    final today = s.classesOn(now);
    final upcoming = s.allAssignments.take(5).toList();

    return TermScaffold(
      title: 'Aulas',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Nova disciplina',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => showCourseSheet(context),
        ),
      ),
      body: courses.isEmpty
          ? const EmptyHint(
              '> Nenhuma disciplina ainda.',
              'Cadastre horários, notas, faltas, provas e trabalhos.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (today.isNotEmpty) ...[
                  SectionHeader('HOJE', count: today.length),
                  for (final o in today)
                    TermRow(
                      key: ValueKey('today-${o.course.id}-${o.time.hour}:${o.time.minute}'),
                      title: o.course.name,
                      trailing: fmtTime(o.time),
                      onTap: () => openCourse(context, o.course),
                    ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SectionHeader('PRÓXIMAS PROVAS E TRABALHOS'),
                  for (final t in upcoming)
                    TermRow(
                      key: ValueKey('up-${t.id}-${t.due}'),
                      title: t.title,
                      subtitle: _firstNote(t).isEmpty ? null : _firstNote(t),
                      trailing: dueLabel(t, now).text,
                      trailingColor: dueLabel(t, now).overdue ? p.warn : null,
                      onTap: () => showTaskDetail(context, t),
                    ),
                ],
                SectionHeader('DISCIPLINAS', count: courses.length),
                for (final c in courses)
                  TermRow(
                    key: ValueKey('course-${c.id}-${c.entry.updatedAt.millisecondsSinceEpoch}'),
                    title: c.name,
                    subtitle: '${c.scheduleText}\n${c.gradesText} · faltas ${c.absencesText}',
                    trailing: c.absencesWarn ? '[!]' : null,
                    onTap: () => openCourse(context, c),
                  ),
              ],
            ),
    );
  }
}
