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

/// Litros no formato do Brasil: 2000 -> "2,0 L"; 1250 -> "1,25 L".
String fmtLiters(int ml) {
  var s = (ml / 1000).toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return '${s.replaceAll('.', ',')} L';
}

String fmtTime(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

/// weekday: 1 = segunda ... 7 = domingo (padrão do DateTime.weekday).
String weekdayShort(int weekday) => _weekdays[weekday - 1];

/// "SEG 05/02". O ano só aparece quando não é o ano atual ("SEG 05/02/2027"),
/// para uma data distante nunca ser confundida com uma próxima.
String fmtDateShort(DateTime d) {
  final year = d.year == DateTime.now().year ? '' : '/${d.year}';
  return '${weekdayShort(d.weekday)} ${two(d.day)}/${two(d.month)}$year';
}

String fmtDateFull(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// "hoje 20:00", "amanhã 09:00", "15/10 09:00" ou "05/02/2027 09:00".
String fmtWhen(DateTime when, DateTime now) {
  final diff = daysBetween(now, when);
  final hm = '${two(when.hour)}:${two(when.minute)}';
  if (diff == 0) return 'hoje $hm';
  if (diff == 1) return 'amanhã $hm';
  final year = when.year == now.year ? '' : '/${when.year}';
  return '${two(when.day)}/${two(when.month)}$year $hm';
}
