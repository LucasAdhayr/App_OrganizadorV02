import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/entry.dart';
import '../core/models.dart';
import '../core/special_dates.dart';
import 'codec.dart';
import 'store.dart';

/// Banco local (SQLite) no armazenamento privado do app. Funciona offline.
///
/// Versão do esquema: 1. Mudanças futuras entram em [_upgrade], sem apagar
/// dados existentes.
class SqliteStore implements AppStore {
  SqliteStore._(this._db);

  final Database _db;

  static const int _version = 7;
  static const String fileName = 'organizador.db';

  /// Abre (ou cria) o banco. [path] só é usado em testes.
  static Future<SqliteStore> open({String? path}) async {
    final file = path ?? p.join(await getDatabasesPath(), fileName);
    final db = await openDatabase(
      file,
      version: _version,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return SqliteStore._(db);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        status TEXT NOT NULL,
        due TEXT,
        time_minutes INTEGER,
        rec_type TEXT,
        rec_weekdays TEXT,
        rec_interval INTEGER,
        rec_day INTEGER,
        rec_month INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        snoozed_until INTEGER,
        last_done_at INTEGER,
        module TEXT,
        alarm INTEGER NOT NULL DEFAULT 0,
        amount_cents INTEGER,
        ref TEXT
      )
    ''');
    batch.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        at INTEGER NOT NULL,
        kind TEXT NOT NULL,
        task_id TEXT NOT NULL,
        task_title TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT ''
      )
    ''');
    batch.execute('CREATE INDEX idx_history_at ON history(at)');
    batch.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_idea INTEGER NOT NULL DEFAULT 0,
        converted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    batch.execute(_datesSql);
    batch.execute(_entriesSql);
    batch.execute(_entriesIndexSql);
    await batch.commit(noResult: true);
  }

  static const String _datesSql = '''
      CREATE TABLE dates (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        year INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''';

  static const String _entriesSql = '''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        module TEXT NOT NULL,
        at INTEGER NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''';

  static const String _entriesIndexSql =
      'CREATE INDEX idx_entries_module_at ON entries(module, at)';

  /// Migrações: nunca apagam dados existentes.
  /// v2: tabela de aniversários e datas.
  /// v3: tabela de registros dos módulos simples.
  /// v4: coluna `module` nas tarefas (rotinas de exercício).
  /// v5: coluna `alarm` nas tarefas (toca como alarme).
  /// v6: coluna `amount_cents` nas tarefas (contas a pagar).
  /// v7: coluna `ref` nas tarefas (liga provas/trabalhos à disciplina).
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) await db.execute(_datesSql);
    if (from < 3) {
      await db.execute(_entriesSql);
      await db.execute(_entriesIndexSql);
    }
    if (from < 4) await db.execute('ALTER TABLE tasks ADD COLUMN module TEXT');
    if (from < 5) {
      await db.execute('ALTER TABLE tasks ADD COLUMN alarm INTEGER NOT NULL DEFAULT 0');
    }
    if (from < 6) await db.execute('ALTER TABLE tasks ADD COLUMN amount_cents INTEGER');
    if (from < 7) await db.execute('ALTER TABLE tasks ADD COLUMN ref TEXT');
  }

  Future<void> close() => _db.close();

  @override
  Future<StoreSnapshot> load() async {
    final tasks = await _db.query('tasks');
    final history = await _db.query('history', orderBy: 'at ASC, rowid ASC');
    final notes = await _db.query(
      'notes',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC, rowid ASC',
    );
    final settings = await _db.query('settings');
    final dates = await _db.query('dates', orderBy: 'created_at ASC, rowid ASC');
    final entries = await _db.query(
      'entries',
      where: 'deleted_at IS NULL',
      orderBy: 'at ASC, rowid ASC',
    );
    return StoreSnapshot(
      tasks: tasks.map(taskFromMap).toList(),
      history: history.map(eventFromMap).toList(),
      notes: notes.map(noteFromMap).toList(),
      dates: dates.map(dateFromMap).toList(),
      entries: entries.map(entryFromMap).toList(),
      settings: <String, String>{
        for (final r in settings) r['key']! as String: r['value']! as String,
      },
    );
  }

  @override
  Future<void> upsertTask(Task task) => _db.insert(
        'tasks',
        taskToMap(task),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> addHistory(HistoryEvent event) => _db.insert(
        'history',
        eventToMap(event),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> deleteHistory(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete('history', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> upsertNote(Note note) => _db.insert(
        'notes',
        noteToMap(note),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> deleteNote(String id) => _db.update(
        'notes',
        <String, Object?>{'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<void> replaceAll(StoreSnapshot snap) => _db.transaction((txn) async {
        await txn.delete('tasks');
        await txn.delete('history');
        await txn.delete('notes');
        await txn.delete('dates');
        await txn.delete('entries');
        final batch = txn.batch();
        for (final t in snap.tasks) {
          batch.insert('tasks', taskToMap(t), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final e in snap.history) {
          batch.insert('history', eventToMap(e), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final n in snap.notes) {
          batch.insert('notes', noteToMap(n), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final d in snap.dates) {
          batch.insert('dates', dateToMap(d), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final e in snap.entries) {
          batch.insert('entries', entryToMap(e), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final e in snap.settings.entries) {
          batch.insert(
            'settings',
            <String, Object?>{'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

  @override
  Future<void> upsertDate(SpecialDate date) => _db.insert(
        'dates',
        dateToMap(date),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> deleteDate(String id) => _db.delete('dates', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> upsertEntry(Entry entry) => _db.insert(
        'entries',
        entryToMap(entry),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> deleteEntry(String id) => _db.update(
        'entries',
        <String, Object?>{'deleted_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<void> setSetting(String key, String value) => _db.insert(
        'settings',
        <String, Object?>{'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
