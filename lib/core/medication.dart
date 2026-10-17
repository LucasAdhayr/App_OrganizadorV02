import 'package:flutter/material.dart' show TimeOfDay;

import 'dates.dart';
import 'entry.dart';

const String kModMed = 'medicamentos';

/// Quantos dias ou menos de estoque já merecem um aviso escrito.
const int kMedLowDays = 7;

/// Visão de um registro do módulo MEDICAMENTOS.
///
/// Campos guardados em `Entry.data`:
/// - `name`: nome;
/// - `times`: horários, "08:00,20:00";
/// - `perDose`: unidades (comprimidos...) por horário;
/// - `stock`: quantas unidades havia em `stockAt` (milissegundos);
/// - `active`: false = "parei de tomar" (sem alarmes e sem consumo).
///
/// O estoque não pede confirmação de cada dose: ele desce sozinho, a cada
/// horário que passa. Isso evita esquecer de marcar e o número desatualizar.
class Medication {
  Medication(this.entry);

  final Entry entry;

  String get id => entry.id;
  String get name => entry.text('name');
  int get perDose => (entry.number('perDose') ?? 1).clamp(1, 99);
  bool get active => entry.data['active'] != false;
  int get stockBase => entry.number('stock') ?? 0;

  DateTime get stockAt {
    final ms = entry.number('stockAt');
    return ms == null ? entry.createdAt : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  List<TimeOfDay> get times => parseMedTimes(entry.text('times'));

  /// Unidades por dia.
  int get perDay => perDose * times.length;

  /// Quantas doses (horários) aconteceram depois de [stockAt] até [now].
  int dosesUntil(DateTime now) {
    final ts = times;
    if (ts.isEmpty || !active) return 0;
    final from = stockAt;
    if (!now.isAfter(from)) return 0;
    var count = 0;
    var day = dateOnly(from);
    final last = dateOnly(now);
    while (!day.isAfter(last)) {
      for (final t in ts) {
        final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (at.isAfter(from) && !at.isAfter(now)) count++;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return count;
  }

  /// Unidades que ainda restam agora.
  int remaining(DateTime now) =>
      (stockBase - dosesUntil(now) * perDose).clamp(0, 1 << 30);

  /// Doses que ainda dá para tomar com o que resta.
  int dosesLeft(DateTime now) => remaining(now) ~/ perDose;

  /// Último dia em que ainda há uma dose completa. null = acabou (ou parado).
  DateTime? lastDay(DateTime now) {
    final ts = times;
    if (ts.isEmpty || !active) return null;
    final k = dosesLeft(now);
    if (k <= 0) return null;
    final today = dateOnly(now);
    var leftToday = 0;
    for (final t in ts) {
      final at = DateTime(today.year, today.month, today.day, t.hour, t.minute);
      if (at.isAfter(now)) leftToday++;
    }
    if (k <= leftToday) return today;
    final k2 = k - leftToday;
    final extraDays = 1 + (k2 - 1) ~/ ts.length;
    return DateTime(today.year, today.month, today.day + extraDays);
  }

  /// Dias de remédio que faltam, contando hoje se ainda houver dose hoje.
  int? daysLeft(DateTime now) {
    final d = lastDay(now);
    return d == null ? null : daysBetween(dateOnly(now), d) + 1;
  }

  bool isOut(DateTime now) => active && times.isNotEmpty && dosesLeft(now) <= 0;

  bool isLow(DateTime now) {
    if (!active) return false;
    if (isOut(now)) return true;
    final d = daysLeft(now);
    return d != null && d <= kMedLowDays;
  }

  /// Texto do estoque: "12 un. · dura até 20/10 (4 dias)".
  String stockText(DateTime now) {
    if (!active) return 'PARADO';
    if (isOut(now)) return 'ACABOU';
    final left = remaining(now);
    final last = lastDay(now);
    final days = daysLeft(now);
    if (last == null || days == null) return '$left un.';
    return '$left un. · dura até ${fmtDateShort(last)} '
        '($days ${days == 1 ? 'dia' : 'dias'})';
  }

  /// Aviso escrito para a tela HOJE.
  String warning(DateTime now) {
    if (isOut(now)) return '$name: acabou.';
    final last = lastDay(now)!;
    final days = daysLeft(now)!;
    return '$name: acaba em ${fmtDateShort(last)} '
        '(falta${days == 1 ? '' : 'm'} $days ${days == 1 ? 'dia' : 'dias'}).';
  }

  /// Dados com o estoque "congelado" em [now]: use antes de mudar horários,
  /// dose ou parar, para o que já foi consumido não ser refeito.
  Map<String, Object?> rebased(DateTime now) => <String, Object?>{
        ...entry.data,
        'stock': remaining(now),
        'stockAt': now.millisecondsSinceEpoch,
      };
}

List<TimeOfDay> parseMedTimes(String raw) {
  final out = <TimeOfDay>[];
  for (final part in raw.split(',')) {
    final p = part.trim().split(':');
    if (p.length != 2) continue;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) continue;
    out.add(TimeOfDay(hour: h, minute: m));
  }
  out.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  // Sem duplicados.
  final seen = <int>{};
  return out.where((t) => seen.add(t.hour * 60 + t.minute)).toList();
}

String joinMedTimes(Iterable<TimeOfDay> times) =>
    (times.toList()..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)))
        .map(fmtTime)
        .join(',');
