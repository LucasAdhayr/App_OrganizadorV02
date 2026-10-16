import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/special_dates.dart';
import '../actions.dart';
import '../term_widgets.dart';

/// Cria ou edita um aniversário / data que se repete todo ano.
class DateFormScreen extends StatefulWidget {
  const DateFormScreen({super.key, this.edit});

  final SpecialDate? edit;

  @override
  State<DateFormScreen> createState() => _DateFormScreenState();
}

class _DateFormScreenState extends State<DateFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateKind _kind;
  int? _month;
  int? _day;
  int? _year;
  bool _keepYear = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.edit;
    _title = TextEditingController(text: d?.title ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _kind = d?.kind ?? DateKind.birthday;
    _month = d?.month;
    _day = d?.day;
    _year = d?.year;
    _keepYear = d == null ? true : d.year != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = AppScope.read(context).now;
    // 2000 é bissexto: dá para escolher 29/02 quando não se sabe o ano.
    final initial = DateTime(_year ?? (_keepYear ? now.year - 30 : 2000), _month ?? now.month,
        _day ?? now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: _keepYear ? 'Dia, mês e ano' : 'Dia e mês (o ano é ignorado)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = picked.month;
      _day = picked.day;
      _year = picked.year;
      _error = null;
    });
  }

  String _dateText() {
    if (_month == null || _day == null) return 'Escolher data';
    final base = '${two(_day!)}/${two(_month!)}';
    return _keepYear && _year != null ? '$base/$_year' : base;
  }

  void _save() {
    final s = AppScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Dê um nome.');
      return;
    }
    if (_month == null || _day == null) {
      setState(() => _error = 'Escolha a data.');
      return;
    }
    final year = _keepYear ? _year : null;
    final existing = widget.edit;
    if (existing == null) {
      s.saveDate(
        SpecialDate(
          id: s.newId('d'),
          title: title,
          kind: _kind,
          month: _month!,
          day: _day!,
          year: year,
          notes: _notes.text.trim(),
          createdAt: s.now,
        ),
        isNew: true,
      );
    } else {
      existing
        ..title = title
        ..kind = _kind
        ..month = _month!
        ..day = _day!
        ..year = year
        ..notes = _notes.text.trim();
      s.saveDate(existing, isNew: false);
    }
    nav.pop();
    toast(messenger, s.palette, existing == null ? 'Data salva.' : 'Alterações salvas.');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final editing = widget.edit != null;
    final dim = TextStyle(color: p.dim, fontSize: 12);

    return TermScaffold(
      title: editing ? 'Editar data' : 'Nova data',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('! $_error', style: TextStyle(color: p.warn, fontSize: 13)),
              ),
            TermButton(
              label: editing ? 'Salvar alterações' : 'Salvar',
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
          const FieldLabel('Nome'),
          TextField(
            controller: _title,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            style: const TextStyle(fontSize: 15),
            cursorColor: p.fg,
            decoration: termInput(context, hint: 'Ex.: Aniversário da Ana'),
          ),
          const FieldLabel('Tipo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in DateKind.values)
                TermButton(
                  label: k.label,
                  dense: true,
                  selected: _kind == k,
                  onPressed: () => setState(() => _kind = k),
                ),
            ],
          ),
          const FieldLabel('Data'),
          TermButton(
            label: _dateText(),
            icon: Icons.event,
            expand: true,
            onPressed: _pickDate,
          ),
          const SizedBox(height: 8),
          TermButton(
            label: _keepYear ? 'Guardar o ano: SIM' : 'Guardar o ano: NÃO',
            dense: true,
            selected: _keepYear,
            onPressed: () => setState(() => _keepYear = !_keepYear),
          ),
          const SizedBox(height: 4),
          Text(
            'Com o ano, o app mostra a idade ("faz 30 anos"). A data se repete '
            'todo ano e avisa na véspera e no dia, às 09:00.',
            style: dim,
          ),
          const FieldLabel('Notas (opcional)'),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15),
            cursorColor: p.fg,
            decoration: termInput(context, hint: 'Ex.: ideia de presente'),
          ),
        ],
      ),
    );
  }
}
