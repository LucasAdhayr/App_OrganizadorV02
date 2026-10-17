import 'dart:async';

import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/entry.dart';
import '../core/medication.dart';
import '../core/ids.dart';
import '../core/models.dart';
import '../core/reminders.dart';
import '../core/special_dates.dart';
import '../data/backup.dart';
import '../data/store.dart';
import '../services/backup_manager.dart';
import '../services/notifier.dart';
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

  /// Treino registrado junto com a conclusão (desfazer remove).
  Entry? entry;
}

/// Regras do app. Os dados vivem em memória (rápido para a interface) e cada
/// alteração é gravada na hora no [AppStore] (banco local). Ao abrir o app,
/// [load] traz tudo de volta. Sem [AppStore] (testes), só existe a memória.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock, bool seed = false, AppStore? store})
      : clock = clock ?? DateTime.now,
        // ignore: prefer_initializing_formals
        _store = store {
    if (seed) _seed();
  }

  /// Relógio injetável, para testes.
  final DateTime Function() clock;

  AppStore? _store;
  Notifier? _notifier;

  /// Backups (null em testes sem Android).
  BackupManager? backup;
  bool _replanQueued = false;

  /// Liga o banco depois da criação (usado pelo main, que abre o banco antes).
  void attachStore(AppStore store) => _store = store;

  /// Notificações (null se não iniciaram). Usado pela tela de diagnóstico.
  Notifier? get notifier => _notifier;

  /// Liga as notificações e já agenda os lembretes do que existe.
  void attachNotifier(Notifier n) {
    _notifier = n;
    replan();
  }

  /// Lembretes que valem agora (usado também pela tela de diagnóstico).
  List<Reminder> get plannedReminders => planReminders(
        tasks,
        now,
        dates: dates,
        water: waterReminders
            ? WaterPlan(goalMl: waterGoalMl, mlOn: waterMlOn)
            : null,
        meds: medications,
      );

  /// Resumo do último plano enviado ao sistema. Se o plano novo for igual, não
  /// há nada a fazer (o relógio chama [replan] todo minuto).
  String? _planSignature;

  /// Refaz os lembretes agendados. Várias chamadas seguidas viram uma só, e
  /// nada é enviado se o plano não mudou. [force] reenvia mesmo assim (ao
  /// voltar para o app), comparando com o que o sistema realmente tem.
  void replan({bool force = false}) {
    if (_notifier == null) return;
    if (force) _planSignature = null;
    if (_replanQueued) return;
    _replanQueued = true;
    scheduleMicrotask(() {
      _replanQueued = false;
      final n = _notifier;
      if (n == null) return;
      final plan = plannedReminders;
      final sig = plan
          .map((r) => '${r.id}|${r.at.millisecondsSinceEpoch}|${r.alarm}|${r.title}|${r.body}')
          .join('\n');
      if (sig == _planSignature) return;
      _planSignature = sig;
      n.replace(plan).then((_) async {
        // Se o sistema recusou algo, tenta de novo na próxima volta do relógio.
        final st = await n.status();
        if (st.error != null) _planSignature = null;
      }).catchError((Object _) {
        _planSignature = null;
      });
    });
  }

  /// Mensagem de erro de armazenamento (banco indisponível, falha ao gravar).
  /// A interface mostra um aviso enquanto ela existir.
  String? storageError;

  final List<Task> tasks = [];
  final List<HistoryEvent> history = [];
  final List<Note> notes = [];
  final List<SpecialDate> dates = [];
  final List<Entry> entries = [];

  AppPalette palette = AppPalette.green;
  EffectLevel effects = EffectLevel.soft;
  int reviewAfterDays = 14;

  /// Cada toque em "+" na água registra este tanto.
  static const int waterStepMl = 200;

  /// Meta diária de água, em mililitros (a interface mostra em litros).
  int waterGoalMl = 2000;

  /// Avisos de água (6h, 12h, 18h e 21h).
  bool waterReminders = true;

  // Backup: quando foi o último, qual arquivo e de que tipo; e se o automático
  // está ligado.
  DateTime? lastBackupAt;
  String? lastBackupName;
  BackupKind? lastBackupKind;
  bool autoBackup = true;

  _Undo? _undo;

  DateTime get now => clock();

  /// Identificador único (UUID) com um prefixo legível: "t-...", "h-...".
  String newId(String prefix) => '$prefix-${newUuid()}';

  void tick() => notifyListeners();

  // -------------------------------------------------------------- persistência

  /// Lê tudo do banco. Chamado uma vez, ao abrir o app.
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final snap = await store.load();
    _applySnapshot(snap);
    final at = int.tryParse(snap.settings['lastBackupAt'] ?? '');
    lastBackupAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    lastBackupName = snap.settings['lastBackupName'];
    lastBackupKind = BackupKind.values
        .where((k) => k.name == snap.settings['lastBackupKind'])
        .firstOrNull;
    autoBackup = snap.settings['autoBackup'] != '0';
    notifyListeners();
  }

  /// Coloca na memória o que veio do banco ou de um backup restaurado.
  void _applySnapshot(StoreSnapshot snap) {
    _undo = null;
    tasks
      ..clear()
      ..addAll(snap.tasks);
    history
      ..clear()
      ..addAll(snap.history);
    notes
      ..clear()
      ..addAll(snap.notes);
    dates
      ..clear()
      ..addAll(snap.dates);
    entries
      ..clear()
      ..addAll(snap.entries);

    final paletteId = snap.settings['palette'];
    palette = AppPalette.all.firstWhere(
      (p) => p.id == paletteId,
      orElse: () => AppPalette.green,
    );
    final fx = snap.settings['effects'];
    effects = EffectLevel.values.firstWhere(
      (e) => e.name == fx,
      orElse: () => EffectLevel.soft,
    );
    reviewAfterDays =
        (int.tryParse(snap.settings['reviewAfterDays'] ?? '') ?? 14).clamp(3, 90);
    // Versões antigas guardavam a meta em copos ("waterGoal"): 1 copo = 200 ml.
    final legacyGlasses = int.tryParse(snap.settings['waterGoal'] ?? '');
    waterGoalMl = (int.tryParse(snap.settings['waterGoalMl'] ?? '') ??
            (legacyGlasses != null ? legacyGlasses * waterStepMl : 2000))
        .clamp(500, 6000);
    waterReminders = snap.settings['waterReminders'] != '0';
    // Adiamentos antigos (status "adiada") viram pendente + data adiada.
    for (final t in tasks) {
      if (t.status == TaskStatus.snoozed) {
        t.status = TaskStatus.pending;
        _saveTask(t);
      }
    }
    replan();
  }

  /// Tudo o que vai para um arquivo de backup.
  StoreSnapshot exportSnapshot() => StoreSnapshot(
        tasks: List.of(tasks),
        history: List.of(history),
        notes: List.of(notes),
        dates: List.of(dates),
        entries: List.of(entries),
        settings: <String, String>{
          'palette': palette.id,
          'effects': effects.name,
          'reviewAfterDays': '$reviewAfterDays',
          'waterGoalMl': '$waterGoalMl',
          'waterReminders': waterReminders ? '1' : '0',
        },
      );

  /// Substitui todos os dados pelos de [snap] (restauração de backup). Grava
  /// no banco primeiro; só mexe na memória se isso der certo.
  Future<void> restoreFrom(StoreSnapshot snap) async {
    await _store?.replaceAll(snap);
    _applySnapshot(snap);
    notifyListeners();
  }

  void setBackupInfo(DateTime at, String name, BackupKind kind) {
    // A cópia de segurança de uma restauração não conta como "último backup".
    if (kind == BackupKind.safety) return;
    lastBackupAt = at;
    lastBackupName = name;
    lastBackupKind = kind;
    _save((s) => s.setSetting('lastBackupAt', '${at.millisecondsSinceEpoch}'));
    _save((s) => s.setSetting('lastBackupName', name));
    _save((s) => s.setSetting('lastBackupKind', kind.name));
    notifyListeners();
  }

  void setAutoBackup(bool on) {
    autoBackup = on;
    _save((s) => s.setSetting('autoBackup', on ? '1' : '0'));
    notifyListeners();
  }

  /// Grava em segundo plano, na ordem das chamadas. Se falhar, guarda o erro
  /// para a interface avisar em vez de perder dados em silêncio.
  void _save(Future<void> Function(AppStore store) op) {
    final store = _store;
    if (store == null) return;
    op(store).catchError((Object e) {
      storageError = 'Não foi possível salvar os dados: $e';
      notifyListeners();
    });
  }

  void _saveTask(Task t) {
    _save((s) => s.upsertTask(t));
    replan();
  }

  void _saveNote(Note n) => _save((s) => s.upsertNote(n));

  // ---------------------------------------------------------------- consultas

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isActive(Task t) =>
      t.status == TaskStatus.pending || t.status == TaskStatus.snoozed;

  /// Adiar não muda o estado da tarefa: ela continua pendente, só com outra
  /// data/hora (ver [Task.dueDate]). Por isso toda tarefa ativa é visível.
  bool isVisibleNow(Task t) => isActive(t);

  /// Tarefa antiga que pede uma decisão (nunca é apagada sozinha).
  bool needsReview(Task t) {
    if (!isVisibleNow(t)) return false;
    final n = now;
    if (t.kind == TaskKind.recurring) {
      final due = t.dueDate;
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
    final da = a.dueDate == null ? DateTime(9999) : dateOnly(a.dueDate!);
    final db = b.dueDate == null ? DateTime(9999) : dateOnly(b.dueDate!);
    final byDay = da.compareTo(db);
    if (byDay != 0) return byDay;
    final ma = a.dueTime == null ? 1440 : _minutes(a.dueTime!);
    final mb = b.dueTime == null ? 1440 : _minutes(b.dueTime!);
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
      final due = t.dueDate == null ? null : dateOnly(t.dueDate!);
      final diff = due == null ? null : daysBetween(today, due);
      final time = t.dueTime;
      final snoozedAhead = t.snoozedUntil?.isAfter(n) ?? false;

      if (diff != null && diff < 0) {
        agora.add(t); // atrasada, mas ainda dentro do prazo de revisão
      } else if (diff == 0 &&
          time != null &&
          !snoozedAhead &&
          _minutes(time) <= nowMin + 60) {
        agora.add(t); // horário já passou ou chega em até 1 hora
      } else if (diff == 0 || (t.kind == TaskKind.reusable && due == null)) {
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
    final event = HistoryEvent(
      id: newId('h'),
      at: now,
      kind: kind,
      taskId: t.id,
      taskTitle: t.title,
      detail: detail,
    );
    history.add(event);
    _save((s) => s.addHistory(event));
  }

  /// Desfaz a última ação rápida (concluir, adiar, descartar...).
  void undo() {
    final u = _undo;
    if (u == null) return;
    u.task.restoreFrom(u.before);
    if (history.length > u.historyLength) {
      final removed = history.sublist(u.historyLength).map((e) => e.id).toList();
      history.removeRange(u.historyLength, history.length);
      _save((s) => s.deleteHistory(removed));
    }
    final made = u.entry;
    if (made != null) {
      entries.remove(made);
      _save((s) => s.deleteEntry(made.id));
    }
    _saveTask(u.task);
    _undo = null;
    notifyListeners();
  }

  /// Tarefa recorrente só pode ser concluída (ou pulada) a partir do dia da
  /// sua ocorrência. Sem isso, dava para clicar "concluir" sem parar e ela
  /// andava semanas para a frente. Única e reutilizável não têm essa trava.
  bool canComplete(Task t) {
    if (t.kind != TaskKind.recurring) return true;
    final due = t.dueDate;
    return due == null || !dateOnly(due).isAfter(dateOnly(now));
  }

  /// Conclui a tarefa. Devolve false (sem mudar nada) se ainda não puder.
  bool complete(Task t) {
    if (!canComplete(t)) return false;
    _remember(t);
    final n = now;
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
          t.due = rule.nextAfter(dateOnly(n));
          t.status = TaskStatus.pending;
        }
      case TaskKind.single:
      case TaskKind.reusable:
        t.status = TaskStatus.done;
    }
    _log(HistoryKind.done, t);
    if (t.module == kModExercise) {
      // Concluir a rotina registra o treino feito.
      final e = Entry(
        id: newId('e'),
        module: kModExercise,
        at: n,
        data: <String, Object?>{'kind': t.title, 'notes': '', 'routine': t.id},
        createdAt: n,
      );
      entries.add(e);
      _save((s) => s.upsertEntry(e));
      _undo?.entry = e;
    }
    _saveTask(t);
    notifyListeners();
    return true;
  }

  /// Adia a tarefa para [until] (data e hora). Ela continua pendente e passa a
  /// aparecer nessa data na agenda. Não conclui nem entra no histórico.
  void snooze(Task t, DateTime until) {
    _remember(t);
    t.status = TaskStatus.pending;
    t.snoozedUntil = until;
    t.updatedAt = now;
    _saveTask(t);
    notifyListeners();
  }

  void discard(Task t) {
    _remember(t);
    t.status = TaskStatus.discarded;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.discarded, t);
    _saveTask(t);
    notifyListeners();
  }

  /// Pula só a ocorrência atual de uma tarefa recorrente. Devolve false (sem
  /// mudar nada) se a tarefa não repete ou se a ocorrência ainda não chegou.
  bool skip(Task t) {
    final rule = t.recurrence;
    if (rule == null || !canComplete(t)) return false;
    _remember(t);
    t.due = rule.nextAfter(dateOnly(now));
    t.status = TaskStatus.pending;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.skipped, t);
    _saveTask(t);
    notifyListeners();
    return true;
  }

  /// "Preciso de novo" (reutilizável) ou reabrir qualquer tarefa encerrada.
  void reopen(Task t) {
    _remember(t);
    t.status = TaskStatus.pending;
    t.snoozedUntil = null;
    t.updatedAt = now;
    _log(HistoryKind.reopened, t);
    _saveTask(t);
    notifyListeners();
  }

  /// Revisão: "sim, continua pendente".
  void keepPending(Task t) {
    _remember(t);
    t.updatedAt = now;
    t.snoozedUntil = null;
    if (t.status == TaskStatus.snoozed) t.status = TaskStatus.pending;
    _log(HistoryKind.kept, t);
    _saveTask(t);
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
    _saveTask(t);
    _undo = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- histórico

  /// Apaga um registro do histórico (a tarefa não é afetada). Devolve a
  /// posição, para o "desfazer" recolocar no mesmo lugar.
  int removeHistoryEvent(HistoryEvent e) {
    final i = history.indexWhere((x) => x.id == e.id);
    if (i >= 0) history.removeAt(i);
    _save((s) => s.deleteHistory([e.id]));
    notifyListeners();
    return i;
  }

  void insertHistoryEvent(int index, HistoryEvent e) {
    history.insert(index.clamp(0, history.length), e);
    _save((s) => s.addHistory(e));
    notifyListeners();
  }

  /// Corrige quando o registro aconteceu (ex.: concluí ontem e só marquei hoje).
  void changeHistoryTime(HistoryEvent e, DateTime at) {
    final i = history.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    final updated = HistoryEvent(
      id: e.id,
      at: at,
      kind: e.kind,
      taskId: e.taskId,
      taskTitle: e.taskTitle,
      detail: e.detail,
    );
    history[i] = updated;
    _save((s) => s.addHistory(updated));
    notifyListeners();
  }

  // ----------------------------------------- registros dos módulos simples

  /// Registros de um módulo, do mais recente para o mais antigo.
  List<Entry> entriesOf(String module) =>
      entries.where((e) => e.module == module).toList()..sort((a, b) => b.at.compareTo(a.at));

  Entry addEntry(String module, {DateTime? at, Map<String, Object?>? data}) {
    final n = now;
    final e = Entry(id: newId('e'), module: module, at: at ?? n, data: data, createdAt: n);
    entries.add(e);
    _save((s) => s.upsertEntry(e));
    replan();
    notifyListeners();
    return e;
  }

  /// Troca [at] e/ou [data] de um registro.
  void updateEntry(Entry e, {DateTime? at, Map<String, Object?>? data}) {
    if (at != null) e.at = at;
    if (data != null) e.data = data;
    e.updatedAt = now;
    _save((s) => s.upsertEntry(e));
    replan();
    notifyListeners();
  }

  /// Remove o registro e devolve a posição, para o "desfazer".
  int removeEntry(Entry e) {
    final i = entries.indexOf(e);
    if (i >= 0) entries.removeAt(i);
    _save((s) => s.deleteEntry(e.id));
    replan();
    notifyListeners();
    return i;
  }

  void insertEntry(int index, Entry e) {
    entries.insert(index.clamp(0, entries.length), e);
    _save((s) => s.upsertEntry(e));
    replan();
    notifyListeners();
  }

  // ------------------------------------------------------------- medicamentos

  /// Todos os remédios (ativos primeiro, depois os parados), por nome.
  List<Medication> get medications {
    final list = entries.where((e) => e.module == kModMed).map(Medication.new).toList();
    list.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Remédios ativos com estoque baixo (7 dias ou menos) ou acabado.
  List<Medication> get lowMedications =>
      medications.where((m) => m.isLow(now)).toList();

  Medication addMedication({
    required String name,
    required List<TimeOfDay> times,
    required int perDose,
    required int stock,
  }) {
    final n = now;
    final e = addEntry(kModMed, data: <String, Object?>{
      'name': name,
      'times': joinMedTimes(times),
      'perDose': perDose,
      'stock': stock,
      'stockAt': n.millisecondsSinceEpoch,
      'active': true,
    });
    return Medication(e);
  }

  /// Muda nome, horários e dose sem refazer o consumo já ocorrido.
  void editMedication(
    Medication m, {
    required String name,
    required List<TimeOfDay> times,
    required int perDose,
  }) {
    final data = m.rebased(now)
      ..['name'] = name
      ..['times'] = joinMedTimes(times)
      ..['perDose'] = perDose;
    updateEntry(m.entry, data: data);
  }

  /// "Comprei mais": soma [amount] ao que resta agora.
  void addMedicationStock(Medication m, int amount) {
    final data = m.rebased(now)..['stock'] = m.remaining(now) + amount;
    updateEntry(m.entry, data: data);
  }

  /// Define o estoque exato de agora (corrigir a contagem).
  void setMedicationStock(Medication m, int units) {
    final data = m.rebased(now)..['stock'] = units;
    updateEntry(m.entry, data: data);
  }

  /// "Parei de tomar": sem alarmes e sem consumo de estoque.
  void stopMedication(Medication m) {
    final data = m.rebased(now)..['active'] = false;
    updateEntry(m.entry, data: data);
  }

  /// Volta a tomar: o consumo recomeça agora.
  void resumeMedication(Medication m) {
    final data = m.rebased(now)..['active'] = true;
    updateEntry(m.entry, data: data);
  }

  // ---------------------------------------------------------------------- água

  /// Água bebida no dia [day], em ml. Registros antigos (sem `ml`) valem 200.
  int waterMlOn(DateTime day) => entries
      .where((e) => e.module == kModWater && sameDay(e.at, day))
      .fold<int>(0, (sum, e) => sum + (e.number('ml') ?? waterStepMl));

  Entry addWater() => addEntry(kModWater, data: <String, Object?>{'ml': waterStepMl});

  /// Tira o último registro de água de hoje. Devolve o removido (ou null).
  Entry? removeLastWater() {
    final today = entriesOf(kModWater).where((e) => sameDay(e.at, now)).toList();
    if (today.isEmpty) return null;
    removeEntry(today.first);
    return today.first;
  }

  /// Meta em ml, entre 0,5 L e 6 L.
  void setWaterGoalMl(int ml) {
    waterGoalMl = ml.clamp(500, 6000);
    _save((s) => s.setSetting('waterGoalMl', '$waterGoalMl'));
    replan();
    notifyListeners();
  }

  void setWaterReminders(bool on) {
    waterReminders = on;
    _save((s) => s.setSetting('waterReminders', on ? '1' : '0'));
    replan();
    notifyListeners();
  }

  // ------------------------------------------------- aniversários e datas

  /// Datas ordenadas pela próxima ocorrência.
  List<SpecialDate> datesByNext() {
    final today = dateOnly(now);
    return List.of(dates)
      ..sort((a, b) {
        final byDay = a.next(today).compareTo(b.next(today));
        return byDay != 0 ? byDay : a.title.compareTo(b.title);
      });
  }

  /// Datas que caem hoje ou nos próximos [withinDays] dias.
  List<SpecialDate> upcomingDates({int withinDays = 3}) {
    final today = dateOnly(now);
    return datesByNext()
        .where((d) => daysBetween(today, d.next(today)) <= withinDays)
        .toList();
  }

  void saveDate(SpecialDate d, {required bool isNew}) {
    if (isNew) dates.add(d);
    _save((s) => s.upsertDate(d));
    replan();
    notifyListeners();
  }

  /// Remove a data e devolve a posição, para o "desfazer" recolocá-la.
  int removeDate(SpecialDate d) {
    final i = dates.indexOf(d);
    if (i >= 0) dates.removeAt(i);
    _save((s) => s.deleteDate(d.id));
    replan();
    notifyListeners();
    return i;
  }

  void insertDate(int index, SpecialDate d) {
    dates.insert(index.clamp(0, dates.length), d);
    _save((s) => s.upsertDate(d));
    replan();
    notifyListeners();
  }

  // -------------------------------------------------------------------- notas

  void editNote(Note n, String text) {
    n.text = text;
    _saveNote(n);
    notifyListeners();
  }

  Note addNote(String text, {bool idea = false}) {
    final n = Note(id: newId('n'), text: text, createdAt: now, isIdea: idea);
    notes.add(n);
    _saveNote(n);
    notifyListeners();
    return n;
  }

  void toggleIdea(Note n) {
    n.isIdea = !n.isIdea;
    _saveNote(n);
    notifyListeners();
  }

  void markConverted(Note n) {
    n.converted = true;
    _saveNote(n);
    notifyListeners();
  }

  /// Remove a nota da lista (no banco é remoção lógica) e devolve a posição,
  /// para o "desfazer" colocá-la de volta no mesmo lugar.
  int removeNote(Note n) {
    final i = notes.indexOf(n);
    if (i >= 0) notes.removeAt(i);
    _save((s) => s.deleteNote(n.id));
    notifyListeners();
    return i;
  }

  void insertNote(int index, Note n) {
    notes.insert(index.clamp(0, notes.length), n);
    _saveNote(n);
    notifyListeners();
  }

  // ---------------------------------------------------------------- aparência

  void setEffects(EffectLevel level) {
    effects = level;
    _save((s) => s.setSetting('effects', level.name));
    notifyListeners();
  }

  void setPalette(AppPalette p) {
    palette = p;
    _save((s) => s.setSetting('palette', p.id));
    notifyListeners();
  }

  void setReviewAfterDays(int days) {
    reviewAfterDays = days.clamp(3, 90);
    _save((s) => s.setSetting('reviewAfterDays', '$reviewAfterDays'));
    notifyListeners();
  }

  // --------------------------------------------------------- dados de exemplo

  /// Carrega os dados de exemplo (só com o app vazio) e grava no banco.
  void loadSampleData() {
    if (tasks.isNotEmpty || notes.isNotEmpty || dates.isNotEmpty || entries.isNotEmpty) return;
    _seed();
    for (final t in tasks) {
      _saveTask(t);
    }
    for (final e in history) {
      _save((s) => s.addHistory(e));
    }
    for (final n in notes) {
      _saveNote(n);
    }
    for (final d in dates) {
      _save((s) => s.upsertDate(d));
    }
    for (final e in entries) {
      _save((s) => s.upsertEntry(e));
    }
    replan();
    notifyListeners();
  }


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

    dates.addAll([
      SpecialDate(
        id: newId('d'),
        title: 'Aniversário da mãe',
        kind: DateKind.birthday,
        month: n.month,
        day: n.day,
        year: 1968,
        createdAt: n,
      ),
      SpecialDate(
        id: newId('d'),
        title: 'Dia do estágio',
        kind: DateKind.date,
        month: (n.month % 12) + 1,
        day: 10,
        createdAt: n,
      ),
    ]);

    for (var i = 0; i < 5; i++) {
      addEntryRaw(kModWater, n.subtract(Duration(minutes: 40 * i)), {'ml': 200});
    }
    addEntryRaw(kModFood, n.subtract(const Duration(hours: 3)),
        {'meal': 'almoco', 'text': 'Arroz, feijão, frango e salada'});
    addEntryRaw(kModExercise, ago(2),
        {'kind': 'Caminhada', 'minutes': 40, 'notes': ''});
    addEntryRaw(kModBook, ago(20), {
      'title': 'Hábitos Atômicos',
      'author': 'James Clear',
      'total': 320,
      'page': 120,
      'status': 'lendo',
    });
  }

  /// Só para os dados de exemplo (não grava; loadSampleData grava depois).
  void addEntryRaw(String module, DateTime at, Map<String, Object?> data) {
    entries.add(Entry(id: newId('e'), module: module, at: at, data: data, createdAt: at));
  }
}
