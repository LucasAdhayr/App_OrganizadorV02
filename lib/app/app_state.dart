import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import 'palette.dart';

/// Acesso ao estado a partir de qualquer widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required super.child})
      : super(notifier: notifier);

  /// Lê o estado e reconstrói o widget quando ele mudar.
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado na árvore de widgets');
    return scope!.notifier!;
  }

  /// Lê o estado sem reconstruir (use em callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado na árvore de widgets');
    return scope!.notifier!;
  }
}

extension AppContext on BuildContext {
  AppPalette get pal => AppScope.of(this).palette;
}

/// Como a tela Hoje enxerga as tarefas.
class TodayView {
  const TodayView({required this.agora, required this.hoje, required this.breve});

  final List<Task> agora;
  final List<Task> hoje;
  final List<Task> breve;

  bool get isEmpty => agora.isEmpty && hoje.isEmpty && breve.isEmpty;
  int get total => agora.length + hoje.length + breve.length;
}

class _Undo {
  _Undo(this.task, this.before, this.historyLength);

  final Task task;
  final Task before;
  final int historyLength;
}

/// Estado em memória do protótipo (Etapa 1). Na Etapa 2 os dados passam
/// para o banco local e esta classe vira a camada de regras.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock, bool seed = true})
      : clock = clock ?? DateTime.now {
    if (seed) _seed();
  }

  /// Relógio injetável, para testes.
  final DateTime Function() clock;

  final List<Task> tasks = [];
  final List<HistoryEvent> history = [];
  final List<Note> notes = [];

  AppPalette palette = AppPalette.green;
  EffectLevel effects = EffectLevel.soft;
  int reviewAfterDays = 14;

  int _seq = 0;
  _Undo? _undo;

  DateTime get now => clock();

  String newId(String prefix) => '$prefix${++_seq}';

  void tick() => notifyListeners();

  // ---------------------------------------------------------------- consultas

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isActive(Task t) =>
      t.status == TaskStatus.pending || t.status == TaskStatus.snoozed;

  /// Pendente, ou adiada cujo horário de volta já passou.
  bool isVisibleNow(Task t) {
    if (t.status == TaskStatus.pending) return true;
    if (t.status == TaskStatus.snoozed) {
      final until = t.snoozedUntil;
      return until == null || !until.isAfter(now);
    }
    return false;
  }

  /// Tarefa antiga que pede uma decisão (nunca é apagada sozinha).
  bool needsReview(Task t) {
    if (!isVisibleNow(t)) return false;
    final n = now;
    if (t.kind == TaskKind.recurring) {
      final due = t.due;
      // Além de atrasada, precisa estar sem nenhuma interação: assim "sim,
      // continua pendente" (que atualiza a tarefa) tira ela da fila.
      return due != null &&
          daysBetween(due, n) >= reviewAfterDays &&
          n.difference(t.updatedAt).inDays >= reviewAfterDays;
    }
    return n.difference(t.updatedAt).inDays >= reviewAfterDays;
  }

  List<Task> get reviewQueue {
    final list = tasks.where(needsReview).toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return list;
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  int _compare(Task a, Task b) {
    final da = a.due == null ? DateTime(9999) : dateOnly(a.due!);
    final db = b.due == null ? DateTime(9999) : dateOnly(b.due!);
    final byDay = da.compareTo(db);
    if (byDay != 0) return byDay;
    final ma = a.time == null ? 1440 : _minutes(a.time!);
    final mb = b.time == null ? 1440 : _minutes(b.time!);
    final byTime = ma.compareTo(mb);
    if (byTime != 0) return byTime;
    return a.title.compareTo(b.title);
  }

  TodayView todayView() {
    final n = now;
    final today = dateOnly(n);
    final nowMin = n.hour * 60 + n.minute;
    final agora = <Task>[];
    final hoje = <Task>[];
    final breve = <Task>[];

    for (final t in tasks) {
      if (!isVisibleNow(t) || needsReview(t)) continue;
      final due = t.due == null ? null : dateOnly(t.due!);
      final diff = due == null ? null : daysBetween(today, due);

      if (diff != null && diff < 0) {
        agora.add(t); // atrasada, mas ainda dentro do prazo de revisão
      } else if (diff == 0 && t.time != null && _minutes(t.time!) <= nowMin + 60) {
        agora.add(t); // horário já passou ou chega em até 1 hora
      } else if (diff == 0 ||
          t.status == TaskStatus.snoozed ||
          (t.kind == TaskKind.reusable && due == null)) {
        hoje.add(t);
      } else if (diff != null && diff > 0 && diff <= 3) {
        breve.add(t);
      }
    }

    agora.sort(_compare);
    hoje.sort(_compare);
    breve.sort(_compare);
    return TodayView(agora: agora, hoje: hoje, breve: breve);
  }

  int doneToday() {
    final today = dateOnly(now);
    return history
        .where((e) => e.kind == HistoryKind.done && sameDay(e.at, today))
        .length;
  }

  // -------------------------------------------------------------------- ações

  void _remember(Task t) => _undo = _Undo(t, t.copy(), history.length);

  void _log(HistoryKind kind, Task t, {String detail = ''}) {
    history.add(HistoryEvent(
      id: newId('h'),
      at: now,
      kind: kind,
      taskId: t.id,
      taskTitle: t.title,
      detail: detail,
    ));
  }

  /// Desfaz a última ação rápida (concluir, adiar, descartar...).
  void undo() {
    final u = _undo;
    if (u == null) return;
    u.task.restoreFrom(u.before);
    if (history.length > u.historyLength) {
      history.removeRange(u.historyLength, history.length);
    }
    _undo = null;
    notifyListeners();
  }

  void complete(Task t) {
    _remember(t);
    final n = now;
    final today = dateOnly(n);
    t.lastDoneAt = n;
    t.updatedAt = n;
    t.snoozedUntil = null;
    switch (t.kind) {
      case TaskKind.recurring:
        {
          // Cada ocorrência tem o seu estado: concluir a de hoje não "conserta"
          // as perdidas, e as perdidas não contaminam as futuras.
          final rule =
              t.recurrence ?? const Recurrence(type: RecurrenceType.daily);
          final due = t.due;
          final base =
              (due != null && due.isAfter(today)) ? dateOnly(due) : today;
          t.due = rule.nextAfter(base);
          t.status = TaskStatus.pending;
        }
      case TaskKind.single:
      case TaskKind.reusable:
        t.status = TaskStatus.done;
    }
    _log(HistoryKind.done, t);
    notifyListeners();
  }

  void snooze(Task t, DateTime until) {
    _remember(t);
    t.status = TaskStatus.snoozed;
    t.snoozedUntil = until;
    t.updatedAt = now;
    _log(HistoryKind.snoozed, t, detail: 'até ${fmtWhen(until, now)}');
    notifyListeners();
  }

  void discard(Task t) {
    _remember(t);
    t.status = TaskStatus.discarded;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.discarded, t);
    notifyListeners();
  }

  /// Pula só a ocorrência atual de uma tarefa recorrente.
  void skip(Task t) {
    final rule = t.recurrence;
    if (rule == null) return;
    _remember(t);
    final today = dateOnly(now);
    final due = t.due;
    final base = (due != null && due.isAfter(today)) ? dateOnly(due) : today;
    t.due = rule.nextAfter(base);
    t.status = TaskStatus.pending;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.skipped, t);
    notifyListeners();
  }

  /// "Preciso de novo" (reutilizável) ou reabrir qualquer tarefa encerrada.
  void reopen(Task t) {
    _remember(t);
    t.status = TaskStatus.pending;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.reopened, t);
    notifyListeners();
  }

  /// Revisão: "sim, continua pendente".
  void keepPending(Task t) {
    _remember(t);
    t.updatedAt = now;
    t.snoozedUntil = null;
    if (t.status == TaskStatus.snoozed) t.status = TaskStatus.pending;
    _log(HistoryKind.kept, t);
    notifyListeners();
  }

  void saveTask(Task t, {required bool isNew}) {
    if (isNew) {
      tasks.add(t);
      _log(HistoryKind.created, t);
    } else {
      t.updatedAt = now;
      _log(HistoryKind.edited, t);
    }
    _undo = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------- notas

  Note addNote(String text, {bool idea = false}) {
    final n = Note(id: newId('n'), text: text, createdAt: now, isIdea: idea);
    notes.add(n);
    notifyListeners();
    return n;
  }

  void toggleIdea(Note n) {
    n.isIdea = !n.isIdea;
    notifyListeners();
  }

  void markConverted(Note n) {
    n.converted = true;
    notifyListeners();
  }

  int removeNote(Note n) {
    final i = notes.indexOf(n);
    if (i >= 0) notes.removeAt(i);
    notifyListeners();
    return i;
  }

  void insertNote(int index, Note n) {
    notes.insert(index.clamp(0, notes.length), n);
    notifyListeners();
  }

  // ---------------------------------------------------------------- aparência

  void setEffects(EffectLevel level) {
    effects = level;
    notifyListeners();
  }

  void setPalette(AppPalette p) {
    palette = p;
    notifyListeners();
  }

  void setReviewAfterDays(int days) {
    reviewAfterDays = days.clamp(3, 90);
    notifyListeners();
  }

  // --------------------------------------------------------- dados de exemplo

  void _seed() {
    final n = now;
    final today = dateOnly(n);
    DateTime day(int offset) => DateTime(today.year, today.month, today.day + offset);
    DateTime ago(int days) => n.subtract(Duration(days: days));

    const monthly = Recurrence(type: RecurrenceType.monthDay, dayOfMonth: 15);
    const classes = Recurrence(type: RecurrenceType.weekdays, weekdays: {2, 4});
    const gym = Recurrence(type: RecurrenceType.weekdays, weekdays: {1, 3, 5});

    final gymTask = Task(
      id: newId('t'),
      title: 'Treino de musculação',
      kind: TaskKind.recurring,
      recurrence: gym,
      due: gym.firstOnOrAfter(today),
      time: const TimeOfDay(hour: 18, minute: 0),
      createdAt: ago(30),
    );
    final cleaning = Task(
      id: newId('t'),
      title: 'Limpar o quarto',
      kind: TaskKind.reusable,
      status: TaskStatus.done,
      createdAt: ago(40),
      updatedAt: ago(6),
      lastDoneAt: ago(6),
    );

    tasks.addAll([
      Task(
        id: newId('t'),
        title: 'Estudar para a prova de Física',
        kind: TaskKind.single,
        due: day(-2),
        createdAt: ago(6),
        updatedAt: ago(1),
      ),
      Task(
        id: newId('t'),
        title: 'Prova de Cálculo II',
        kind: TaskKind.single,
        due: day(0),
        time: const TimeOfDay(hour: 14, minute: 0),
        createdAt: ago(8),
      ),
      Task(
        id: newId('t'),
        title: 'Entregar o relatório do TFG',
        kind: TaskKind.single,
        due: day(2),
        createdAt: ago(9),
      ),
      Task(
        id: newId('t'),
        title: 'Pagar a internet',
        kind: TaskKind.recurring,
        recurrence: monthly,
        due: monthly.firstOnOrAfter(today),
        createdAt: ago(60),
      ),
      Task(
        id: newId('t'),
        title: 'Aula de Cálculo',
        kind: TaskKind.recurring,
        recurrence: classes,
        due: classes.firstOnOrAfter(today),
        time: const TimeOfDay(hour: 19, minute: 0),
        createdAt: ago(45),
      ),
      gymTask,
      Task(
        id: newId('t'),
        title: 'Comprar ração',
        kind: TaskKind.single,
        createdAt: ago(3),
      ),
      cleaning,
      Task(
        id: newId('t'),
        title: 'Trocar o lençol',
        kind: TaskKind.reusable,
        createdAt: ago(20),
        updatedAt: ago(2),
      ),
      Task(
        id: newId('t'),
        title: 'Renovar a CNH',
        kind: TaskKind.single,
        createdAt: ago(40),
      ),
      Task(
        id: newId('t'),
        title: 'Ligar para o dentista',
        kind: TaskKind.single,
        createdAt: ago(21),
      ),
    ]);

    history.addAll([
      HistoryEvent(
        id: newId('h'),
        at: ago(1),
        kind: HistoryKind.done,
        taskId: gymTask.id,
        taskTitle: gymTask.title,
      ),
      HistoryEvent(
        id: newId('h'),
        at: ago(6),
        kind: HistoryKind.done,
        taskId: cleaning.id,
        taskTitle: cleaning.title,
      ),
    ]);

    notes.addAll([
      Note(
        id: newId('n'),
        text: 'Gráfico de tarefas concluídas por semana no HTML de análise',
        createdAt: ago(1),
        isIdea: true,
      ),
      Note(
        id: newId('n'),
        text: 'Perguntar ao orientador sobre o prazo do TFG',
        createdAt: ago(2),
      ),
    ]);
  }
}
