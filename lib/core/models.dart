import 'package:flutter/material.dart' show TimeOfDay;

import 'dates.dart';

/// Os três tipos de tarefa definidos para o app.
enum TaskKind { recurring, single, reusable }

extension TaskKindX on TaskKind {
  String get label => switch (this) {
        TaskKind.recurring => 'RECORRENTE',
        TaskKind.single => 'ÚNICA',
        TaskKind.reusable => 'REUTILIZÁVEL',
      };
}

enum TaskStatus { pending, snoozed, done, discarded }

enum RecurrenceType { daily, weekdays, everyNDays, monthDay, yearly }

extension RecurrenceTypeX on RecurrenceType {
  String get label => switch (this) {
        RecurrenceType.daily => 'TODO DIA',
        RecurrenceType.weekdays => 'DIAS DA SEMANA',
        RecurrenceType.everyNDays => 'A CADA N DIAS',
        RecurrenceType.monthDay => 'DIA DO MÊS',
        RecurrenceType.yearly => 'ANUAL',
      };
}

/// Regra de repetição por calendário (data fixa). Imutável.
class Recurrence {
  const Recurrence({
    required this.type,
    this.weekdays = const <int>{},
    this.interval = 1,
    this.dayOfMonth = 1,
    this.month = 1,
  });

  final RecurrenceType type;

  /// 1 = segunda ... 7 = domingo.
  final Set<int> weekdays;
  final int interval;
  final int dayOfMonth;
  final int month;

  /// Primeira ocorrência estritamente depois de [date].
  DateTime nextAfter(DateTime date) {
    final d = dateOnly(date);
    switch (type) {
      case RecurrenceType.daily:
        return DateTime(d.year, d.month, d.day + 1);
      case RecurrenceType.weekdays:
        if (weekdays.isEmpty) return DateTime(d.year, d.month, d.day + 1);
        for (var i = 1; i <= 7; i++) {
          final c = DateTime(d.year, d.month, d.day + i);
          if (weekdays.contains(c.weekday)) return c;
        }
        return DateTime(d.year, d.month, d.day + 7);
      case RecurrenceType.everyNDays:
        return DateTime(d.year, d.month, d.day + (interval < 1 ? 1 : interval));
      case RecurrenceType.monthDay:
        final candMonth = _clamped(d.year, d.month, dayOfMonth);
        if (candMonth.isAfter(d)) return candMonth;
        return _clamped(d.year, d.month + 1, dayOfMonth);
      case RecurrenceType.yearly:
        final candYear = _clamped(d.year, month, dayOfMonth);
        if (candYear.isAfter(d)) return candYear;
        return _clamped(d.year + 1, month, dayOfMonth);
    }
  }

  /// Primeira ocorrência em [from] ou depois.
  DateTime firstOnOrAfter(DateTime from) {
    final f = dateOnly(from);
    if (type == RecurrenceType.daily || type == RecurrenceType.everyNDays) {
      return f;
    }
    return nextAfter(DateTime(f.year, f.month, f.day - 1));
  }

  /// Dia [day] do mês, limitado ao último dia daquele mês (ex.: 31 em fevereiro).
  static DateTime _clamped(int year, int month, int day) {
    final first = DateTime(year, month, 1); // normaliza meses fora de 1..12
    final last = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > last ? last : day);
  }

  String get label {
    switch (type) {
      case RecurrenceType.daily:
        return 'Todo dia';
      case RecurrenceType.weekdays:
        if (weekdays.isEmpty) return 'Todo dia';
        final days = weekdays.toList()..sort();
        return days.map(weekdayShort).join(' · ');
      case RecurrenceType.everyNDays:
        return interval <= 1 ? 'Todo dia' : 'A cada $interval dias';
      case RecurrenceType.monthDay:
        return 'Todo mês, dia $dayOfMonth';
      case RecurrenceType.yearly:
        return 'Todo ano, ${two(dayOfMonth)}/${two(month)}';
    }
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.status = TaskStatus.pending,
    this.due,
    this.time,
    this.recurrence,
    this.notes = '',
    DateTime? updatedAt,
    this.snoozedUntil,
    this.lastDoneAt,
    this.module,
    this.alarm = false,
    this.amountCents,
    this.ref,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;

  /// Módulo dono da tarefa (null = tarefa comum). Rotinas de exercício têm
  /// `exercicios`: aparecem em HOJE e AGENDA como as outras, mas pertencem ao
  /// módulo e, ao concluir, registram um treino.
  final String? module;
  String title;
  TaskKind kind;
  TaskStatus status;

  /// Toca como alarme (som de despertador, tela acesa) em vez de só notificar.
  bool alarm;

  /// Valor em centavos (contas a pagar do módulo FINANÇAS). null = sem valor.
  int? amountCents;

  /// Id do registro a que a tarefa pertence (ex.: a disciplina de uma prova).
  String? ref;

  /// Prazo (ou próxima ocorrência, se recorrente). Só a data.
  DateTime? due;
  TimeOfDay? time;
  Recurrence? recurrence;
  String notes;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? snoozedUntil;
  DateTime? lastDoneAt;

  /// Data efetiva: se a tarefa foi adiada, vale a data do adiamento; senão, o
  /// prazo (ou próxima ocorrência). É a que aparece na agenda e nos rótulos.
  DateTime? get dueDate {
    final s = snoozedUntil;
    return s != null ? dateOnly(s) : due;
  }

  /// Horário efetivo (o do adiamento, se houver).
  TimeOfDay? get dueTime {
    final s = snoozedUntil;
    return s != null ? TimeOfDay(hour: s.hour, minute: s.minute) : time;
  }

  Task copy() => Task(
        id: id,
        title: title,
        kind: kind,
        createdAt: createdAt,
        status: status,
        due: due,
        time: time,
        recurrence: recurrence,
        notes: notes,
        updatedAt: updatedAt,
        snoozedUntil: snoozedUntil,
        lastDoneAt: lastDoneAt,
        module: module,
        alarm: alarm,
        amountCents: amountCents,
        ref: ref,
      );

  void restoreFrom(Task o) {
    title = o.title;
    kind = o.kind;
    status = o.status;
    due = o.due;
    time = o.time;
    recurrence = o.recurrence;
    notes = o.notes;
    updatedAt = o.updatedAt;
    snoozedUntil = o.snoozedUntil;
    lastDoneAt = o.lastDoneAt;
    alarm = o.alarm;
    amountCents = o.amountCents;
    ref = o.ref;
  }
}

enum HistoryKind {
  created,
  done,
  skipped,
  snoozed,
  discarded,
  reopened,
  edited,
  kept,
}

extension HistoryKindX on HistoryKind {
  String get label => switch (this) {
        HistoryKind.created => 'CRIADA',
        HistoryKind.done => 'CONCLUÍDA',
        HistoryKind.skipped => 'PULADA',
        HistoryKind.snoozed => 'ADIADA',
        HistoryKind.discarded => 'DESCARTADA',
        HistoryKind.reopened => 'REABERTA',
        HistoryKind.edited => 'EDITADA',
        HistoryKind.kept => 'MANTIDA',
      };
}

class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.at,
    required this.kind,
    required this.taskId,
    required this.taskTitle,
    this.detail = '',
  });

  final String id;
  final DateTime at;
  final HistoryKind kind;
  final String taskId;
  final String taskTitle;
  final String detail;
}

class Note {
  Note({
    required this.id,
    required this.text,
    required this.createdAt,
    this.isIdea = false,
    this.converted = false,
  });

  final String id;
  String text;
  final DateTime createdAt;
  bool isIdea;
  bool converted;
}
