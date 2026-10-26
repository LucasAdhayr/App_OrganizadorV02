import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../../core/labels.dart';
import '../../core/money.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';
import 'task_form_screen.dart';

const List<String> _months = [
  'JANEIRO',
  'FEVEREIRO',
  'MARÇO',
  'ABRIL',
  'MAIO',
  'JUNHO',
  'JULHO',
  'AGOSTO',
  'SETEMBRO',
  'OUTUBRO',
  'NOVEMBRO',
  'DEZEMBRO',
];

String _monthName(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// Registra um gasto (ou edita [edit]).
Future<void> showExpenseSheet(BuildContext host, {Entry? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final amount = TextEditingController(
    text: edit == null ? '' : fmtMoney(edit.number('cents') ?? 0).replaceFirst('R\$ ', ''),
  );
  final desc = TextEditingController(text: edit?.text('desc') ?? '');
  var cat = edit == null || edit.text('cat').isEmpty ? kExpenseCategories.first : edit.text('cat');
  var when = edit?.at ?? s.now;
  String? error;
  final cats = <String>[
    ...kExpenseCategories,
    if (!kExpenseCategories.contains(cat)) cat,
  ];

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        void save() {
          final cents = parseMoney(amount.text);
          if (cents == null || cents <= 0) {
            setSheet(() => error = 'Informe o valor. Exemplo: 25,90');
            return;
          }
          final text = desc.text.trim();
          final data = <String, Object?>{
            'desc': text.isEmpty ? cat : text,
            'cents': cents,
            'cat': cat,
            if (edit != null && edit.data['bill'] != null) 'bill': edit.data['bill'],
          };
          if (edit == null) {
            s.addEntry(kModFinance, at: when, data: data);
          } else {
            s.updateEntry(edit, at: when, data: data);
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Gasto registrado.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'Novo gasto' : 'Editar gasto',
          children: [
            TextField(
              controller: amount,
              autofocus: edit == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              style: const TextStyle(fontSize: 18),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Valor (R\$)'),
            ),
            gap(8),
            TextField(
              controller: desc,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Descrição (opcional)'),
            ),
            const FieldLabel('Categoria'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in cats)
                  TermButton(
                    label: k,
                    dense: true,
                    selected: cat == k,
                    onPressed: () => setSheet(() => cat = k),
                  ),
              ],
            ),
            gap(12),
            WhenButton(when: when, onChanged: (v) => setSheet(() => when = v)),
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

Future<void> newBill(BuildContext context) => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TaskFormScreen(module: kModFinance)),
    );

/// "+" > FINANÇAS: conta a pagar (com vencimento) ou gasto já feito.
Future<void> addFinanceChoice(BuildContext context) async {
  final choice = await showTermSheet<String>(
    context,
    (c) => SheetFrame(
      title: 'Finanças',
      children: [
        TermButton(
          label: 'Nova conta a pagar',
          icon: Icons.event_note_outlined,
          expand: true,
          primary: true,
          onPressed: () => Navigator.of(c).pop('bill'),
        ),
        gap(),
        TermButton(
          label: 'Registrar gasto',
          icon: Icons.payments_outlined,
          expand: true,
          onPressed: () => Navigator.of(c).pop('expense'),
        ),
        gap(),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'bill') {
    await newBill(context);
  } else {
    await showExpenseSheet(context);
  }
}

/// FINANÇAS: contas a pagar com vencimento e o que foi gasto no mês.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final now = s.now;
    final bills = s.bills;
    final month = s.expensesIn(now);
    final spent = s.totalCents(month);
    final toPay = s.billsDueCents(now);
    final cats = s.byCategory(month);

    // Meses anteriores com movimento (até 3).
    final past = <(DateTime, int)>[];
    for (var i = 1; i <= 6 && past.length < 3; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final total = s.totalCents(s.expensesIn(d));
      if (total > 0) past.add((d, total));
    }

    final empty = bills.isEmpty && s.expenses.isEmpty;

    return TermScaffold(
      title: 'Finanças',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TermButton(
                label: 'Gasto',
                icon: Icons.payments_outlined,
                dense: true,
                expand: true,
                onPressed: () => showExpenseSheet(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TermButton(
                label: 'Nova conta',
                icon: Icons.add,
                expand: true,
                primary: true,
                onPressed: () => newBill(context),
              ),
            ),
          ],
        ),
      ),
      body: empty
          ? const EmptyHint(
              '> Nada em finanças ainda.',
              'Cadastre contas a pagar com vencimento e registre seus gastos.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(_monthName(now),
                    style: TextStyle(color: p.dim, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text('GASTO  ${fmtMoney(spent)}',
                    style: TextStyle(color: p.fg, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  toPay > 0
                      ? 'Falta pagar até o fim do mês: ${fmtMoney(toPay)}'
                      : 'Nenhuma conta com valor pendente neste mês.',
                  style: TextStyle(color: p.dim, fontSize: 13),
                ),
                if (bills.isNotEmpty) ...[
                  SectionHeader('CONTAS A PAGAR', count: bills.length),
                  for (final t in bills)
                    TermRow(
                      key: ValueKey('bill-${t.id}-${t.due}-${t.snoozedUntil}-${t.amountCents}'),
                      title: t.title,
                      subtitle: [
                        if (t.amountCents != null) fmtMoney(t.amountCents!),
                        if (t.recurrence != null) t.recurrence!.label,
                        if (t.alarm) 'ALARME',
                      ].join(' · '),
                      trailing: dueLabel(t, now).text,
                      trailingColor: dueLabel(t, now).overdue ? p.warn : null,
                      onTap: () => showTaskDetail(context, t),
                    ),
                ],
                if (cats.isNotEmpty) ...[
                  const SectionHeader('POR CATEGORIA'),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(c.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.dim, fontSize: 13)),
                          ),
                          BlockBar(value: spent == 0 ? 0 : c.value / spent, cells: 8),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(fmtMoney(c.value),
                                style: TextStyle(color: p.fg, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                ],
                if (month.isNotEmpty) ...[
                  const SectionHeader('LANÇAMENTOS DO MÊS'),
                  for (final e in month)
                    TermRow(
                      key: ValueKey('fin-${e.id}-${e.updatedAt.millisecondsSinceEpoch}'),
                      title: e.text('desc').isEmpty ? e.text('cat') : e.text('desc'),
                      subtitle: '${e.text('cat')} · ${dayLabel(e.at, now)} ${hm(e.at)}',
                      trailing: fmtMoney(e.number('cents') ?? 0),
                      onTap: () => showEntryActions(
                        context,
                        e,
                        title: e.text('desc').isEmpty ? e.text('cat') : e.text('desc'),
                        top: [
                          Text(fmtMoney(e.number('cents') ?? 0),
                              style: TextStyle(color: p.fg, fontSize: 18)),
                          gap(4),
                          Text('${e.text('cat')} · ${dayLabel(e.at, now)} ${hm(e.at)}',
                              style: TextStyle(color: p.dim, fontSize: 13)),
                        ],
                        onEdit: () => showExpenseSheet(context, edit: e),
                        deletedMessage: 'Lançamento apagado.',
                      ),
                    ),
                ],
                if (past.isNotEmpty) ...[
                  const SectionHeader('MESES ANTERIORES'),
                  for (final (d, total) in past)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_monthName(d),
                                style: TextStyle(color: p.dim, fontSize: 13)),
                          ),
                          Text(fmtMoney(total), style: TextStyle(color: p.fg, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
