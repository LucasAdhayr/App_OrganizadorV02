import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../services/notifier.dart';
import '../actions.dart';
import '../term_widgets.dart';

/// Mostra se os lembretes vão funcionar de verdade neste celular e permite
/// testar. Em celulares Xiaomi o sistema costuma matar alarmes de apps
/// fechados; por isso o teste com o app fechado importa.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key, required this.notifier});

  final Notifier? notifier;

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  NotifierStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = widget.notifier;
    final st = n == null ? null : await n.status();
    if (mounted) setState(() => _status = st);
  }

  Future<void> _run(Future<void> Function(Notifier n) op, String done) async {
    final n = widget.notifier;
    if (n == null || _busy) return;
    final s = AppScope.read(context);
    final m = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await op(n);
      toast(m, s.palette, done);
    } catch (e) {
      toast(m, s.palette, 'Falhou: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  String _flag(bool? v) => v == null ? '[?] não deu para saber' : (v ? '[OK]' : '[!] NÃO');

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final dim = TextStyle(color: p.dim, fontSize: 12, height: 1.4);
    final body = TextStyle(color: p.fg, fontSize: 14, height: 1.5);
    final st = _status;
    final planned = s.plannedReminders;
    final n = widget.notifier;

    return TermScaffold(
      title: 'Diagnóstico',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (n == null)
            Text('[!] Notificações indisponíveis nesta execução.', style: body)
          else ...[
            const FieldLabel('Situação'),
            Text('Notificações permitidas: ${_flag(st?.notificationsEnabled)}', style: body),
            Text('Alarmes exatos: ${_flag(st?.exactAlarms)}', style: body),
            Text('Agendados no sistema: ${st?.pending ?? '...'}', style: body),
            Text('Planejados pelo app: ${planned.length}', style: body),
            if (st?.error != null) Text('[!] Último erro: ${st!.error}', style: body),
            const SizedBox(height: 4),
            Text(
              'Sem alarmes exatos, os avisos podem atrasar alguns minutos. '
              'Silêncio: nada toca entre 00:00 e 05:00 (vai para as 05:00).',
              style: dim,
            ),
            const FieldLabel('Próximos lembretes'),
            if (planned.isEmpty)
              Text('> Nenhum lembrete futuro.', style: dim)
            else
              for (final r in planned.take(5))
                Text('${fmtWhen(r.at, s.now)}  ${r.title}', style: body),
            const FieldLabel('Ajustes'),
            TermButton(
              label: 'Permitir notificações',
              expand: true,
              onPressed: _busy ? null : () => _run((x) => x.requestPermission(), 'Pedido enviado.'),
            ),
            const SizedBox(height: 8),
            TermButton(
              label: 'Liberar alarmes exatos',
              expand: true,
              onPressed: _busy ? null : () => _run((x) => x.requestExactAlarms(), 'Pedido enviado.'),
            ),
            const SizedBox(height: 8),
            TermButton(
              label: 'Reagendar tudo',
              expand: true,
              onPressed: _busy
                  ? null
                  : () => _run((x) async => x.replace(s.plannedReminders), 'Lembretes reagendados.'),
            ),
            const FieldLabel('Testes'),
            TermButton(
              label: 'Notificação agora',
              expand: true,
              onPressed: _busy ? null : () => _run((x) => x.showTest(), 'Enviada.'),
            ),
            const SizedBox(height: 8),
            TermButton(
              label: 'Notificação em 1 minuto',
              expand: true,
              onPressed: _busy
                  ? null
                  : () => _run((x) => x.scheduleTest(const Duration(minutes: 1)),
                      'Agendada. Feche o app e espere.'),
            ),
            const SizedBox(height: 8),
            TermButton(
              label: 'Alarme em 1 minuto',
              icon: Icons.alarm,
              expand: true,
              onPressed: _busy
                  ? null
                  : () => _run((x) => x.scheduleAlarmTest(const Duration(minutes: 1)),
                      'Agendado. Feche o app e espere o som de alarme.'),
            ),
            const SizedBox(height: 4),
            Text(
              'Faça o teste de 1 minuto com o app fechado (remova dos recentes). '
              'Se não chegar, veja abaixo.',
              style: dim,
            ),
            const FieldLabel('Se não chegar (Xiaomi / Poco)'),
            Text(
              '1. Configurações > Apps > Gerenciar apps > Organizador > '
              'Início automático: ligar.\n'
              '2. Nessa mesma tela > Economizar bateria > Sem restrições.\n'
              '3. Na tela de apps recentes, segure o card do Organizador e '
              'toque no cadeado.\n'
              '4. Notificações do app: tudo ligado, inclusive "Lembretes de tarefas" e '
              '"Alarmes" (esta com som e tela de bloqueio permitidos).\n'
              '5. Alarmes usam o volume de ALARME do celular: confira que não está no mudo.',
              style: dim,
            ),
          ],
        ],
      ),
    );
  }
}
