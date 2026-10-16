import 'package:organizador/core/models.dart';
import 'package:organizador/core/special_dates.dart';
import 'package:organizador/data/store.dart';

/// Armazenamento em memória para testes (imita o que o SQLite guardaria).
class FakeStore implements AppStore {
  final Map<String, Task> tasks = {};
  final Map<String, HistoryEvent> history = {};
  final Map<String, Note> notes = {};
  final Map<String, SpecialDate> dates = {};
  final Set<String> deletedNotes = {};
  final Map<String, String> settings = {};

  @override
  Future<StoreSnapshot> load() async => StoreSnapshot(
        tasks: tasks.values.toList(),
        history: history.values.toList(),
        notes: notes.values.where((n) => !deletedNotes.contains(n.id)).toList(),
        dates: dates.values.toList(),
        settings: Map.of(settings),
      );

  @override
  Future<void> upsertTask(Task task) async => tasks[task.id] = task.copy();

  @override
  Future<void> addHistory(HistoryEvent event) async => history[event.id] = event;

  @override
  Future<void> deleteHistory(List<String> ids) async => ids.forEach(history.remove);

  @override
  Future<void> upsertNote(Note note) async {
    notes[note.id] = note;
    deletedNotes.remove(note.id);
  }

  @override
  Future<void> deleteNote(String id) async => deletedNotes.add(id);

  @override
  Future<void> replaceAll(StoreSnapshot snap) async {
    tasks
      ..clear()
      ..addEntries(snap.tasks.map((t) => MapEntry(t.id, t.copy())));
    history
      ..clear()
      ..addEntries(snap.history.map((e) => MapEntry(e.id, e)));
    notes
      ..clear()
      ..addEntries(snap.notes.map((n) => MapEntry(n.id, n)));
    deletedNotes.clear();
    dates
      ..clear()
      ..addEntries(snap.dates.map((d) => MapEntry(d.id, d)));
    settings.addAll(snap.settings);
  }

  @override
  Future<void> upsertDate(SpecialDate date) async => dates[date.id] = date;

  @override
  Future<void> deleteDate(String id) async => dates.remove(id);

  @override
  Future<void> setSetting(String key, String value) async => settings[key] = value;
}
