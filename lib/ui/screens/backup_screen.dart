import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/dates.dart';
import '../../data/backup.dart';
import '../../services/backup_files.dart';
import '../../services/backup_manager.dart';
import '../actions.dart';
import '../sheets.dart';
import '../term_widgets.dart';

/// Backup em arquivo JSON no celular: fazer agora, ligar/desligar o automático
/// (23:00), ver os arquivos salvos e restaurar (sempre com confirmação e uma
/// cópia de segurança dos dados atuais).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupFile>? _saved;
  String? _listError;
  bool _busy = false;

  BackupManager? get _manager => AppScope.read(context).backup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadList());
  }

  Future<void> _loadList() async {
    final m = _manager;
    if (m == null) return;
    try {
      final list = await m.saved();
      if (mounted) {
        setState(() {
          _saved = list;
          _listError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _listError = '$e');
    }
  }

  Future<void> _guard(Future<void> Function() op) async {
    if (_busy) return;
    final s = AppScope.read(context);
    final m = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await op();
    } on BackupFormatException catch (e) {
      toast(m, s.palette, e.message);
    } catch (e) {
      toast(m, s.palette, 'Falhou: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _loadList();
  }

  Future<void> _backupNow() => _guard(() async {
        final s = AppScope.read(context);
        final m = ScaffoldMessenger.of(context);
        final name = await _manager!.backupNow();
        toast(m, s.palette, 'Backup salvo: $name');
      });

  Future<void> _confirmAndRestore(BackupData data) async {
    if (!mounted) return;
    final s = AppScope.read(context);
    final m = ScaffoldMessenger.of(context);
    final mgr = _manager!;
    final ok = await confirmTerm(
      context,
      title: 'Restaurar backup',
      message: 'Isto SUBSTITUI todos os dados atuais pelos do backup de '
          '${fmtWhen(data.createdAt, s.now)}: ${data.taskCount} tarefas, '
          '${data.noteCount} notas e ${data.historyCount} registros no histórico. '
          'Antes, uma cópia dos dados atuais é salva em ${mgr.files.folderLabel}.',
      confirmLabel: 'Restaurar',
      danger: true,
    );
    if (!ok) return;
    final safety = await mgr.restore(data);
    toast(m, s.palette, 'Restaurado. Cópia anterior: $safety');
  }

  Future<void> _restoreFromFile() => _guard(() async {
        final mgr = _manager!;
        final bytes = await mgr.files.pick();
        if (bytes == null) return;
        await _confirmAndRestore(mgr.inspect(bytes));
      });

  Future<void> _restoreSaved(BackupFile f) => _guard(() async {
        final mgr = _manager!;
        final bytes = await mgr.files.read(f.uri);
        await _confirmAndRestore(mgr.inspect(bytes));
      });

  String _lastLine(AppState s) {
    final at = s.lastBackupAt;
    if (at == null) return '[!] Nenhum backup ainda.';
    final kind = s.lastBackupKind?.label ?? '';
    return '[OK] ${fmtWhen(at, s.now)}${kind.isEmpty ? '' : ' ($kind)'}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    final mgr = s.backup;
    final dim = TextStyle(color: p.dim, fontSize: 12, height: 1.4);
    final body = TextStyle(color: p.fg, fontSize: 14, height: 1.5);

    if (mgr == null) {
      return TermScaffold(
        title: 'Backup',
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('[!] Backup indisponível nesta execução.', style: body),
        ),
      );
    }

    final saved = _saved;
    return TermScaffold(
      title: 'Backup',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const FieldLabel('Último backup'),
          Text(_lastLine(s), style: body),
          if (mgr.lastAutoError != null)
            Text('[!] O automático falhou: ${mgr.lastAutoError}', style: body),
          const SizedBox(height: 4),
          Text('Pasta no celular: ${mgr.files.folderLabel}', style: dim),
          const FieldLabel('Fazer backup'),
          TermButton(
            label: 'Fazer backup agora',
            icon: Icons.save_alt,
            expand: true,
            primary: true,
            onPressed: _busy ? null : _backupNow,
          ),
          const SizedBox(height: 8),
          TermButton(
            label: s.autoBackup ? 'Automático às 23:00: LIGADO' : 'Automático às 23:00: DESLIGADO',
            expand: true,
            selected: s.autoBackup,
            onPressed: () => s.setAutoBackup(!s.autoBackup),
          ),
          const SizedBox(height: 4),
          Text(
            'O app não roda em segundo plano: se estiver fechado às 23:00, o '
            'backup é feito na próxima vez que você abrir. Guarda os 14 últimos '
            'automáticos; os manuais nunca são apagados.',
            style: dim,
          ),
          const FieldLabel('Restaurar'),
          TermButton(
            label: 'Escolher um arquivo...',
            icon: Icons.folder_open,
            expand: true,
            onPressed: _busy ? null : _restoreFromFile,
          ),
          const SizedBox(height: 4),
          Text(
            'Use esta opção depois de reinstalar o app ou em outro celular: '
            'copie o arquivo .json para o celular e escolha-o aqui.',
            style: dim,
          ),
          const FieldLabel('Salvos pelo app'),
          if (_listError != null)
            Text('[!] Não foi possível listar: $_listError', style: body)
          else if (saved == null)
            Text('...', style: dim)
          else if (saved.isEmpty)
            Text('> Nenhum arquivo ainda.', style: dim)
          else
            for (final f in saved.take(15))
              TermRow(
                key: ValueKey(f.uri),
                title: f.name.replaceFirst('organizador-backup-', ''),
                subtitle: '${fmtWhen(f.modified, s.now)} · ${(f.size / 1024).ceil()} KB',
                trailing: 'RESTAURAR',
                onTap: _busy ? null : () => _restoreSaved(f),
              ),
        ],
      ),
    );
  }
}
