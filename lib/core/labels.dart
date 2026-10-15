import 'dates.dart';
import 'models.dart';

class DueLabel {
  const DueLabel(this.text, {this.overdue = false});

  final String text;
  final bool overdue;
}

/// Texto curto de prazo para a linha da tarefa. A cor nunca é o único sinal:
/// atrasadas levam "!" no texto.
DueLabel dueLabel(Task t, DateTime now) {
  final due = t.dueDate;
  if (due == null) return const DueLabel('');
  final diff = daysBetween(dateOnly(now), dateOnly(due));
  final tt = t.dueTime;
  final time = tt == null ? '' : fmtTime(tt);
  if (diff < 0) return DueLabel('!ATRASADA ${-diff}D', overdue: true);
  if (diff == 0) {
    // Hoje com horário já passado também é atraso.
    if (tt != null && tt.hour * 60 + tt.minute < now.hour * 60 + now.minute) {
      return DueLabel('!ATRASADA $time', overdue: true);
    }
    return DueLabel(time.isEmpty ? 'HOJE' : time);
  }
  if (diff == 1) return DueLabel(time.isEmpty ? 'AMANHÃ' : 'AMANHÃ $time');
  return DueLabel('${fmtDateShort(due)}${time.isEmpty ? '' : ' $time'}');
}

/// Primeira linha de um texto, limitada a [max] caracteres.
String firstLine(String text, {int max = 80}) {
  final line = text.trim().split('\n').first.trim();
  return line.length <= max ? line : '${line.substring(0, max - 1)}…';
}
