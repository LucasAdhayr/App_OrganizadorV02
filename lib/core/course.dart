import 'package:flutter/material.dart' show TimeOfDay;

import 'dates.dart';
import 'entry.dart';
import 'money.dart';

const String kModClass = 'aulas';

/// Nota padrão para passar (em centésimos: 600 = 6,0).
const int kDefaultPass = 600;

/// Quantos dias à frente os avisos de aula ficam agendados.
const int kClassDaysAhead = 14;

/// Antecedência do aviso, em minutos: -1 = sem aviso, 0 = na hora da aula.
const List<int> kClassLeads = [-1, 0, 15, 30, 60];

/// Um horário semanal de aula: dia da semana (1 = segunda ... 7 = domingo) e hora.
class ClassSlot {
  const ClassSlot(this.weekday, this.time);

  final int weekday;
  final TimeOfDay time;

  int get minutes => time.hour * 60 + time.minute;

  /// Chave que ordena e identifica o horário.
  int get key => weekday * 1440 + minutes;

  @override
  bool operator ==(Object other) => other is ClassSlot && other.key == key;

  @override
  int get hashCode => key;
}

/// "2@07:00,4@15:00" -> dois horários. Entradas inválidas são ignoradas;
/// o resultado vem ordenado e sem repetidos.
List<ClassSlot> parseSlots(String raw) {
  final out = <ClassSlot>[];
  for (final part in raw.split(',')) {
    final a = part.trim().split('@');
    if (a.length != 2) continue;
    final wd = int.tryParse(a[0]);
    final t = a[1].split(':');
    if (wd == null || wd < 1 || wd > 7 || t.length != 2) continue;
    final h = int.tryParse(t[0]);
    final m = int.tryParse(t[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) continue;
    out.add(ClassSlot(wd, TimeOfDay(hour: h, minute: m)));
  }
  return _sortedUnique(out);
}

List<ClassSlot> _sortedUnique(Iterable<ClassSlot> slots) {
  final seen = <int>{};
  final list = slots.where((s) => seen.add(s.key)).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return list;
}

List<ClassSlot> sortedSlots(Iterable<ClassSlot> slots) => _sortedUnique(slots);

String joinSlots(Iterable<ClassSlot> slots) =>
    _sortedUnique(slots).map((s) => '${s.weekday}@${fmtTime(s.time)}').join(',');

/// 750 -> "7,5"; 800 -> "8,0"; 825 -> "8,25".
String fmtGrade(int hundredths) {
  final s = (hundredths / 100).toStringAsFixed(2);
  final trimmed = s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  return trimmed.replaceAll('.', ',');
}

/// Lê "7,5", "7.5", "10" -> centésimos (0 a 1000). null se inválido.
int? parseGrade(String input) {
  final v = parseMoney(input);
  if (v == null || v < 0 || v > 1000) return null;
  return v;
}

/// Uma aula num dia: qual disciplina e a que horas.
class ClassOccurrence {
  const ClassOccurrence(this.course, this.time);

  final Course course;
  final TimeOfDay time;
}

/// Visão de um registro do módulo AULAS (uma disciplina).
///
/// Campos de `Entry.data`: `name`; `slots` ("2@07:00,4@15:00"); `lead`
/// (minutos de antecedência do aviso; -1 = sem aviso, 0 = na hora); `alarm` (toca como alarme);
/// `maxAbs` (faltas permitidas, 0 = não controlar); `abs` (faltas dadas);
/// `p1`, `p2` (notas em centésimos, ausentes = ainda sem nota);
/// `pass` (média para passar, em centésimos).
class Course {
  Course(this.entry);

  final Entry entry;

  String get id => entry.id;
  String get name => entry.text('name');
  List<ClassSlot> get slots => parseSlots(entry.text('slots'));
  int get lead => entry.number('lead') ?? 30;
  bool get alarm => entry.data['alarm'] == true;
  int get maxAbsences => entry.number('maxAbs') ?? 0;
  int get absences => entry.number('abs') ?? 0;
  int? get p1 => entry.number('p1');
  int? get p2 => entry.number('p2');
  int get pass => entry.number('pass') ?? kDefaultPass;

  bool get tracksAbsences => maxAbsences > 0;

  /// Quantas faltas ainda pode ter (negativo = passou do limite).
  int get absencesLeft => maxAbsences - absences;

  /// Perto do limite (2 ou menos) ou acima dele.
  bool get absencesWarn => tracksAbsences && absencesLeft <= 2;

  String get absencesText {
    if (!tracksAbsences) return '$absences ${absences == 1 ? 'falta' : 'faltas'}';
    final left = absencesLeft;
    final base = '$absences/$maxAbsences';
    if (left < 0) return '$base · passou ${-left}';
    if (left == 0) return '$base · no limite';
    return '$base · restam $left';
  }

  /// Média simples de P1 e P2 (só quando as duas existem).
  int? get average {
    final a = p1;
    final b = p2;
    if (a == null || b == null) return null;
    return ((a + b) / 2).round();
  }

  /// Nota que falta tirar na P2 para chegar à média de passar (só se há P1 e
  /// não há P2). 0 = já passou; mais de 1000 = não dá mais.
  int? get neededOnP2 {
    final a = p1;
    if (a == null || p2 != null) return null;
    final need = 2 * pass - a;
    return need < 0 ? 0 : need;
  }

  /// "P1 7,5 · P2 --" (e a média, quando existe).
  String get gradesText {
    final parts = <String>[
      'P1 ${p1 == null ? '--' : fmtGrade(p1!)}',
      'P2 ${p2 == null ? '--' : fmtGrade(p2!)}',
    ];
    final avg = average;
    if (avg != null) parts.add('média ${fmtGrade(avg)}');
    return parts.join(' · ');
  }

  /// "TER 07:00 · QUI 15:00".
  String get scheduleText => slots.isEmpty
      ? 'sem horário'
      : slots.map((s) => '${weekdayShort(s.weekday)} ${fmtTime(s.time)}').join(' · ');

  /// Horários desta disciplina no dia [day].
  List<TimeOfDay> timesOn(DateTime day) =>
      slots.where((s) => s.weekday == day.weekday).map((s) => s.time).toList();

  /// Próxima aula depois de [now] (null se não houver horários).
  DateTime? nextClass(DateTime now) {
    final ss = slots;
    if (ss.isEmpty) return null;
    DateTime? best;
    for (var d = 0; d <= 7; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      for (final s in ss) {
        if (s.weekday != day.weekday) continue;
        final at = DateTime(day.year, day.month, day.day, s.time.hour, s.time.minute);
        if (at.isAfter(now) && (best == null || at.isBefore(best))) best = at;
      }
      if (best != null) return best;
    }
    return best;
  }
}
