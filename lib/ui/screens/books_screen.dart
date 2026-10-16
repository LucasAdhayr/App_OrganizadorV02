import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/entry.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';
import 'entry_common.dart';

const Map<String, String> _status = {
  'lendo': 'LENDO',
  'quero': 'QUERO LER',
  'lido': 'LIDO',
};

int _statusOrder(String s) => switch (s) {
      'lendo' => 0,
      'quero' => 1,
      _ => 2,
    };

String _pages(Entry e) {
  final page = e.number('page') ?? 0;
  final total = e.number('total');
  if (total == null) return page > 0 ? 'pág. $page' : '';
  return 'pág. $page/$total (${(page * 100 / total).clamp(0, 100).round()}%)';
}

String? _subtitle(Entry e) {
  final parts = [
    if (e.text('author').isNotEmpty) e.text('author'),
    if (_pages(e).isNotEmpty) _pages(e),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

double _progress(Entry e) {
  final total = e.number('total');
  if (total == null || total <= 0) return e.text('status') == 'lido' ? 1 : 0;
  return ((e.number('page') ?? 0) / total).clamp(0, 1).toDouble();
}

/// Cadastra um livro (ou edita [edit]).
Future<void> showBookSheet(BuildContext host, {Entry? edit}) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final title = TextEditingController(text: edit?.text('title') ?? '');
  final author = TextEditingController(text: edit?.text('author') ?? '');
  final total = TextEditingController(text: edit?.number('total')?.toString() ?? '');
  var status = edit?.text('status').isNotEmpty == true ? edit!.text('status') : 'lendo';

  return showTermSheet<void>(host, (c) {
    return StatefulBuilder(
      builder: (c, setSheet) {
        void save() {
          final t = title.text.trim();
          if (t.isEmpty) return;
          final pages = int.tryParse(total.text.trim());
          final old = edit?.data ?? const <String, Object?>{};
          var page = (old['page'] as num?)?.toInt() ?? 0;
          if (status == 'lido' && pages != null) page = pages;
          if (pages != null && page > pages) page = pages;
          final data = <String, Object?>{
            'title': t,
            'author': author.text.trim(),
            if (pages != null && pages > 0) 'total': pages,
            'page': page,
            'status': status,
          };
          if (edit == null) {
            s.addEntry(kModBook, data: data);
          } else {
            s.updateEntry(edit, data: data);
          }
          Navigator.of(c).pop();
          toast(m, s.palette, edit == null ? 'Livro adicionado.' : 'Alterações salvas.');
        }

        return SheetFrame(
          title: edit == null ? 'Novo livro' : 'Editar livro',
          children: [
            TextField(
              controller: title,
              autofocus: edit == null,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Título'),
            ),
            gap(8),
            TextField(
              controller: author,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Autor (opcional)'),
            ),
            gap(8),
            TextField(
              controller: total,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15),
              cursorColor: s.palette.fg,
              decoration: termInput(c, hint: 'Total de páginas (opcional)'),
            ),
            gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _status.entries)
                  TermButton(
                    label: e.value,
                    dense: true,
                    selected: status == e.key,
                    onPressed: () => setSheet(() => status = e.key),
                  ),
              ],
            ),
            gap(12),
            TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
          ],
        );
      },
    );
  });
}

/// Atualiza a página em que parou. Chegar ao fim marca como lido.
Future<void> showPageSheet(BuildContext host, Entry e) {
  final s = AppScope.read(host);
  final m = ScaffoldMessenger.of(host);
  final page = TextEditingController(text: '${e.number('page') ?? 0}');
  final total = e.number('total');

  return showTermSheet<void>(host, (c) {
    void save() {
      var p = int.tryParse(page.text.trim());
      if (p == null) return;
      if (total != null && p > total) p = total;
      final data = Map<String, Object?>.from(e.data)..['page'] = p;
      if (total != null && p >= total) {
        data['status'] = 'lido';
      } else if (p > 0 && e.text('status') == 'quero') {
        data['status'] = 'lendo';
      }
      s.updateEntry(e, data: data);
      Navigator.of(c).pop();
      toast(m, s.palette,
          data['status'] == 'lido' ? 'Livro terminado!' : 'Página atualizada.');
    }

    return SheetFrame(
      title: 'Em que página parou?',
      children: [
        TextField(
          controller: page,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 18),
          cursorColor: s.palette.fg,
          decoration: termInput(c, hint: total == null ? 'Página' : 'Página (de $total)'),
        ),
        gap(12),
        TermButton(label: 'Salvar', expand: true, primary: true, onPressed: save),
      ],
    );
  });
}

void _openBook(BuildContext context, Entry e) {
  final s = AppScope.read(context);
  final p = s.palette;
  final m = ScaffoldMessenger.of(context);
  final isDone = e.text('status') == 'lido';

  showEntryActions(
    context,
    e,
    title: e.text('title'),
    top: [
      if (e.text('author').isNotEmpty)
        Text(e.text('author'), style: TextStyle(color: p.dim, fontSize: 13)),
      gap(6),
      Text('${_status[e.text('status')] ?? ''}  ${_pages(e)}',
          style: TextStyle(color: p.fg, fontSize: 14)),
      gap(8),
      BlockBar(value: _progress(e), cells: 16),
    ],
    extra: [
      if (!isDone) ...[
        TermButton(
          label: 'Atualizar página',
          icon: Icons.bookmark_outline,
          expand: true,
          primary: true,
          onPressed: () {
            Navigator.of(context).pop();
            showPageSheet(context, e);
          },
        ),
        gap(),
        TermButton(
          label: 'Marcar como lido',
          expand: true,
          onPressed: () {
            final data = Map<String, Object?>.from(e.data)..['status'] = 'lido';
            final total = e.number('total');
            if (total != null) data['page'] = total;
            s.updateEntry(e, data: data);
            Navigator.of(context).pop();
            toast(m, s.palette, 'Livro terminado!');
          },
        ),
        gap(),
      ],
    ],
    onEdit: () => showBookSheet(context, edit: e),
    deletedMessage: 'Livro apagado.',
  );
}

/// LIVROS: o que está lendo, o que quer ler e o que já leu.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.entriesOf(kModBook)
      ..sort((a, b) {
        final byStatus = _statusOrder(a.text('status')).compareTo(_statusOrder(b.text('status')));
        return byStatus != 0 ? byStatus : b.at.compareTo(a.at);
      });

    final groups = <String, List<Entry>>{};
    for (final e in list) {
      groups.putIfAbsent(_status[e.text('status')] ?? 'LENDO', () => <Entry>[]).add(e);
    }

    return TermScaffold(
      title: 'Livros',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TermButton(
          label: 'Novo livro',
          icon: Icons.add,
          expand: true,
          primary: true,
          onPressed: () => showBookSheet(context),
        ),
      ),
      body: list.isEmpty
          ? const EmptyHint('> Nenhum livro ainda.', 'Guarde o que está lendo e o progresso.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final g in groups.entries) ...[
                  SectionHeader(g.key, count: g.value.length),
                  for (final e in g.value)
                    TermRow(
                      key: ValueKey('book-${e.id}-${e.updatedAt.millisecondsSinceEpoch}'),
                      title: e.text('title'),
                      subtitle: _subtitle(e),
                      trailing: _status[e.text('status')],
                      onTap: () => _openBook(context, e),
                    ),
                ],
              ],
            ),
    );
  }
}
