import 'package:flutter/material.dart' show TimeOfDay;

import '../core/dates.dart';
import '../core/models.dart';
import '../core/special_dates.dart';

// Conversão entre os objetos do app e linhas do banco. Fica separada do
// SQLite de propósito: dá para testar sem banco.
//
// Convenções:
// - enums são guardados pelo nome (texto), então reordenar um enum não
//   corrompe dados antigos;
// - datas sem hora (prazo) viram "aaaa-mm-dd", sem fuso;
// - instantes (criado em, concluído em...) viram milissegundos desde 1970.

String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

int _ms(DateTime d) => d.millisecondsSinceEpoch;

DateTime _fromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

// -------------------------------------------------------------------- tarefa

Map<String, Object?> taskToMap(Task t) {
  final r = t.recurrence;
  final time = t.time;
  return <String, Object?>{
    'id': t.id,
    'title': t.title,
    'kind': t.kind.name,
    'status': t.status.name,
    'due': t.due == null ? null : _dateKey(t.due!),
    'time_minutes': time == null ? null : time.hour * 60 + time.minute,
    'rec_type': r?.type.name,
    'rec_weekdays': r == null ? null : (r.weekdays.toList()..sort()).join(','),
    'rec_interval': r?.interval,
    'rec_day': r?.dayOfMonth,
    'rec_month': r?.month,
    'notes': t.notes,
    'created_at': _ms(t.createdAt),
    'updated_at': _ms(t.updatedAt),
    'snoozed_until': t.snoozedUntil == null ? null : _ms(t.snoozedUntil!),
    'last_done_at': t.lastDoneAt == null ? null : _ms(t.lastDoneAt!),
  };
}

Task taskFromMap(Map<String, Object?> m) {
  Recurrence? rule;
  final recType = m['rec_type'] as String?;
  if (recType != null) {
    final raw = (m['rec_weekdays'] as String?) ?? '';
    rule = Recurrence(
      type: _enumByName(RecurrenceType.values, recType, RecurrenceType.daily),
      weekdays: raw.isEmpty ? <int>{} : raw.split(',').map(int.parse).toSet(),
      interval: (m['rec_interval'] as int?) ?? 1,
      dayOfMonth: (m['rec_day'] as int?) ?? 1,
      month: (m['rec_month'] as int?) ?? 1,
    );
  }
  final minutes = m['time_minutes'] as int?;
  final due = m['due'] as String?;
  final snoozed = m['snoozed_until'] as int?;
  final lastDone = m['last_done_at'] as int?;
  return Task(
    id: m['id']! as String,
    title: m['title']! as String,
    kind: _enumByName(TaskKind.values, m['kind'], TaskKind.single),
    status: _enumByName(TaskStatus.values, m['status'], TaskStatus.pending),
    due: due == null ? null : _parseDate(due),
    time: minutes == null ? null : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    recurrence: rule,
    notes: (m['notes'] as String?) ?? '',
    createdAt: _fromMs(m['created_at']! as int),
    updatedAt: _fromMs(m['updated_at']! as int),
    snoozedUntil: snoozed == null ? null : _fromMs(snoozed),
    lastDoneAt: lastDone == null ? null : _fromMs(lastDone),
  );
}

// ----------------------------------------------------------------- histórico

Map<String, Object?> eventToMap(HistoryEvent e) => <String, Object?>{
      'id': e.id,
      'at': _ms(e.at),
      'kind': e.kind.name,
      'task_id': e.taskId,
      'task_title': e.taskTitle,
      'detail': e.detail,
    };

HistoryEvent eventFromMap(Map<String, Object?> m) => HistoryEvent(
      id: m['id']! as String,
      at: _fromMs(m['at']! as int),
      kind: _enumByName(HistoryKind.values, m['kind'], HistoryKind.edited),
      taskId: m['task_id']! as String,
      taskTitle: m['task_title']! as String,
      detail: (m['detail'] as String?) ?? '',
    );

// --------------------------------------------------------------------- notas

Map<String, Object?> noteToMap(Note n) => <String, Object?>{
      'id': n.id,
      'text': n.text,
      'created_at': _ms(n.createdAt),
      'is_idea': n.isIdea ? 1 : 0,
      'converted': n.converted ? 1 : 0,
      'deleted_at': null,
    };

Note noteFromMap(Map<String, Object?> m) => Note(
      id: m['id']! as String,
      text: m['text']! as String,
      createdAt: _fromMs(m['created_at']! as int),
      isIdea: (m['is_idea'] as int?) == 1,
      converted: (m['converted'] as int?) == 1,
    );

// ------------------------------------------------------- aniversários e datas

Map<String, Object?> dateToMap(SpecialDate d) => <String, Object?>{
      'id': d.id,
      'title': d.title,
      'kind': d.kind.name,
      'month': d.month,
      'day': d.day,
      'year': d.year,
      'notes': d.notes,
      'created_at': _ms(d.createdAt),
    };

SpecialDate dateFromMap(Map<String, Object?> m) {
  final month = m['month']! as int;
  final day = m['day']! as int;
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw const FormatException('dia ou mês fora do intervalo');
  }
  return SpecialDate(
    id: m['id']! as String,
    title: m['title']! as String,
    kind: _enumByName(DateKind.values, m['kind'], DateKind.date),
    month: month,
    day: day,
    year: m['year'] as int?,
    notes: (m['notes'] as String?) ?? '',
    createdAt: _fromMs(m['created_at']! as int),
  );
}
