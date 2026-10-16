import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../core/special_dates.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'date_form_screen.dart';

/// "HOJE", "AMANHÃ" ou "EM 12D" para uma data que se repete.
String untilLabel(SpecialDate d, DateTime now) {
  final days = daysBetween(dateOnly(now), d.next(now));
  if (days == 0) return 'HOJE';
  if (days == 1) return 'AMANHÃ';
  if (days <= 30) return 'EM ${days}D';
  return '${two(d.day)}/${two(d.month)}';
}

/// Ficha da data: editar ou apagar (com desfazer).
void showDateDetail(BuildContext host, SpecialDate d) {
  showTermSheet<void>(host, (c) {
    final s = AppScope.of(c);
    final p = s.palette;
    final next = d.next(s.now);
    return SheetFrame(
      title: d.title,
      children: [
        Text(
          '${d.kind.label} · ${d.describe(s.now)}',
          style: TextStyle(color: p.fg, fontSize: 14),
        ),
        gap(4),
        Text(
          'Próxima: ${fmtDateShort(next)} (${untilLabel(d, s.now).toLowerCase()})',
          style: TextStyle(color: p.dim, fontSize: 13),
        ),
        if (d.notes.isNotEmpty) ...[
          gap(8),
          SelectableText(d.notes, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
        gap(16),
        TermButton(
          label: 'Editar',
          icon: Icons.edit_outlined,
          expand: true,
          primary: true,
          onPressed: () {
            Navigator.of(c).pop();
            Navigator.of(host).push<void>(
              MaterialPageRoute<void>(builder: (_) => DateFormScreen(edit: d)),
            );
          },
        ),
        gap(),
        TermButton(
          label: 'Apagar',
          expand: true,
          danger: true,
          onPressed: () {
            final messenger = ScaffoldMessenger.of(host);
            final index = s.removeDate(d);
            Navigator.of(c).pop();
            toast(messenger, s.palette, 'Data apagada.', onUndo: () => s.insertDate(index, d));
          },
        ),
      ],
    );
  });
}

/// Linha de uma data (usada aqui e na tela HOJE).
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.date});

  final SpecialDate date;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final soon = daysBetween(dateOnly(s.now), date.next(s.now)) <= 1;
    return TermRow(
      title: date.title,
      subtitle: '${fmtDateShort(date.next(s.now))} · ${date.describe(s.now)}',
      leading: SizedBox(
        width: 32,
        child: Icon(
          date.kind == DateKind.birthday ? Icons.cake_outlined : Icons.event,
          size: 20,
          color: soon ? s.palette.fg : s.palette.dim,
        ),
      ),
      trailing: untilLabel(date, s.now),
      onTap: () => showDateDetail(context, date),
    );
  }
}

/// Módulo ANIVERSÁRIOS: todas as datas, da mais próxima para a mais distante.
class DatesScreen extends StatelessWidget {
  const DatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final list = s.datesByNext();

    return TermScaffold(
      title: 'Aniversários e datas',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Nova data',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const DateFormScreen()),
          ),
        ),
      ),
      body: list.isEmpty
          ? const EmptyState(
              title: '> Nenhuma data guardada.',
              subtitle: 'Aniversários e datas que se repetem todo ano.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final d in list) DateRow(key: ValueKey('date-${d.id}-${d.title}'), date: d),
              ],
            ),
    );
  }
}
