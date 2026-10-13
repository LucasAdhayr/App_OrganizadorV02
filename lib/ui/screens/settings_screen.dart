import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/palette.dart';
import '../term_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final dim = TextStyle(color: p.dim, fontSize: 12, height: 1.4);

    return TermScaffold(
      title: 'Configurações',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const FieldLabel('Tema'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pal in AppPalette.all)
                TermButton(
                  label: pal.name,
                  dense: true,
                  selected: s.palette.id == pal.id,
                  onPressed: () => s.setPalette(pal),
                ),
            ],
          ),
          const FieldLabel('Efeitos de tela'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in EffectLevel.values)
                TermButton(
                  label: level.label,
                  dense: true,
                  selected: s.effects == level,
                  onPressed: () => s.setEffects(level),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Linhas de varredura e brilho leve. Nada pisca nem se move. '
            'OFF desliga tudo.',
            style: dim,
          ),
          const FieldLabel('Revisão de tarefas antigas'),
          Row(
            children: [
              TermButton(
                label: '−',
                dense: true,
                onPressed: () => s.setReviewAfterDays(s.reviewAfterDays - 1),
              ),
              SizedBox(
                width: 96,
                child: Center(
                  child: Text(
                    '${s.reviewAfterDays} DIAS',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              TermButton(
                label: '+',
                dense: true,
                onPressed: () => s.setReviewAfterDays(s.reviewAfterDays + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tarefas sem atualização por esse tempo pedem uma decisão. '
            'Nenhuma é apagada sozinha.',
            style: dim,
          ),
          const FieldLabel('Lembretes'),
          Text(
            'Chegam na Etapa 3: silêncio das 00:00 às 05:00; adiar por 10 min, '
            '1 h, hoje à noite ou amanhã; aviso 1 dia antes e às 09:00.',
            style: dim,
          ),
          const FieldLabel('Backup'),
          Text(
            'Chega na Etapa 4: arquivo no próprio celular, manual e diário, '
            'mostrando a data do último.',
            style: dim,
          ),
          const FieldLabel('Sobre esta versão'),
          Text(
            'Protótipo da Etapa 1. Os dados são de exemplo e ficam só na '
            'memória: somem quando o app é fechado. O banco local chega na '
            'Etapa 2.',
            style: dim,
          ),
        ],
      ),
    );
  }
}
