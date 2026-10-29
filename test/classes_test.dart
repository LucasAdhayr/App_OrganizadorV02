import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/core/course.dart';
import 'package:organizador/core/entry.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/core/reminders.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/codec.dart';

import 'fake_store.dart';

// Terça-feira, 13/10/2026, 10:00.
DateTime _clock = DateTime(2026, 10, 13, 10, 0);

AppState _app([FakeStore? store]) => AppState(clock: () => _clock, store: store);

Course _course({
  String slots = '2@07:00,4@15:00',
  int lead = 30,
  bool alarm = false,
  int maxAbs = 10,
  int abs = 3,
  int? p1,
  int? p2,
  int pass = 600,
}) =>
    Course(Entry(
      id: 'c1',
      module: kModClass,
      at: _clock,
      createdAt: _clock,
      data: <String, Object?>{
        'name': 'Máquinas de Fluxo',
        'slots': slots,
        'lead': lead,
        'alarm': alarm,
        'maxAbs': maxAbs,
        'abs': abs,
        'pass': pass,
        'p1': ?p1,
        'p2': ?p2,
      },
    ));

AppState _withCourse() {
  final s = _app();
  s.addCourse(
    name: 'Máquinas de Fluxo',
    slots: parseSlots('2@07:00,4@15:00'),
    lead: 30,
    alarm: false,
    maxAbsences: 10,
    pass: 600,
  );
  return s;
}

void main() {
  setUp(() => _clock = DateTime(2026, 10, 13, 10, 0));

  group('horários', () {
    test('lê, ordena e tira repetidos', () {
      final s = parseSlots('4@15:00, 2@07:00,2@07:00,9@10:00,x,3@25:00');
      expect(joinSlots(s), '2@07:00,4@15:00');
      expect(s.length, 2);
    });

    test('ida e volta', () {
      expect(joinSlots(parseSlots('7@23:59,1@00:00')), '1@00:00,7@23:59');
    });

    test('texto do horário', () {
      expect(_course().scheduleText, 'TER 07:00 · QUI 15:00');
      expect(_course(slots: '').scheduleText, 'sem horário');
    });

    test('próxima aula', () {
      final c = _course();
      expect(c.nextClass(DateTime(2026, 10, 13, 10)), DateTime(2026, 10, 15, 15));
      expect(c.nextClass(DateTime(2026, 10, 13, 6)), DateTime(2026, 10, 13, 7));
      expect(c.nextClass(DateTime(2026, 10, 15, 16)), DateTime(2026, 10, 20, 7));
      expect(_course(slots: '').nextClass(_clock), isNull);
    });
  });

  group('notas', () {
    test('formato e leitura', () {
      expect(fmtGrade(750), '7,5');
      expect(fmtGrade(800), '8,0');
      expect(fmtGrade(825), '8,25');
      expect(fmtGrade(1000), '10,0');
      expect(fmtGrade(5), '0,05');
      expect(parseGrade('7,5'), 750);
      expect(parseGrade('7.5'), 750);
      expect(parseGrade('10'), 1000);
      expect(parseGrade('0'), 0);
      expect(parseGrade('10,5'), isNull);
      expect(parseGrade('abc'), isNull);
      expect(parseGrade(''), isNull);
    });

    test('média só com P1 e P2', () {
      expect(_course(p1: 700).average, isNull);
      expect(_course(p1: 700, p2: 800).average, 750);
      expect(_course(p1: 500, p2: 575).average, 538);
    });

    test('quanto falta na P2 para passar', () {
      expect(_course(p1: 500).neededOnP2, 700);
      expect(_course(p1: 700).neededOnP2, 500);
      expect(_course(p1: 100).neededOnP2, 1100); // acima de 10: não dá mais
      expect(_course(p1: 700, p2: 600).neededOnP2, isNull);
      expect(_course().neededOnP2, isNull);
    });

    test('texto das notas', () {
      expect(_course().gradesText, 'P1 -- · P2 --');
      expect(_course(p1: 700, p2: 800).gradesText, 'P1 7,0 · P2 8,0 · média 7,5');
    });
  });

  group('faltas', () {
    test('quanto resta e quando avisar', () {
      expect(_course(abs: 3).absencesText, '3/10 · restam 7');
      expect(_course(abs: 3).absencesWarn, isFalse);
      expect(_course(abs: 8).absencesWarn, isTrue);
      expect(_course(abs: 10).absencesText, '10/10 · no limite');
      expect(_course(abs: 12).absencesText, '12/10 · passou 2');
      expect(_course(abs: 12).absencesWarn, isTrue);
    });

    test('sem limite definido, só conta', () {
      final c = _course(maxAbs: 0, abs: 4);
      expect(c.tracksAbsences, isFalse);
      expect(c.absencesWarn, isFalse);
      expect(c.absencesText, '4 faltas');
    });

    test('+1 e -1 nunca passam de zero para baixo; desfazer volta', () {
      final s = _withCourse();
      final c = s.courses.single;
      s.addAbsence(c, -1);
      expect(s.courses.single.absences, 0);
      s.addAbsence(c, 1);
      s.addAbsence(c, 1);
      expect(s.courses.single.absences, 2);
      s.addAbsence(c, -1);
      expect(s.courses.single.absences, 1);
    });
  });

  group('AppState', () {
    test('cadastro, notas e edição sem perder nada', () {
      final s = _withCourse();
      var c = s.courses.single;
      s.setGrade(c, 'p1', 750);
      s.addAbsence(c, 1);
      s.editCourse(c,
          name: 'Máquinas',
          slots: parseSlots('3@10:00'),
          lead: 15,
          alarm: true,
          maxAbsences: 12,
          pass: 500);
      c = s.courses.single;
      expect(c.name, 'Máquinas');
      expect(c.p1, 750);
      expect(c.absences, 1);
      expect(c.maxAbsences, 12);
      expect(c.alarm, isTrue);
      expect(c.lead, 15);
      expect(c.pass, 500);
      expect(c.scheduleText, 'QUA 10:00');
      s.setGrade(c, 'p1', null);
      expect(s.courses.single.p1, isNull);
    });

    test('aulas do dia, por horário', () {
      final s = _withCourse();
      s.addCourse(
        name: 'Cálculo',
        slots: parseSlots('2@09:00'),
        lead: -1,
        alarm: false,
        maxAbsences: 0,
        pass: 600,
      );
      final tue = s.classesOn(DateTime(2026, 10, 13));
      expect(tue.map((o) => o.course.name), ['Máquinas de Fluxo', 'Cálculo']);
      expect(s.classesOn(DateTime(2026, 10, 15)).map((o) => o.course.name), ['Máquinas de Fluxo']);
      expect(s.classesOn(DateTime(2026, 10, 14)), isEmpty);
    });

    test('prova vira tarefa ligada à disciplina e aparece na agenda', () {
      final s = _withCourse();
      final c = s.courses.single;
      final t = s.addAssignment(c,
          type: 'Prova', description: 'Capítulos 1 a 3', due: DateTime(2026, 10, 20));
      expect(t.module, kModClass);
      expect(t.ref, c.id);
      expect(t.title, 'Prova: Máquinas de Fluxo');
      expect(t.notes, 'Capítulos 1 a 3');
      expect(s.assignmentsOf(c.id).single, t);
      expect(s.allAssignments.single, t);
    });

    test('provas ordenadas pela data e concluir tira da lista', () {
      final s = _withCourse();
      final c = s.courses.single;
      final late = s.addAssignment(c, type: 'Trabalho', description: '', due: DateTime(2026, 10, 30));
      final soon = s.addAssignment(c, type: 'Prova', description: '', due: DateTime(2026, 10, 16));
      expect(s.assignmentsOf(c.id), [soon, late]);
      s.complete(soon);
      expect(s.assignmentsOf(c.id), [late]);
      expect(s.assignmentsOf(c.id, includeClosed: true).length, 2);
    });

    test('renomear a disciplina renomeia as provas', () {
      final s = _withCourse();
      final c = s.courses.single;
      final t = s.addAssignment(c, type: 'Prova', description: 'x', due: DateTime(2026, 10, 20));
      s.editCourse(c,
          name: 'MF II',
          slots: c.slots,
          lead: c.lead,
          alarm: c.alarm,
          maxAbsences: c.maxAbsences,
          pass: c.pass);
      expect(t.title, 'Prova: MF II');
    });

    test('apagar a disciplina descarta as provas pendentes', () {
      final s = _withCourse();
      final c = s.courses.single;
      final t = s.addAssignment(c, type: 'Prova', description: '', due: DateTime(2026, 10, 20));
      s.deleteCourse(c);
      expect(s.courses, isEmpty);
      expect(t.status, TaskStatus.discarded);
      expect(s.allAssignments, isEmpty);
    });

    test('prova não aparece na lista de tarefas comuns, mas sim em HOJE/AGENDA', () {
      final s = _withCourse();
      final c = s.courses.single;
      s.addAssignment(c, type: 'Prova', description: '', due: DateTime(2026, 10, 13));
      expect(s.todayView().total, 1);
    });
  });

  group('avisos', () {
    test('um aviso por aula, 30 min antes, nas próximas duas semanas', () {
      final r = planReminders(const <Task>[], _clock, courses: [_course()]);
      expect(r.first.at, DateTime(2026, 10, 15, 14, 30));
      expect(r.first.body, 'Aula às 15:00 (em 30 min)');
      expect(r.first.title, 'Máquinas de Fluxo');
      // Qui 15, ter 20, qui 22 (ter 13 já passou).
      expect(r.length, 3);
      expect(r.every((x) => !x.alarm), isTrue);
      expect(r.map((x) => x.id).toSet().length, 3);
    });

    test('sem aviso, na hora e com alarme', () {
      expect(planReminders(const <Task>[], _clock, courses: [_course(lead: -1)]), isEmpty);
      final r = planReminders(const <Task>[], _clock, courses: [_course(lead: 0, alarm: true)]);
      expect(r.first.at, DateTime(2026, 10, 15, 15, 0));
      expect(r.first.body, 'Aula às 15:00');
      expect(r.every((x) => x.alarm), isTrue);
    });

    test('silêncio: aula de madrugada avisa às 05:00', () {
      final r = planReminders(const <Task>[], _clock, courses: [_course(slots: '4@05:10')]);
      expect(r.first.at, DateTime(2026, 10, 15, 5, 0));
    });

    test('disciplina nova entra nos avisos do AppState', () {
      final s = _withCourse();
      expect(s.plannedReminders.length, greaterThanOrEqualTo(3));
    });
  });

  group('codec e backup', () {
    test('ref sobrevive ao codec e ao backup; antigo sem ref abre', () {
      final t = Task(
        id: 'a',
        title: 'Prova: MF',
        kind: TaskKind.single,
        createdAt: _clock,
        module: kModClass,
        ref: 'c1',
      );
      expect(taskFromMap(taskToMap(t)).ref, 'c1');
      expect(taskFromMap(taskToMap(t)..remove('ref')).ref, isNull);

      final s = _withCourse();
      s.saveTask(t, isNew: true);
      final back = decodeBackup(encodeBackup(s.exportSnapshot(), _clock));
      expect(back.snapshot.tasks.single.ref, 'c1');
      expect(Course(back.snapshot.entries.single).name, 'Máquinas de Fluxo');
      expect(Course(back.snapshot.entries.single).scheduleText, 'TER 07:00 · QUI 15:00');
    });

    test('disciplina persiste e volta ao reabrir', () async {
      final store = FakeStore();
      final a = _app(store);
      a.addCourse(
        name: 'Cálculo',
        slots: [const ClassSlot(2, TimeOfDay(hour: 9, minute: 0))],
        lead: 30,
        alarm: true,
        maxAbsences: 8,
        pass: 600,
      );
      await Future<void>.delayed(Duration.zero);
      final b = _app(store);
      await b.load();
      final c = b.courses.single;
      expect(c.name, 'Cálculo');
      expect(c.alarm, isTrue);
      expect(c.maxAbsences, 8);
    });
  });
}
