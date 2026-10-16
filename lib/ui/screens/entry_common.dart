import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/entry.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';

// Peças comuns dos módulos simples (alimentação, exercícios, livros...).

String dayLabel(DateTime at, DateTime now) {
  final diff = daysBetween(dateOnly(at), dateOnly(now));
  if (diff == 0) return 'HOJE';
  if (diff == 1) return 'ONTEM';
  return fmtDateShort(at);
}

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// Primeiro dia (segunda-feira) da semana de [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Escolhe data e hora (não aceita o futuro). null se desistir.
Future<DateTime?> pickPastDateTime(BuildContext context, DateTime initial) async {
  final now = AppScope.read(context).now;
  final date = await showDatePicker(
    context: context,
    initialDate: dateOnly(initial),
    firstDate: DateTime(2020),
    lastDate: dateOnly(now),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
  );
  if (time == null) return null;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (at.isAfter(now)) {
    if (context.mounted) showToast(context, 'Esse horário ainda não chegou.');
    return null;
  }
  return at;
}

/// Botão que mostra data/hora e deixa trocar.
class WhenButton extends StatelessWidget {
  const WhenButton({super.key, required this.when, required this.onChanged});

  final DateTime when;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = AppScope.read(context).now;
    return TermButton(
      label: '${dayLabel(when, now)} ${hm(when)}',
      icon: Icons.schedule,
      expand: true,
      onPressed: () async {
        final picked = await pickPastDateTime(context, when);
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Folha de um registro: informações no topo, Editar e Apagar (com desfazer).
void showEntryActions(
  BuildContext host,
  Entry e, {
  required String title,
  List<Widget> top = const <Widget>[],
  List<Widget> extra = const <Widget>[],
  required VoidCallback onEdit,
  String deletedMessage = 'Registro apagado.',
}) {
  showTermSheet<void>(host, (c) {
    final s = AppScope.of(c);
    return SheetFrame(
      title: title,
      children: [
        ...top,
        gap(12),
        ...extra,
        TermButton(
          label: 'Editar',
          icon: Icons.edit_outlined,
          expand: true,
          onPressed: () {
            Navigator.of(c).pop();
            onEdit();
          },
        ),
        gap(),
        TermButton(
          label: 'Apagar',
          expand: true,
          danger: true,
          onPressed: () {
            final messenger = ScaffoldMessenger.of(host);
            final index = s.removeEntry(e);
            Navigator.of(c).pop();
            toast(messenger, s.palette, deletedMessage,
                onUndo: () => s.insertEntry(index, e));
          },
        ),
      ],
    );
  });
}

/// Mensagem de lista vazia no estilo do app.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.title, this.subtitle, {super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const WireGlobe(size: 110),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: p.fg, fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: p.dim, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
