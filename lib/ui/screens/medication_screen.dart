import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/medication.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

String _timesText(Medication m) => m.times.isEmpty ? '--' : m.times.map(fmtTime).join('  ');

String _doseText(Medication m) {
  final n = m.perDose;
  final day = m.perDay;
  return '$n ${n == 1 ? 'unidade' : 'unidades'} por vez · $day por dia';
}

/// Cadastra um remédio (ou edita [edit]). Todo remédio toca alarme.
Future<void> showMedicationSheet(BuildContext host, {Medication? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final name = TextEditingController(text: edit?.name ?? '');
  final perDose = TextEditingController(text: '${edit?.perDose ?? 1}');
  final stock = TextEditingController();
  final times = <TimeOfDay>[...?edit?.times];
  String? error;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        Future<void> addTime() async {
          final picked = await showTimePicker(
            context: c,
            initialTime: const TimeOfDay(hour: 8, minute: 0),
          );
          if (picked == null) return;
          final key = picked.hour * 60 + picked.minute;
          if (times.every((t) => t.hour * 60 + t.minute != key)) {
            setSheet(() {
              times.add(picked);
              times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
              error = null;
            });
          }
        }

        void save() {
          final n = name.text.trim();
          final dose = int.tryParse(perDose.text.trim()) ?? 0;
          if (n.isEmpty) return setSheet(() => error = 'Dê um nome ao remédio.');
          if (times.isEmpty) return setSheet(() => error = 'Adicione ao menos um horário.');
          if (dose < 1) return setSheet(() => error = 'Informe quantas unidades por vez.');
          if (edit == null) {
            final units = int.tryParse(stock.text.trim()) ?? 0;
            s.addMedication(name: n, times: times, perDose: dose, stock: units);
          } else {
            s.editMedication(edit, name: n, times: times, perDose: dose);
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Remédio adicionado.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'Novo remédio' : 'Editar remédio',
          children: [
            TextField(
              controller: name,
              autofocus: edit == null,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Nome do remédio'),
            ),
            const FieldLabel('Horários'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in times)
                  TermButton(
                    label: fmtTime(t),
                    icon: Icons.close,
                    dense: true,
                    selected: true,
                    onPressed: () => setSheet(() => times.remove(t)),
                  ),
                TermButton(
                  label: 'Adicionar horário',
                  icon: Icons.add,
                  dense: true,
                  onPressed: addTime,
                ),
              ],
            ),
            const FieldLabel('Unidades por vez'),
            TextField(
              controller: perDose,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Ex.: 1'),
            ),
            if (edit == null) ...[
              const FieldLabel('Quantas unidades você tem agora'),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 15),
                cursorColor: s.palette.fg,
                decoration: termInput(c, hint: 'Ex.: 30'),
              ),
            ],
            gap(8),
            Text(
              'Toca alarme em todos os horários. O estoque desce sozinho a cada '
              'horário que passa.',
              style: TextStyle(color: s.palette.dim, fontSize: 12, height: 1.4),
            ),
            if (error != null) ...[
              gap(8),
              Text('! $error', style: TextStyle(color: s.palette.warn, fontSize: 13)),
            ],
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

/// Pergunta um número e devolve para [onSave].
Future<void> _numberSheet(
  BuildContext host, {
  required String title,
  required String hint,
  String initial = '',
  required void Function(int value) onSave,
}) {
  final s = AppScope.read(host);
  final field = TextEditingController(text: initial);
  return showTermSheet<void>(host, (c) {
    void save() {
      final v = int.tryParse(field.text.trim());
      if (v == null || v < 0) return;
      onSave(v);
      Navigator.of(c).pop();
    }

    return SheetFrame(
      title: title,
      children: [
        TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18),
          cursorColor: s.palette.fg,
          decoration: termInput(c, hint: hint),
        ),
        gap(12),
        TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
      ],
    );
  });
}

void _openMedication(BuildContext context, Medication med) {
  final s = AppScope.read(context);
  final p = s.palette;
  final m = ScaffoldMessenger.of(context);

  showEntryActions(
    context,
    med.entry,
    title: med.name,
    top: [
      Text('HORÁRIOS  ${_timesText(med)}', style: TextStyle(color: p.fg, fontSize: 14)),
      gap(4),
      Text(_doseText(med), style: TextStyle(color: p.dim, fontSize: 13)),
      gap(4),
      Text(med.stockText(s.now), style: TextStyle(color: p.fg, fontSize: 14)),
    ],
    extra: [
      if (med.active) ...[
        TermButton(
          label: 'Adicionar estoque',
          icon: Icons.add_box_outlined,
          expand: true,
          primary: true,
          onPressed: () {
            Navigator.of(context).pop();
            _numberSheet(
              context,
              title: 'Quantas unidades chegaram?',
              hint: 'Unidades',
              onSave: (v) {
                if (v == 0) return;
                s.addMedicationStock(med, v);
                toast(m, s.palette, '+$v un. no estoque.');
              },
            );
          },
        ),
        gap(),
        TermButton(
          label: 'Corrigir contagem',
          expand: true,
          onPressed: () {
            Navigator.of(context).pop();
            _numberSheet(
              context,
              title: 'Quantas unidades você tem agora?',
              hint: 'Unidades',
              initial: '${med.remaining(s.now)}',
              onSave: (v) {
                s.setMedicationStock(med, v);
                toast(m, s.palette, 'Contagem corrigida.');
              },
            );
          },
        ),
        gap(),
        TermButton(
          label: 'Parei de tomar',
          expand: true,
          onPressed: () {
            s.stopMedication(med);
            Navigator.of(context).pop();
            toast(m, s.palette, 'Alarmes desligados.', onUndo: () => s.resumeMedication(med));
          },
        ),
        gap(),
      ] else ...[
        TermButton(
          label: 'Voltar a tomar',
          icon: Icons.replay,
          expand: true,
          primary: true,
          onPressed: () {
            s.resumeMedication(med);
            Navigator.of(context).pop();
            toast(m, s.palette, 'Alarmes ligados de novo.');
          },
        ),
        gap(),
      ],
    ],
    onEdit: () => showMedicationSheet(context, edit: med),
    deletedMessage: 'Remédio apagado.',
  );
}

/// MEDICAMENTOS: horários, estoque e o dia em que cada um acaba.
class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = s.now;
    final all = s.medications;
    final active = all.where((m) => m.active).toList();
    final stopped = all.where((m) => !m.active).toList();

    Widget row(Medication m) => TermRow(
          key: ValueKey('med-${m.id}-${m.entry.updatedAt.millisecondsSinceEpoch}'),
          title: m.name,
          subtitle: m.active
              ? '${_timesText(m)} · ${m.perDose} por vez\n${m.stockText(now)}'
              : 'PARADO',
          trailing: m.isLow(now) ? '[!]' : null,
          onTap: () => _openMedication(context, m),
        );

    return TermScaffold(
      title: 'Medicamentos',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Novo remédio',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => showMedicationSheet(context),
        ),
      ),
      body: all.isEmpty
          ? const EmptyHint('> Nenhum remédio ainda.', 'Cadastre horários e estoque. Todo remédio toca alarme.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (active.isNotEmpty) ...[
                  SectionHeader('TOMANDO', count: active.length),
                  for (final m in active) row(m),
                ],
                if (stopped.isNotEmpty) ...[
                  SectionHeader('PARADOS', count: stopped.length),
                  for (final m in stopped) row(m),
                ],
              ],
            ),
    );
  }
}
