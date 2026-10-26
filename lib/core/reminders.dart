import 'package:flutter/material.dart' show TimeOfDay;

import 'course.dart';
import 'dates.dart';
import 'entry.dart';
import 'medication.dart';
import 'models.dart';
import 'special_dates.dart';

/// Um lembrete já decidido: quando tocar e o que dizer.
class Reminder {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.at,
    required this.title,
    required this.body,
    this.alarm = false,
  });

  /// Identificador estável (mesma tarefa e mesmo tipo = mesmo id).
  final int id;
  final String taskId;
  final DateTime at;
  final String title;
  final String body;

  /// Toca como alarme (som de despertador, tela acesa).
  final bool alarm;
}

/// Início e fim do silêncio: nada toca entre 00:00 e 05:00; quem cairia nessa
/// janela é adiado para as 05:00 do mesmo dia.
const int kSilenceEndHour = 5;

/// Hora dos lembretes de tarefas que só têm data.
const int kDateOnlyHour = 9;

/// Máximo de lembretes comuns agendados de uma vez (o Android limita alarmes).
const int kMaxReminders = 80;

/// Máximo de alarmes (remédios e tarefas com alarme). Têm limite próprio para
/// nunca serem cortados por lembretes comuns.
const int kMaxAlarms = 150;

/// Quantos dias à frente as próximas ocorrências de tarefas recorrentes
/// também ficam agendadas. Sem isso, a rotina de amanhã só teria aviso depois
/// de você abrir o app e concluir a de hoje.
const int kRecurDaysAhead = 7;

/// Lembretes de água: hora, fração da meta que já deveria ter sido atingida
/// (o aviso só toca se ainda não foi) e a mensagem. Na primeira hora (fração
/// 0) o aviso toca se ainda não houve nenhum registro no dia.
const List<(int, double, String)> kWaterSlots = [
  (6, 0.0, 'Beba seu primeiro gole d\'água'),
  (12, 0.3, 'Beba mais água'),
  (18, 0.7, 'Beba mais água'),
  (21, 1.0, 'Ainda falta beber água'),
];

/// Quantos dias à frente os alarmes de remédio ficam agendados. Como não há
/// serviço em segundo plano, o plano é refeito a cada vez que o app abre; sete
/// duas semanas cobrem uma boa viagem sem abrir o app.
const int kMedDaysAhead = 14;

/// Quantos dias à frente os avisos de água ficam agendados.
const int kWaterDaysAhead = 3;

/// O que o planejador precisa saber da água.
class WaterPlan {
  const WaterPlan({required this.goalMl, required this.mlOn});

  final int goalMl;

  /// Quanto já foi bebido no dia dado (0 para dias futuros).
  final int Function(DateTime day) mlOn;
}

/// FNV-1a de 32 bits: o mesmo texto sempre dá o mesmo número, e textos
/// diferentes (mesmo do mesmo tamanho) dão números diferentes.
int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

int _ordinal(DateTime day) => DateTime.utc(day.year, day.month, day.day)
    .difference(DateTime.utc(2020))
    .inDays;

DateTime _applySilence(DateTime at) =>
    at.hour < kSilenceEndHour ? DateTime(at.year, at.month, at.day, kSilenceEndHour) : at;

/// Decide todos os lembretes futuros. Função pura (não toca no Android), por
/// isso é testada.
///
/// - Com horário: um lembrete na hora marcada.
/// - Só com data: um na véspera às 09:00 e outro no dia às 09:00.
/// - Adiada: vale o horário do adiamento (a data efetiva da tarefa).
/// - Recorrente: a ocorrência atual e as dos próximos [kRecurDaysAhead] dias.
/// - Sem data (reutilizável) e tarefas encerradas: nenhum.
/// - Remédios: alarme em todos os horários pelos próximos [kMedDaysAhead] dias.
///
/// Lembretes comuns respeitam [limit]; alarmes têm o limite [kMaxAlarms].
List<Reminder> planReminders(
  Iterable<Task> tasks,
  DateTime now, {
  Iterable<SpecialDate> dates = const <SpecialDate>[],
  WaterPlan? water,
  Iterable<Medication> meds = const <Medication>[],
  Iterable<Course> courses = const <Course>[],
  int limit = kMaxReminders,
}) {
  final today = dateOnly(now);
  final normal = <Reminder>[];
  final alarms = <Reminder>[];

  void emit(Reminder r) => (r.alarm ? alarms : normal).add(r);

  // [primary]: ocorrência atual da tarefa (id estável por tarefa e posição).
  // As demais (recorrentes futuras) têm id por dia.
  void planDay(Task t, DateTime day, TimeOfDay? time, {required bool primary}) {
    int idFor(int slot) => primary
        ? (_fnv(t.id) & 0x1fffffff) * 4 + slot
        : (_fnv('r:${t.id}:${_ordinal(day)}:$slot') & 0x1fffffff) + 1000000000;

    void add(int slot, DateTime at, String body) {
      final when = _applySilence(at);
      if (!when.isAfter(now)) return;
      emit(Reminder(
        id: idFor(slot),
        taskId: t.id,
        at: when,
        title: t.title,
        body: body,
        alarm: t.alarm,
      ));
    }

    if (time != null) {
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      final diff = daysBetween(today, day);
      final where = diff == 0 ? 'Hoje' : diff == 1 ? 'Amanhã' : fmtDateShort(day);
      if (t.module == kModExercise) {
        // Rotina de exercício: avisa 1 hora antes.
        add(1, at.subtract(const Duration(hours: 1)),
            'Começa ${where.toLowerCase()} às ${fmtTime(time)}');
      } else {
        add(1, at, '$where às ${fmtTime(time)}');
      }
    } else {
      add(0, DateTime(day.year, day.month, day.day - 1, kDateOnlyHour), 'Vence amanhã');
      add(1, DateTime(day.year, day.month, day.day, kDateOnlyHour), 'Vence hoje');
    }
  }

  for (final t in tasks) {
    if (t.status != TaskStatus.pending && t.status != TaskStatus.snoozed) continue;
    final date = t.dueDate;
    if (date == null) continue;
    final day = dateOnly(date);
    planDay(t, day, t.dueTime, primary: true);

    final rule = t.recurrence;
    if (t.kind == TaskKind.recurring && rule != null) {
      final horizon = DateTime(today.year, today.month, today.day + kRecurDaysAhead);
      var from = day.isAfter(today) ? day : today;
      for (var i = 0; i < kRecurDaysAhead + 1; i++) {
        final next = rule.nextAfter(from);
        if (next.isAfter(horizon)) break;
        planDay(t, next, t.time, primary: false);
        from = next;
      }
    }
  }

  // Aniversários e datas: véspera e dia, às 09:00, na próxima ocorrência.
  for (final d in dates) {
    final day = d.next(today);
    final base = (_fnv('d:${d.id}') & 0x1fffffff) * 4;
    final age = d.turningAge(today);
    final what = switch (d.kind) {
      DateKind.birthday => age != null && age > 0
          ? 'Faz $age ${age == 1 ? 'ano' : 'anos'}'
          : 'Aniversário',
      DateKind.date => 'Data importante',
    };
    void addDate(int slot, DateTime at, String when) {
      final shifted = _applySilence(at);
      if (!shifted.isAfter(now)) return;
      normal.add(Reminder(
        id: base + slot,
        taskId: 'date:${d.id}',
        at: shifted,
        title: d.title,
        body: '$what $when',
      ));
    }

    addDate(0, DateTime(day.year, day.month, day.day - 1, kDateOnlyHour), 'amanhã');
    addDate(1, DateTime(day.year, day.month, day.day, kDateOnlyHour), 'hoje');
  }

  // Água: 6h, 12h, 18h e 21h, só se a meta parcial ainda não foi atingida. Como
  // o plano é refeito a cada registro de água, o aviso some assim que você bebe.
  if (water != null) {
    for (var d = 0; d < kWaterDaysAhead; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      final ml = d == 0 ? water.mlOn(day) : 0;
      for (var i = 0; i < kWaterSlots.length; i++) {
        final (hour, fraction, message) = kWaterSlots[i];
        final due = fraction == 0 ? ml == 0 : ml < fraction * water.goalMl;
        if (!due) continue;
        final at = DateTime(day.year, day.month, day.day, hour);
        if (!at.isAfter(now)) continue;
        normal.add(Reminder(
          id: 2000000000 + (_ordinal(day) % 100000) * 10 + i,
          taskId: 'water',
          at: at,
          title: 'Água',
          body: message,
        ));
      }
    }
  }

  // Remédios: sempre alarme.
  for (final m in meds) {
    if (!m.active) continue;
    final ts = m.times;
    for (var d = 0; d < kMedDaysAhead; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      for (var i = 0; i < ts.length; i++) {
        final at = _applySilence(DateTime(day.year, day.month, day.day, ts[i].hour, ts[i].minute));
        if (!at.isAfter(now)) continue;
        alarms.add(Reminder(
          id: (_fnv('m:${m.id}:${_ordinal(day)}:$i') & 0x1fffffff) + 1000000000,
          taskId: 'med:${m.id}',
          at: at,
          title: m.name,
          body: 'Hora de tomar: ${m.perDose} ${m.perDose == 1 ? 'unidade' : 'unidades'}',
          alarm: true,
        ));
      }
    }
  }

  // Aulas: um aviso por horário semanal, com a antecedência escolhida.
  for (final c in courses) {
    final lead = c.lead;
    if (lead < 0) continue;
    final ss = c.slots;
    for (var d = 0; d < kClassDaysAhead; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      for (final s in ss) {
        if (s.weekday != day.weekday) continue;
        final start = DateTime(day.year, day.month, day.day, s.time.hour, s.time.minute);
        final at = _applySilence(start.subtract(Duration(minutes: lead)));
        if (!at.isAfter(now)) continue;
        emit(Reminder(
          id: (_fnv('c:${c.id}:${_ordinal(day)}:${s.key}') & 0x1fffffff) + 1000000000,
          taskId: 'class:${c.id}',
          at: at,
          title: c.name,
          body: lead > 0
              ? 'Aula às ${fmtTime(s.time)} (em $lead min)'
              : 'Aula às ${fmtTime(s.time)}',
          alarm: c.alarm,
        ));
      }
    }
  }

  int byTime(Reminder a, Reminder b) => a.at.compareTo(b.at);
  normal.sort(byTime);
  alarms.sort(byTime);
  final all = <Reminder>[
    ...(normal.length <= limit ? normal : normal.sublist(0, limit)),
    ...(alarms.length <= kMaxAlarms ? alarms : alarms.sublist(0, kMaxAlarms)),
  ]..sort(byTime);

  // Garantia final: dois lembretes nunca ficam com o mesmo número (o segundo
  // apagaria o primeiro no sistema). Em colisão, o número é deslocado.
  final seen = <int>{};
  final out = <Reminder>[];
  for (final r in all) {
    var id = r.id;
    while (!seen.add(id)) {
      id++;
    }
    out.add(id == r.id
        ? r
        : Reminder(
            id: id,
            taskId: r.taskId,
            at: r.at,
            title: r.title,
            body: r.body,
            alarm: r.alarm,
          ));
  }
  return out;
}
