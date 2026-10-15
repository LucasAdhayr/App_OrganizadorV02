import 'dart:convert';
import 'dart:typed_data';

import '../app/app_state.dart';
import '../data/backup.dart';
import 'backup_files.dart';

/// Faz, lista e restaura backups. Os arquivos são JSON no celular; nada sai do
/// aparelho (a pasta pode ser sincronizada com o Drive pelo próprio usuário).
class BackupManager {
  BackupManager(this.files, this.state);

  final BackupFiles files;
  final AppState state;

  /// Quantos backups automáticos manter (os manuais nunca são apagados).
  static const int keepAuto = 14;

  /// Intervalo mínimo entre tentativas do automático depois de uma falha.
  static const Duration retryAfter = Duration(minutes: 30);

  bool _busy = false;
  DateTime? _failedAt;

  /// Último erro do backup automático (a tela mostra enquanto existir).
  String? lastAutoError;

  Future<String> backupNow({BackupKind kind = BackupKind.manual}) async {
    final now = state.now;
    final text = encodeBackup(state.exportSnapshot(), now);
    final name = backupFileName(now, kind);
    await files.save(name, Uint8List.fromList(utf8.encode(text)));
    state.setBackupInfo(now, name, kind);
    if (kind == BackupKind.auto) await _prune();
    return name;
  }

  /// Chamado ao abrir o app, ao voltar para ele e a cada minuto enquanto
  /// aberto. Só faz algo se já passou das 23:00 sem backup desde então.
  Future<void> runAutoIfDue() async {
    if (!state.autoBackup || _busy) return;
    if (state.tasks.isEmpty && state.notes.isEmpty && state.history.isEmpty) return;
    final now = state.now;
    if (!autoBackupDue(now, state.lastBackupAt)) return;
    final failed = _failedAt;
    if (failed != null && now.difference(failed) < retryAfter) return;

    _busy = true;
    try {
      await backupNow(kind: BackupKind.auto);
      lastAutoError = null;
      _failedAt = null;
    } catch (e) {
      lastAutoError = '$e';
      _failedAt = now;
    } finally {
      _busy = false;
      state.tick();
    }
  }

  Future<void> _prune() async {
    try {
      final autos = (await files.list())
          .where((f) => f.name.endsWith('-${BackupKind.auto.suffix}.json'))
          .toList()
        ..sort((a, b) => b.name.compareTo(a.name));
      for (final f in autos.skip(keepAuto)) {
        await files.delete(f.uri);
      }
    } catch (_) {
      // Limpeza é só conforto; não pode derrubar o backup.
    }
  }

  Future<List<BackupFile>> saved() => files.list();

  /// Lê e valida os bytes de um arquivo. Não altera nada.
  BackupData inspect(Uint8List bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const BackupFormatException('O arquivo não é texto (não é um backup).');
    }
    return decodeBackup(text);
  }

  /// Restaura: primeiro grava uma cópia dos dados atuais (se isso falhar, nada
  /// é restaurado); depois substitui tudo pelo conteúdo do backup. Devolve o
  /// nome da cópia de segurança.
  Future<String> restore(BackupData data) async {
    final now = state.now;
    final name = backupFileName(now, BackupKind.safety);
    final text = encodeBackup(state.exportSnapshot(), now);
    await files.save(name, Uint8List.fromList(utf8.encode(text)));
    await state.restoreFrom(data.snapshot);
    return name;
  }
}
