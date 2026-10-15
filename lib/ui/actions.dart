import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/palette.dart';
import '../core/dates.dart';
import '../core/models.dart';
import 'sheets.dart';

/// Aviso curto no rodapé, com "desfazer" opcional.
void toast(
  ScaffoldMessengerState messenger,
  AppPalette p,
  String message, {
  VoidCallback? onUndo,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      // Com botão de ação, o Flutter mantém o aviso na tela até ser dispensado
      // (persist). Aqui ele deve sumir sozinho em 3 segundos.
      persist: false,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: p.dim),
      ),
      content: Text('> $message', style: TextStyle(color: p.fg, fontSize: 14)),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'DESFAZER', textColor: p.fg, onPressed: onUndo),
    ),
  );
}

void showToast(BuildContext context, String message, {VoidCallback? onUndo}) {
  toast(
    ScaffoldMessenger.of(context),
    AppScope.read(context).palette,
    message,
    onUndo: onUndo,
  );
}

// Todas as ações capturam estado e mensageiro ANTES de qualquer espera,
// porque a linha que chamou pode sair da tela logo depois da ação.

/// Uma tarefa recorrente só pode ser concluída ou pulada a partir do dia da
/// sua ocorrência. Antes disso, avisa e devolve false.
bool ensureCanComplete(BuildContext context, Task t) {
  final s = AppScope.read(context);
  if (s.canComplete(t)) return true;
  showToast(context, 'Ainda não. A próxima é ${fmtDateShort(t.dueDate!)}.');
  return false;
}

void completeTask(BuildContext context, Task t) {
  if (!ensureCanComplete(context, t)) return;
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  s.complete(t);
  final msg = switch (t.kind) {
    TaskKind.recurring => 'Feito. Próxima: ${fmtDateShort(t.due!)}.',
    TaskKind.single => 'Tarefa concluída.',
    TaskKind.reusable => 'Marcada como feita.',
  };
  toast(m, s.palette, msg, onUndo: s.undo);
}

Future<void> snoozeTask(BuildContext context, Task t) async {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  final until = await showSnoozeSheet(context, task: t);
  if (until == null) return;
  s.snooze(t, until);
  toast(m, s.palette, 'Adiada para ${fmtWhen(until, s.now)}.', onUndo: s.undo);
}

Future<void> discardTask(BuildContext context, Task t) async {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  final recurring = t.kind == TaskKind.recurring;
  final ok = await confirmTerm(
    context,
    title: 'Descartar tarefa',
    message: recurring
        ? '"${t.title}" deixa de se repetir. O histórico é mantido.'
        : '"${t.title}" sai da lista. O histórico é mantido.',
    confirmLabel: 'Descartar',
    danger: true,
  );
  if (!ok) return;
  s.discard(t);
  toast(m, s.palette, 'Tarefa descartada.', onUndo: s.undo);
}

void skipTask(BuildContext context, Task t) {
  if (!ensureCanComplete(context, t)) return;
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  s.skip(t);
  toast(m, s.palette, 'Pulada. Próxima: ${fmtDateShort(t.due!)}.', onUndo: s.undo);
}

void reopenTask(BuildContext context, Task t) {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  s.reopen(t);
  toast(m, s.palette, 'Tarefa reaberta.', onUndo: s.undo);
}

void keepTask(BuildContext context, Task t) {
  final s = AppScope.read(context);
  final m = ScaffoldMessenger.of(context);
  s.keepPending(t);
  toast(m, s.palette, 'Mantida como pendente.', onUndo: s.undo);
}
