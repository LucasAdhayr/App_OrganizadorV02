import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/entry.dart';
import '../../core/models.dart';
import '../actions.dart';
import '../term_widgets.dart';

/// Formulário de tarefa (nova ou edição). Ao salvar, devolve a [Task]
/// para quem abriu a tela (usado pela ENTRADA para marcar "virou tarefa").
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    this.edit,
    this.initialTitle,
    this.initialNotes,
    this.module,
  });

  /// Módulo que será dono da tarefa (ex.: `exercicios`). Com módulo, a tarefa
  /// é sempre uma rotina que se repete e precisa de horário.
  final String? module;

  final Task? edit;
  final String? initialTitle;
  final String? initialNotes;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _interval;
  late final TextEditingController _monthDay;
  late final TextEditingController _month;
  late TaskKind _kind;
  String? get _module => widget.edit?.module ?? widget.module;
  String get _moduleLabel => _module == kModExercise ? 'Exercício' : 'Rotina';
  late RecurrenceType _rtype;
  late Set<int> _weekdays;
  DateTime? _due;
  TimeOfDay? _time;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.edit;
    final r = t?.recurrence;
    _title = TextEditingController(text: t?.title ?? widget.initialTitle ?? '');
    _notes = TextEditingController(text: t?.notes ?? widget.initialNotes ?? '');
    _interval = TextEditingController(text: '${r?.interval ?? 2}');
    _monthDay = TextEditingController(text: '${r?.dayOfMonth ?? 1}');
    _month = TextEditingController(text: '${r?.month ?? 1}');
    _kind = (t?.module ?? widget.module) != null
        ? TaskKind.recurring
        : (t?.kind ?? TaskKind.single);
    _rtype = r?.type ?? RecurrenceType.daily;
    _weekdays = Set<int>.of(r?.weekdays ?? const <int>{});
    _due = (t != null && t.kind == TaskKind.single) ? t.dueDate : null;
    _time = (t != null && t.kind == TaskKind.single) ? t.dueTime : t?.time;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _interval.dispose();
    _monthDay.dispose();
    _month.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- ajudantes

  Widget _choices(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: TextStyle(color: context.pal.dim, fontSize: 12)),
      );

  Widget _numberField(TextEditingController c) => SizedBox(
        width: 72,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
          cursorColor: context.pal.fg,
          decoration: termInput(context),
        ),
      );

  Widget _inlineLabel(String text) => Text(
        text,
        style: TextStyle(color: context.pal.dim, fontSize: 13, letterSpacing: 1),
      );

  String _kindHint(TaskKind k) => switch (k) {
        TaskKind.recurring => 'Repete em dias fixos. Cada ocorrência tem o seu próprio estado.',
        TaskKind.single => 'Acontece uma vez. Pode ter prazo ou não.',
        TaskKind.reusable =>
          'Sem data. Marque quando fizer e reabra quando precisar de novo.',
      };

  // -------------------------------------------------------------------- datas

  Future<void> _pickDate(DateTime today) async {
    final first = DateTime(today.year - 1, today.month, today.day);
    var initial = _due ?? today;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked != null && mounted) setState(() => _due = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Widget _dueSection(DateTime today) {
    bool isDay(int offset) =>
        _due != null &&
        sameDay(_due!, DateTime(today.year, today.month, today.day + offset));
    final custom = _due != null && !isDay(0) && !isDay(1) && !isDay(7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Prazo'),
        _choices([
          TermButton(
            label: 'Sem prazo',
            dense: true,
            selected: _due == null,
            onPressed: () => setState(() {
              _due = null;
              _time = null;
            }),
          ),
          TermButton(
            label: 'Hoje',
            dense: true,
            selected: isDay(0),
            onPressed: () => setState(() => _due = today),
          ),
          TermButton(
            label: 'Amanhã',
            dense: true,
            selected: isDay(1),
            onPressed: () =>
                setState(() => _due = DateTime(today.year, today.month, today.day + 1)),
          ),
          TermButton(
            label: 'Em 7 dias',
            dense: true,
            selected: isDay(7),
            onPressed: () =>
                setState(() => _due = DateTime(today.year, today.month, today.day + 7)),
          ),
          TermButton(
            label: 'Escolher data',
            icon: Icons.event,
            dense: true,
            selected: custom,
            onPressed: () => _pickDate(today),
          ),
        ]),
        if (_due != null) _hint('> ${fmtDateShort(_due!)}'),
      ],
    );
  }

  Widget _timeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Horário'),
        _choices([
          if (_module == null)
            TermButton(
              label: 'Sem horário',
              dense: true,
              selected: _time == null,
              onPressed: () => setState(() => _time = null),
            ),
          TermButton(
            label: _time == null ? 'Escolher horário' : fmtTime(_time!),
            icon: Icons.schedule,
            dense: true,
            selected: _time != null,
            onPressed: _pickTime,
          ),
        ]),
      ],
    );
  }

  // --------------------------------------------------------------- recorrência

  Widget _recurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Repetição'),
        _choices([
          for (final r in RecurrenceType.values)
            TermButton(
              label: r.label,
              dense: true,
              selected: _rtype == r,
              onPressed: () => setState(() => _rtype = r),
            ),
        ]),
        const SizedBox(height: 12),
        _recurrenceDetail(),
      ],
    );
  }

  Widget _recurrenceDetail() {
    switch (_rtype) {
      case RecurrenceType.daily:
        return _hint('Aparece todos os dias.');
      case RecurrenceType.weekdays:
        return _choices([
          for (var d = 1; d <= 7; d++)
            TermButton(
              label: weekdayShort(d),
              dense: true,
              selected: _weekdays.contains(d),
              onPressed: () => setState(() {
                if (!_weekdays.remove(d)) _weekdays.add(d);
              }),
            ),
        ]);
      case RecurrenceType.everyNDays:
        return Row(
          children: [
            _inlineLabel('A CADA'),
            const SizedBox(width: 10),
            _numberField(_interval),
            const SizedBox(width: 10),
            _inlineLabel('DIAS'),
          ],
        );
      case RecurrenceType.monthDay:
        return Row(
          children: [
            _inlineLabel('TODO MÊS, DIA'),
            const SizedBox(width: 10),
            _numberField(_monthDay),
          ],
        );
      case RecurrenceType.yearly:
        return Row(
          children: [
            _inlineLabel('DIA'),
            const SizedBox(width: 10),
            _numberField(_monthDay),
            const SizedBox(width: 16),
            _inlineLabel('MÊS'),
            const SizedBox(width: 10),
            _numberField(_month),
          ],
        );
    }
  }

  /// Monta a regra a partir dos campos. Em caso de erro, mostra a mensagem
  /// e devolve null.
  Recurrence? _buildRule() {
    Recurrence? fail(String message) {
      setState(() => _error = message);
      return null;
    }

    switch (_rtype) {
      case RecurrenceType.daily:
        return const Recurrence(type: RecurrenceType.daily);
      case RecurrenceType.weekdays:
        if (_weekdays.isEmpty) return fail('Escolha ao menos um dia da semana.');
        return Recurrence(
          type: RecurrenceType.weekdays,
          weekdays: Set<int>.of(_weekdays),
        );
      case RecurrenceType.everyNDays:
        final n = int.tryParse(_interval.text) ?? 0;
        if (n < 1) return fail('Informe de quantos em quantos dias (1 ou mais).');
        return Recurrence(type: RecurrenceType.everyNDays, interval: n);
      case RecurrenceType.monthDay:
        final d = int.tryParse(_monthDay.text) ?? 0;
        if (d < 1 || d > 31) return fail('O dia do mês deve estar entre 1 e 31.');
        return Recurrence(type: RecurrenceType.monthDay, dayOfMonth: d);
      case RecurrenceType.yearly:
        final d = int.tryParse(_monthDay.text) ?? 0;
        final m = int.tryParse(_month.text) ?? 0;
        if (d < 1 || d > 31) return fail('O dia deve estar entre 1 e 31.');
        if (m < 1 || m > 12) return fail('O mês deve estar entre 1 e 12.');
        return Recurrence(type: RecurrenceType.yearly, dayOfMonth: d, month: m);
    }
  }

  // ------------------------------------------------------------------- salvar

  void _save() {
    setState(() => _error = null);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Dê um título à tarefa.');
      return;
    }

    Recurrence? rule;
    if (_kind == TaskKind.recurring) {
      rule = _buildRule();
      if (rule == null) return;
    }
    if (_module != null && _time == null) {
      setState(() => _error = 'Escolha o horário (o aviso chega 1 hora antes).');
      return;
    }

    final s = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final existing = widget.edit;
    final now = s.now;
    final today = dateOnly(now);

    DateTime? due;
    TimeOfDay? time;
    switch (_kind) {
      case TaskKind.recurring:
        {
          final r = rule!;
          final old = existing?.recurrence;
          final sameRule = old != null && old.type == r.type && old.label == r.label;
          // Regra igual: mantém a próxima ocorrência. Regra nova: recalcula.
          due = (sameRule && existing!.due != null)
              ? existing.due
              : r.firstOnOrAfter(today);
          time = _time;
        }
      case TaskKind.single:
        due = _due;
        time = _due == null ? null : _time;
      case TaskKind.reusable:
        due = null;
        time = null;
    }

    final notes = _notes.text.trim();
    final Task result;
    if (existing == null) {
      result = Task(
        id: s.newId('t'),
        title: title,
        kind: _kind,
        createdAt: now,
        due: due,
        time: time,
        recurrence: rule,
        notes: notes,
        module: widget.module,
      );
      s.saveTask(result, isNew: true);
    } else {
      // Mudar data ou horário na edição vale mais que um adiamento anterior.
      final moved = existing.due != due || existing.time != time;
      if (moved) existing.snoozedUntil = null;
      existing
        ..title = title
        ..kind = _kind
        ..due = due
        ..time = time
        ..recurrence = rule
        ..notes = notes;
      result = existing;
      s.saveTask(existing, isNew: false);
    }

    nav.pop(result);
    toast(messenger, s.palette, existing == null ? 'Tarefa criada.' : 'Alterações salvas.');
  }

  // -------------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final editing = widget.edit != null;
    final today = dateOnly(s.now);
    final showTime = _kind == TaskKind.recurring ||
        (_kind == TaskKind.single && _due != null);

    return TermScaffold(
      title: _module != null
          ? (editing ? 'Editar rotina' : 'Nova rotina')
          : (editing ? 'Editar tarefa' : 'Nova tarefa'),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '! $_error',
                  style: TextStyle(color: p.warn, fontSize: 13),
                ),
              ),
            TermButton(
              label: editing ? 'Salvar alterações' : 'Salvar tarefa',
              expand: true,
              primary: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FieldLabel(_module != null ? _moduleLabel : 'Título'),
          TextField(
            controller: _title,
            autofocus: !editing && widget.initialTitle == null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 120,
            style: const TextStyle(fontSize: 15),
            cursorColor: p.fg,
            decoration: termInput(
              context,
              hint: _module != null ? 'Ex.: Musculação' : 'O que precisa ser feito?',
            ),
          ),
          if (_module == null) ...[
            const FieldLabel('Tipo'),
            _choices([
              for (final k in TaskKind.values)
                TermButton(
                  label: k.label,
                  dense: true,
                  selected: _kind == k,
                  onPressed: () => setState(() => _kind = k),
                ),
            ]),
            _hint(_kindHint(_kind)),
          ] else
            _hint('Repete sozinha e aparece em HOJE e AGENDA. Ao concluir, registra o treino.'),
          if (_kind == TaskKind.single) _dueSection(today),
          if (_kind == TaskKind.recurring) _recurrenceSection(),
          if (showTime) _timeSection(),
          const FieldLabel('Notas (opcional)'),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15),
            cursorColor: p.fg,
            decoration: termInput(context),
          ),
        ],
      ),
    );
  }
}
