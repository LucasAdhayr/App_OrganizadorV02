import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../../core/labels.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

const Map<String, String> _meals = {
  'cafe': 'CAFÉ',
  'almoco': 'ALMOÇO',
  'lanche': 'LANCHE',
  'jantar': 'JANTAR',
  'outro': 'OUTRO',
};

String _guessMeal(DateTime now) {
  if (now.hour < 10) return 'cafe';
  if (now.hour < 15) return 'almoco';
  if (now.hour < 18) return 'lanche';
  return 'jantar';
}

/// Anota uma refeição (ou edita [edit]). Sem calorias: é um bloco de notas.
Future<void> showMealSheet(BuildContext host, {Entry? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final text = TextEditingController(text: edit?.text('text') ?? '');
  var meal = edit?.text('meal').isNotEmpty == true ? edit!.text('meal') : _guessMeal(s.now);
  var when = edit?.at ?? s.now;

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        void save() {
          final t = text.text.trim();
          if (t.isEmpty) return;
          final data = <String, Object?>{'meal': meal, 'text': t};
          if (edit == null) {
            s.addEntry(kModFood, at: when, data: data);
          } else {
            s.updateEntry(edit, at: when, data: data);
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Refeição anotada.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'O que você comeu?' : 'Editar refeição',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _meals.entries)
                  TermButton(
                    label: e.value,
                    dense: true,
                    selected: meal == e.key,
                    onPressed: () => setSheet(() => meal = e.key),
                  ),
              ],
            ),
            gap(12),
            TextField(
              controller: text,
              autofocus: edit == null,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Ex.: arroz, feijão, frango e salada'),
            ),
            gap(12),
            WhenButton(when: when, onChanged: (v) => setSheet(() => when = v)),
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

/// ALIMENTAÇÃO: bloco de notas do que você comeu, por dia.
class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = s.now;
    final list = s.entriesOf(kModFood);

    final groups = <String, List<Entry>>{};
    for (final e in list) {
      groups.putIfAbsent(dayLabel(e.at, now), () => <Entry>[]).add(e);
    }

    return TermScaffold(
      title: 'Alimentação',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Anotar refeição',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => showMealSheet(context),
        ),
      ),
      body: list.isEmpty
          ? const EmptyHint('> Nada anotado ainda.', 'Registre o que comeu, do seu jeito.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final g in groups.entries) ...[
                  SectionHeader(g.key, count: g.value.length),
                  for (final e in g.value)
                    TermRow(
                      key: ValueKey('food-${e.id}-${e.updatedAt.millisecondsSinceEpoch}'),
                      title: firstLine(e.text('text')),
                      subtitle: _meals[e.text('meal')] ?? 'REFEIÇÃO',
                      trailing: hm(e.at),
                      onTap: () => showEntryActions(
                        context,
                        e,
                        title: _meals[e.text('meal')] ?? 'Refeição',
                        top: [
                          SelectableText(e.text('text'),
                              style: const TextStyle(fontSize: 15, height: 1.4)),
                          gap(6),
                          Text('${dayLabel(e.at, now)} ${hm(e.at)}',
                              style: TextStyle(color: s.palette.dim, fontSize: 12)),
                        ],
                        onEdit: () => showMealSheet(context, edit: e),
                        deletedMessage: 'Refeição apagada.',
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
