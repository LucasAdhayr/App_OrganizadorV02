import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/models.dart';
import 'codec.dart';
import 'store.dart';

/// Banco local (SQLite) no armazenamento privado do app. Funciona offline.
///
/// Versão do esquema: 1. Mudanças futuras entram em [_upgrade], sem apagar
/// dados existentes.
class SqliteStore implements AppStore {
  SqliteStore._(this._db);

  final Database _db;

  static const int _version = 1;
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
        last_done_at INTEGER
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
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // Versão 1 é a primeira: ainda não há migrações.
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
    return StoreSnapshot(
      tasks: tasks.map(taskFromMap).toList(),
      history: history.map(eventFromMap).toList(),
      notes: notes.map(noteFromMap).toList(),
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
  Future<void> setSetting(String key, String value) => _db.insert(
        'settings',
        <String, Object?>{'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
