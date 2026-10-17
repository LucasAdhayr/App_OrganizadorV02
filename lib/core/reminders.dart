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

/// Máximo de lembretes agendados de uma vez (o Android limita alarmes).
const int kMaxReminders = 80;

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
/// dias cobrem alguns dias sem abrir o app.
const int kMedDaysAhead = 7;

/// Quantos dias à frente os avisos de água ficam agendados.
const int kWaterDaysAhead = 3;

/// O que o planejador precisa saber da água.
class WaterPlan {
  const WaterPlan({required this.goalMl, required this.mlOn});

  final int goalMl;

  /// Quanto já foi bebido no dia dado (0 para dias futuros).
  final int Function(DateTime day) mlOn;
}

int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

DateTime _applySilence(DateTime at) =>
    at.hour < kSilenceEndHour ? DateTime(at.year, at.month, at.day, kSilenceEndHour) : at;

/// Decide todos os lembretes futuros. Função pura (não toca no Android), por
/// isso é testada.
///
/// - Com horário: um lembrete na hora marcada.
/// - Só com data: um na véspera às 09:00 e outro no dia às 09:00.
/// - Adiada: vale o horário do adiamento (a data efetiva da tarefa).
/// - Recorrente: só a ocorrência atual; ao concluir, o plano é refeito.
/// - Sem data (reutilizável) e tarefas encerradas: nenhum.
List<Reminder> planReminders(
  Iterable<Task> tasks,
  DateTime now, {
  Iterable<SpecialDate> dates = const <SpecialDate>[],
  WaterPlan? water,
  Iterable<Medication> meds = const <Medication>[],
  int limit = kMaxReminders,
}) {
  final out = <Reminder>[];

  void add(Task t, int slot, DateTime at, String body) {
    final when = _applySilence(at);
    if (!when.isAfter(now)) return;
    out.add(Reminder(
      id: (_fnv(t.id) & 0x1fffffff) * 4 + slot,
      taskId: t.id,
      at: when,
      title: t.title,
      body: body,
      alarm: t.alarm,
    ));
  }

  for (final t in tasks) {
    if (t.status != TaskStatus.pending && t.status != TaskStatus.snoozed) continue;
    final date = t.dueDate;
    if (date == null) continue;
    final day = dateOnly(date);
    final time = t.dueTime;
    if (time != null) {
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      final where = daysBetween(dateOnly(now), day) == 0
          ? 'Hoje'
          : daysBetween(dateOnly(now), day) == 1
              ? 'Amanhã'
              : fmtDateShort(day);
      if (t.module == kModExercise) {
        // Rotina de exercício: avisa 1 hora antes.
        final when = where == 'Hoje'
            ? 'hoje'
            : where == 'Amanhã'
                ? 'amanhã'
                : where;
        add(t, 1, at.subtract(const Duration(hours: 1)),
            'Começa $when às ${fmtTime(time)}');
      } else {
        add(t, 1, at, '$where às ${fmtTime(time)}');
      }
    } else {
      add(t, 0, DateTime(day.year, day.month, day.day - 1, kDateOnlyHour), 'Vence amanhã');
      add(t, 1, DateTime(day.year, day.month, day.day, kDateOnlyHour), 'Vence hoje');
    }
  }

  // Aniversários e datas: véspera e dia, às 09:00, na próxima ocorrência.
  final today = dateOnly(now);
  for (final d in dates) {
    final day = d.next(today);
    final base = (_fnv('d:${d.id}') & 0x1fffffff) * 4;
    final what = switch (d.kind) {
      DateKind.birthday => d.turningAge(today) != null && d.turningAge(today)! > 0
          ? 'Faz ${d.turningAge(today)} ${d.turningAge(today) == 1 ? 'ano' : 'anos'}'
          : 'Aniversário',
      DateKind.date => 'Data importante',
    };
    void addDate(int slot, DateTime at, String when) {
      final shifted = _applySilence(at);
      if (!shifted.isAfter(now)) return;
      out.add(Reminder(
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
        out.add(Reminder(
          id: 2000000000 + (day.difference(DateTime(2020)).inDays % 100000) * 10 + i,
          taskId: 'water',
          at: at,
          title: 'Água',
          body: message,
        ));
      }
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  final capped = out.length <= limit ? out : out.sublist(0, limit);

  // Remédios: sempre alarme, e nunca cortados pelo limite acima.
  for (final m in meds) {
    if (!m.active) continue;
    final ts = m.times;
    for (var d = 0; d < kMedDaysAhead; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      for (var i = 0; i < ts.length; i++) {
        final at = _applySilence(DateTime(day.year, day.month, day.day, ts[i].hour, ts[i].minute));
        if (!at.isAfter(now)) continue;
        capped.add(Reminder(
          id: (_fnv('m:${m.id}:${day.difference(DateTime(2020)).inDays}:$i') & 0x1fffffff) + 1000000000,
          taskId: 'med:${m.id}',
          at: at,
          title: m.name,
          body: 'Hora de tomar: ${m.perDose} ${m.perDose == 1 ? 'unidade' : 'unidades'}',
          alarm: true,
        ));
      }
    }
  }
  capped.sort((a, b) => a.at.compareTo(b.at));
  return capped;
}
