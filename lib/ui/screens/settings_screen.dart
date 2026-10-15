import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/palette.dart';
import '../term_widgets.dart';
import 'diagnostic_screen.dart';

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
          const FieldLabel('Lembretes'),
          Text(
            'Tarefas com horário avisam na hora. Só com data, avisam na véspera '
            'e no dia, às 09:00. Nada toca entre 00:00 e 05:00.',
            style: dim,
          ),
          const SizedBox(height: 8),
          TermButton(
            label: 'Diagnóstico de notificações',
            icon: Icons.notifications_active_outlined,
            expand: true,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => DiagnosticScreen(notifier: s.notifier),
              ),
            ),
          ),
          const FieldLabel('Backup'),
          Text(
            'Chega na Etapa 4: arquivo no próprio celular, manual e diário, '
            'mostrando a data do último.',
            style: dim,
          ),
          const FieldLabel('Sobre esta versão'),
          Text(
            'Etapa 3. Tudo fica salvo no banco do próprio celular e continua '
            'aqui depois de fechar o app.',
            style: dim,
          ),
          const FieldLabel('Dados de exemplo'),
          Text(
            'Só funciona com o app vazio (sem tarefas nem notas).',
            style: dim,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final empty = s.tasks.isEmpty && s.notes.isEmpty;
              s.loadSampleData();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(empty
                    ? 'Dados de exemplo carregados.'
                    : 'O app já tem dados. Nada foi feito.'),
                duration: const Duration(seconds: 3),
              ));
            },
            child: const Text('Carregar dados de exemplo'),
          ),
        ],
      ),
    );
  }
}
