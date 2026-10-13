import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../modules/registry.dart';
import '../actions.dart';
import '../term_widgets.dart';

/// MÓDULOS: gerada a partir de [kModules]. Módulo novo entra na lista sozinho.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('> Escolha um módulo.', style: TextStyle(color: p.dim, fontSize: 13)),
        const SizedBox(height: 8),
        const TermDivider(),
        for (final m in kModules) ...[
          TermRow(
            title: m.label,
            subtitle: m.blurb,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: Icon(m.icon, color: m.ready ? p.fg : p.dim),
            ),
            trailing: m.ready ? null : 'EM BREVE',
            onTap: () {
              final open = m.screen;
              if (open == null) {
                showToast(context, 'Este módulo chega em uma próxima etapa.');
                return;
              }
              Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: open));
            },
          ),
          const TermDivider(),
        ],
      ],
    );
  }
}
