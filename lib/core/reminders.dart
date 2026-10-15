import 'dates.dart';
import 'models.dart';

/// Um lembrete já decidido: quando tocar e o que dizer.
class Reminder {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Identificador estável (mesma tarefa e mesmo tipo = mesmo id).
  final int id;
  final String taskId;
  final DateTime at;
  final String title;
  final String body;
}

/// Início e fim do silêncio: nada toca entre 00:00 e 05:00; quem cairia nessa
/// janela é adiado para as 05:00 do mesmo dia.
const int kSilenceEndHour = 5;

/// Hora dos lembretes de tarefas que só têm data.
const int kDateOnlyHour = 9;

/// Máximo de lembretes agendados de uma vez (o Android limita alarmes).
const int kMaxReminders = 50;

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
      add(t, 1, at, '$where às ${fmtTime(time)}');
    } else {
      add(t, 0, DateTime(day.year, day.month, day.day - 1, kDateOnlyHour), 'Vence amanhã');
      add(t, 1, DateTime(day.year, day.month, day.day, kDateOnlyHour), 'Vence hoje');
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length <= limit ? out : out.sublist(0, limit);
}
