import 'dates.dart';

/// Aniversário (de uma pessoa) ou data que não pode passar (uma data comemorativa,
/// o dia de uma prova, um vencimento anual...).
enum DateKind { birthday, date }

extension DateKindX on DateKind {
  String get label => switch (this) {
        DateKind.birthday => 'ANIVERSÁRIO',
        DateKind.date => 'DATA',
      };
}

/// Se repete todo ano, no mesmo dia e mês. O ano é opcional: com ele dá para
/// mostrar a idade ("faz 30 anos").
class SpecialDate {
  SpecialDate({
    required this.id,
    required this.title,
    required this.kind,
    required this.month,
    required this.day,
    this.year,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  String title;
  DateKind kind;
  int month;
  int day;
  int? year;
  String notes;
  final DateTime createdAt;

  /// Próxima vez que a data cai, hoje ou depois de hoje.
  DateTime next(DateTime today) => nextOccurrence(month, day, today);

  /// Idade que a pessoa faz na próxima ocorrência (null sem ano).
  int? turningAge(DateTime today) => year == null ? null : next(today).year - year!;

  /// "faz 30 anos" / "completa 30 anos" etc., ou o tipo se não houver ano.
  String describe(DateTime today) {
    final age = turningAge(today);
    if (kind == DateKind.birthday && age != null && age >= 0) {
      return age == 1 ? 'faz 1 ano' : 'faz $age anos';
    }
    if (kind == DateKind.date && year != null) {
      final years = next(today).year - year!;
      if (years > 0) return years == 1 ? '1 ano' : '$years anos';
    }
    return kind.label.toLowerCase();
  }
}

/// Próxima ocorrência de [day]/[month] a partir de [today] (inclusive). Um dia
/// que não existe naquele ano (29/02) cai no último dia do mês (28/02).
DateTime nextOccurrence(int month, int day, DateTime today) {
  final t = dateOnly(today);
  DateTime on(int y) {
    final last = DateTime(y, month + 1, 0).day;
    return DateTime(y, month, day > last ? last : day);
  }

  final thisYear = on(t.year);
  return thisYear.isBefore(t) ? on(t.year + 1) : thisYear;
}
