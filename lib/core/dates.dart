import 'package:flutter/material.dart' show TimeOfDay;

const List<String> _weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

/// Data sem hora (meia-noite local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Diferença em dias de calendário (to - from), imune a horário de verão.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

String two(int n) => n.toString().padLeft(2, '0');

String fmtTime(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

/// weekday: 1 = segunda ... 7 = domingo (padrão do DateTime.weekday).
String weekdayShort(int weekday) => _weekdays[weekday - 1];

String fmtDateShort(DateTime d) =>
    '${weekdayShort(d.weekday)} ${two(d.day)}/${two(d.month)}';

String fmtDateFull(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// "hoje 20:00", "amanhã 09:00" ou "15/10 09:00".
String fmtWhen(DateTime when, DateTime now) {
  final diff = daysBetween(now, when);
  final hm = '${two(when.hour)}:${two(when.minute)}';
  if (diff == 0) return 'hoje $hm';
  if (diff == 1) return 'amanhã $hm';
  return '${two(when.day)}/${two(when.month)} $hm';
}
