import 'package:flutter/services.dart';

/// Um arquivo de backup guardado pelo app.
class BackupFile {
  const BackupFile({
    required this.name,
    required this.uri,
    required this.modified,
    required this.size,
  });

  final String name;
  final String uri;
  final DateTime modified;
  final int size;
}

/// Onde os arquivos de backup ficam. Interface para testar sem Android.
abstract class BackupFiles {
  /// Pasta mostrada ao usuário.
  String get folderLabel;

  Future<void> save(String name, Uint8List bytes);
  Future<List<BackupFile>> list();
  Future<Uint8List> read(String uri);
  Future<void> delete(String uri);

  /// Abre o seletor de arquivos do sistema. null = cancelou.
  Future<Uint8List?> pick();
}

/// Android: grava em Downloads/Organizador (MediaStore, sem pedir permissão de
/// armazenamento) e lê/lista/apaga só o que o próprio app criou. Para escolher
/// um arquivo qualquer (por exemplo, depois de reinstalar) usa o seletor de
/// documentos do sistema.
class AndroidBackupFiles implements BackupFiles {
  static const MethodChannel _channel = MethodChannel('br.pessoal.organizador/backup');

  @override
  String get folderLabel => 'Downloads/Organizador';

  @override
  Future<void> save(String name, Uint8List bytes) async {
    await _channel.invokeMethod<String>('save', <String, Object?>{
      'name': name,
      'bytes': bytes,
    });
  }

  @override
  Future<List<BackupFile>> list() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list') ??
        const <Map<Object?, Object?>>[];
    return [
      for (final m in raw)
        BackupFile(
          name: m['name']! as String,
          uri: m['uri']! as String,
          modified: DateTime.fromMillisecondsSinceEpoch(m['modified']! as int),
          size: (m['size'] as int?) ?? 0,
        ),
    ]..sort((a, b) => b.name.compareTo(a.name));
  }

  @override
  Future<Uint8List> read(String uri) async {
    final bytes = await _channel.invokeMethod<Uint8List>('read', <String, Object?>{'uri': uri});
    if (bytes == null) throw Exception('Arquivo vazio ou ilegível.');
    return bytes;
  }

  @override
  Future<void> delete(String uri) async {
    await _channel.invokeMethod<void>('delete', <String, Object?>{'uri': uri});
  }

  @override
  Future<Uint8List?> pick() async {
    // Seletor de documentos do sistema (feito no lado Android).
    return _channel.invokeMethod<Uint8List>('pick');
  }
}
