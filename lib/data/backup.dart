import 'dart:convert';

import '../core/dates.dart';
import 'codec.dart';
import 'store.dart';

// Formato do arquivo de backup (JSON legível, documentado em
// docs/BACKUP_FORMATO.md). Tudo aqui é puro Dart e testado sem Android.

const String kBackupFormat = 'organizador-backup';
const int kBackupVersion = 1;

/// Configurações que entram no backup. As informações do próprio backup
/// (último backup etc.) ficam de fora.
const Set<String> kBackupSettingKeys = {
  'palette',
  'effects',
  'reviewAfterDays',
  'waterGoal', // antigo (em copos); só lido ao restaurar backups velhos
  'waterGoalMl',
  'waterReminders',
};

/// Hora do backup automático.
const int kAutoBackupHour = 23;

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Conteúdo já lido e validado de um arquivo de backup.
class BackupData {
  const BackupData({required this.createdAt, required this.snapshot});

  final DateTime createdAt;
  final StoreSnapshot snapshot;

  int get taskCount => snapshot.tasks.length;
  int get noteCount => snapshot.notes.length;
  int get historyCount => snapshot.history.length;
  int get dateCount => snapshot.dates.length;
  int get entryCount => snapshot.entries.length;
}

String encodeBackup(StoreSnapshot snap, DateTime now) {
  final map = <String, Object?>{
    'format': kBackupFormat,
    'version': kBackupVersion,
    'createdAt': now.toIso8601String(),
    'counts': <String, int>{
      'tasks': snap.tasks.length,
      'history': snap.history.length,
      'notes': snap.notes.length,
      'dates': snap.dates.length,
      'entries': snap.entries.length,
    },
    'settings': <String, String>{
      for (final e in snap.settings.entries)
        if (kBackupSettingKeys.contains(e.key)) e.key: e.value,
    },
    'tasks': snap.tasks.map(taskToMap).toList(),
    'history': snap.history.map(eventToMap).toList(),
    'notes': snap.notes.map(noteToMap).toList(),
    'dates': snap.dates.map(dateToMap).toList(),
    'entries': [
      for (final e in snap.entries) <String, Object?>{...entryToMap(e), 'data': e.data},
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Lê e valida. Se algo estiver errado, lança [BackupFormatException] com uma
/// mensagem que dá para mostrar ao usuário. Nada é alterado aqui.
BackupData decodeBackup(String text) {
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    throw const BackupFormatException('O arquivo não é um JSON válido.');
  }
  if (raw is! Map<String, dynamic> || raw['format'] != kBackupFormat) {
    throw const BackupFormatException('Esse arquivo não é um backup do Organizador.');
  }
  final Map<String, dynamic> doc = raw;
  final version = doc['version'];
  if (version is! int || version < 1) {
    throw const BackupFormatException('Versão do backup inválida.');
  }
  if (version > kBackupVersion) {
    throw BackupFormatException(
      'Backup criado por uma versão mais nova do app (v$version). Atualize o app.',
    );
  }
  final created = DateTime.tryParse('${doc['createdAt']}');
  if (created == null) {
    throw const BackupFormatException('Backup sem data de criação.');
  }

  List<T> rows<T>(String key, T Function(Map<String, Object?>) parse,
      {bool optional = false}) {
    final list = doc[key];
    if (list == null && optional) return <T>[];
    if (list is! List) throw BackupFormatException('Backup sem a lista "$key".');
    final out = <T>[];
    for (var i = 0; i < list.length; i++) {
      final row = list[i];
      try {
        if (row is! Map) throw const FormatException('linha inválida');
        out.add(parse(Map<String, Object?>.from(row)));
      } catch (_) {
        throw BackupFormatException('Registro ${i + 1} de "$key" está corrompido.');
      }
    }
    return out;
  }

  final settings = <String, String>{};
  final rawSettings = doc['settings'];
  if (rawSettings is Map) {
    for (final e in rawSettings.entries) {
      if (kBackupSettingKeys.contains(e.key) && e.value != null) {
        settings['${e.key}'] = '${e.value}';
      }
    }
  }

  return BackupData(
    createdAt: created,
    snapshot: StoreSnapshot(
      tasks: rows('tasks', taskFromMap),
      history: rows('history', eventFromMap),
      notes: rows('notes', noteFromMap),
      // Backups antigos (sem aniversários) continuam valendo.
      dates: rows('dates', dateFromMap, optional: true),
      entries: rows('entries', entryFromMap, optional: true),
      settings: settings,
    ),
  );
}

/// Verdadeiro se já passou um horário de backup (23:00) desde o último.
/// Se o app estava fechado às 23:00, o backup é feito na próxima abertura.
bool autoBackupDue(DateTime now, DateTime? last) {
  final todayAt = DateTime(now.year, now.month, now.day, kAutoBackupHour);
  final boundary =
      now.isBefore(todayAt) ? todayAt.subtract(const Duration(days: 1)) : todayAt;
  // subtract(1 dia) pode errar em troca de horário de verão; refaz por data.
  final fixed = DateTime(boundary.year, boundary.month, boundary.day, kAutoBackupHour);
  return last == null || last.isBefore(fixed);
}

enum BackupKind { manual, auto, safety }

extension BackupKindX on BackupKind {
  String get suffix => switch (this) {
        BackupKind.manual => 'manual',
        BackupKind.auto => 'auto',
        BackupKind.safety => 'antes-de-restaurar',
      };

  String get label => switch (this) {
        BackupKind.manual => 'manual',
        BackupKind.auto => 'automático',
        BackupKind.safety => 'cópia de segurança',
      };
}

String backupFileName(DateTime now, BackupKind kind) =>
    'organizador-backup-${now.year}-${two(now.month)}-${two(now.day)}-'
    '${two(now.hour)}${two(now.minute)}${two(now.second)}-${kind.suffix}.json';
