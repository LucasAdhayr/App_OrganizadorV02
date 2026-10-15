import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizador/app/app_state.dart';
import 'package:organizador/app/palette.dart';
import 'package:organizador/core/models.dart';
import 'package:organizador/data/backup.dart';
import 'package:organizador/data/store.dart';
import 'package:organizador/services/backup_files.dart';
import 'package:organizador/services/backup_manager.dart';

import 'fake_store.dart';

DateTime _clock = DateTime(2026, 10, 14, 22, 0);

class _FakeFiles implements BackupFiles {
  final Map<String, Uint8List> data = {};
  bool failSave = false;
  Uint8List? picked;

  @override
  String get folderLabel => 'Downloads/Organizador';

  @override
  Future<void> save(String name, Uint8List bytes) async {
    if (failSave) throw Exception('sem espaço');
    data[name] = bytes;
  }

  @override
  Future<List<BackupFile>> list() async => [
        for (final e in data.entries)
          BackupFile(name: e.key, uri: e.key, modified: _clock, size: e.value.length),
      ];

  @override
  Future<Uint8List> read(String uri) async => data[uri]!;

  @override
  Future<void> delete(String uri) async => data.remove(uri);

  @override
  Future<Uint8List?> pick() async => picked;
}

AppState _app(FakeStore store) => AppState(clock: () => _clock, store: store);

Task _task(AppState s, String title,
        {DateTime? due, TimeOfDay? time, TaskKind kind = TaskKind.single}) =>
    Task(
      id: s.newId('t'),
      title: title,
      kind: kind,
      createdAt: _clock,
      due: due,
      time: time,
      recurrence: kind == TaskKind.recurring
          ? const Recurrence(type: RecurrenceType.weekdays, weekdays: {1, 3})
          : null,
    );

void main() {
  setUp(() => _clock = DateTime(2026, 10, 14, 22, 0));

  group('formato', () {
    test('ida e volta preserva tudo', () {
      final s = _app(FakeStore());
      s.saveTask(
          _task(s, 'Academia',
              kind: TaskKind.recurring,
              due: DateTime(2026, 10, 14),
              time: const TimeOfDay(hour: 7, minute: 0)),
          isNew: true);
      s.addNote('lembrar do ônibus', idea: true);
      s.setPalette(AppPalette.amber);

      final text = encodeBackup(s.exportSnapshot(), _clock);
      final back = decodeBackup(text);
      expect(back.taskCount, 1);
      expect(back.noteCount, 1);
      expect(back.historyCount, 1);
      expect(back.snapshot.tasks.single.recurrence!.weekdays, {1, 3});
      expect(back.snapshot.tasks.single.time, const TimeOfDay(hour: 7, minute: 0));
      expect(back.snapshot.notes.single.isIdea, isTrue);
      expect(back.snapshot.settings['palette'], 'ambar');
      expect(back.createdAt, _clock);
    });

    test('o arquivo é JSON legível com as chaves documentadas', () {
      final s = _app(FakeStore());
      final map = jsonDecode(encodeBackup(s.exportSnapshot(), _clock)) as Map<String, dynamic>;
      expect(map['format'], 'organizador-backup');
      expect(map['version'], 1);
      expect(map.keys, containsAll(['counts', 'settings', 'tasks', 'history', 'notes']));
    });

    test('rejeita lixo, formato errado, versão nova e linha corrompida', () {
      expect(() => decodeBackup('não é json'), throwsA(isA<BackupFormatException>()));
      expect(() => decodeBackup('{"format":"outro"}'), throwsA(isA<BackupFormatException>()));
      expect(() => decodeBackup('[1,2]'), throwsA(isA<BackupFormatException>()));
      expect(
        () => decodeBackup(
            '{"format":"organizador-backup","version":99,"createdAt":"2026-01-01T00:00:00"}'),
        throwsA(isA<BackupFormatException>()),
      );
      final bad = jsonDecode(encodeBackup(const StoreSnapshot(), _clock)) as Map<String, dynamic>;
      bad['tasks'] = [
        {'id': 'x'}
      ];
      expect(() => decodeBackup(jsonEncode(bad)), throwsA(isA<BackupFormatException>()));
    });
  });

  group('autoBackupDue', () {
    test('antes das 23:00 vale o de ontem às 23:00', () {
      final now = DateTime(2026, 10, 14, 22, 0);
      expect(autoBackupDue(now, null), isTrue);
      expect(autoBackupDue(now, DateTime(2026, 10, 13, 23, 0)), isFalse);
      expect(autoBackupDue(now, DateTime(2026, 10, 13, 22, 59)), isTrue);
    });

    test('depois das 23:00 vale o de hoje', () {
      final now = DateTime(2026, 10, 14, 23, 5);
      expect(autoBackupDue(now, DateTime(2026, 10, 14, 22, 0)), isTrue);
      expect(autoBackupDue(now, DateTime(2026, 10, 14, 23, 0)), isFalse);
    });

    test('app fechado às 23:00: faz na próxima abertura (manhã seguinte)', () {
      final now = DateTime(2026, 10, 15, 8, 0);
      expect(autoBackupDue(now, DateTime(2026, 10, 14, 10, 0)), isTrue);
    });
  });

  test('nome do arquivo', () {
    expect(backupFileName(DateTime(2026, 1, 2, 23, 0, 5), BackupKind.auto),
        'organizador-backup-2026-01-02-230005-auto.json');
  });

  group('manager', () {
    test('backup manual grava arquivo e registra o último', () async {
      final store = FakeStore();
      final s = _app(store);
      final files = _FakeFiles();
      final m = BackupManager(files, s);
      s.saveTask(_task(s, 'A'), isNew: true);

      final name = await m.backupNow();
      expect(files.data.keys, [name]);
      expect(s.lastBackupAt, _clock);
      expect(s.lastBackupKind, BackupKind.manual);
      await Future<void>.delayed(Duration.zero);
      expect(store.settings['lastBackupName'], name);
    });

    test('automático só roda quando devido, e não com app vazio', () async {
      final s = _app(FakeStore());
      final files = _FakeFiles();
      final m = BackupManager(files, s);
      await m.runAutoIfDue();
      expect(files.data, isEmpty); // vazio

      s.saveTask(_task(s, 'A'), isNew: true);
      await m.runAutoIfDue();
      expect(files.data.length, 1);
      await m.runAutoIfDue(); // já feito
      expect(files.data.length, 1);

      _clock = DateTime(2026, 10, 15, 23, 1);
      await m.runAutoIfDue();
      expect(files.data.length, 2);
    });

    test('automático desligado não roda', () async {
      final s = _app(FakeStore());
      final files = _FakeFiles();
      s.saveTask(_task(s, 'A'), isNew: true);
      s.setAutoBackup(false);
      await BackupManager(files, s).runAutoIfDue();
      expect(files.data, isEmpty);
    });

    test('falha no automático guarda o erro e espera para tentar de novo', () async {
      final s = _app(FakeStore());
      final files = _FakeFiles()..failSave = true;
      final m = BackupManager(files, s);
      s.saveTask(_task(s, 'A'), isNew: true);
      await m.runAutoIfDue();
      expect(m.lastAutoError, isNotNull);
      expect(s.lastBackupAt, isNull);

      files.failSave = false;
      _clock = _clock.add(const Duration(minutes: 5));
      await m.runAutoIfDue(); // ainda dentro dos 30 min
      expect(files.data, isEmpty);
      _clock = _clock.add(const Duration(minutes: 30));
      await m.runAutoIfDue();
      expect(files.data.length, 1);
      expect(m.lastAutoError, isNull);
    });

    test('mantém só os 14 últimos automáticos e todos os manuais', () async {
      final s = _app(FakeStore());
      final files = _FakeFiles();
      final m = BackupManager(files, s);
      s.saveTask(_task(s, 'A'), isNew: true);
      await m.backupNow(); // manual
      for (var i = 0; i < 20; i++) {
        _clock = _clock.add(const Duration(days: 1, minutes: 5));
        await m.backupNow(kind: BackupKind.auto);
      }
      final autos = files.data.keys.where((n) => n.endsWith('-auto.json')).length;
      final manuals = files.data.keys.where((n) => n.endsWith('-manual.json')).length;
      expect(autos, BackupManager.keepAuto);
      expect(manuals, 1);
    });

    test('restaurar: cópia de segurança, troca tudo e persiste', () async {
      final store = FakeStore();
      final s = _app(store);
      final files = _FakeFiles();
      final m = BackupManager(files, s);

      s.saveTask(_task(s, 'Antiga'), isNew: true);
      await m.backupNow();
      final data = m.inspect(files.data.values.single);

      s.saveTask(_task(s, 'Nova depois do backup'), isNew: true);
      s.addNote('nota nova');
      expect(s.tasks.length, 2);

      final safety = await m.restore(data);
      expect(s.tasks.map((t) => t.title), ['Antiga']);
      expect(s.notes, isEmpty);
      expect(store.tasks.length, 1);
      // A cópia de segurança tem os dados de ANTES da restauração.
      final saved = decodeBackup(utf8.decode(files.data[safety]!));
      expect(saved.taskCount, 2);
      expect(saved.noteCount, 1);
      // Cópia de segurança não vira "último backup".
      expect(s.lastBackupKind, BackupKind.manual);
    });

    test('se a cópia de segurança falhar, nada é restaurado', () async {
      final s = _app(FakeStore());
      final files = _FakeFiles();
      final m = BackupManager(files, s);
      s.saveTask(_task(s, 'Atual'), isNew: true);
      final other = _app(FakeStore());
      other.saveTask(_task(other, 'De outro backup'), isNew: true);
      final data = decodeBackup(encodeBackup(other.exportSnapshot(), _clock));

      files.failSave = true;
      await expectLater(m.restore(data), throwsA(isA<Exception>()));
      expect(s.tasks.map((t) => t.title), ['Atual']);
    });

    test('arquivo inválido não altera nada', () {
      final s = _app(FakeStore());
      final m = BackupManager(_FakeFiles(), s);
      expect(() => m.inspect(Uint8List.fromList([0xff, 0xfe, 0x00])),
          throwsA(isA<BackupFormatException>()));
      expect(() => m.inspect(Uint8List.fromList(utf8.encode('{}'))),
          throwsA(isA<BackupFormatException>()));
    });

    test('restaurar reagenda os lembretes e abre igual depois', () async {
      final store = FakeStore();
      final s = _app(store);
      final m = BackupManager(_FakeFiles(), s);
      final other = _app(FakeStore());
      other.saveTask(_task(other, 'X', due: DateTime(2026, 10, 20)), isNew: true);
      await m.restore(decodeBackup(encodeBackup(other.exportSnapshot(), _clock)));
      await Future<void>.delayed(Duration.zero);

      final reopened = _app(store);
      await reopened.load();
      expect(reopened.tasks.single.title, 'X');
    });
  });
}
