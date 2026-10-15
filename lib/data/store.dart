import '../core/models.dart';

/// Tudo o que o app guarda, lido de uma vez ao abrir.
class StoreSnapshot {
  const StoreSnapshot({
    this.tasks = const <Task>[],
    this.history = const <HistoryEvent>[],
    this.notes = const <Note>[],
    this.settings = const <String, String>{},
  });

  final List<Task> tasks;
  final List<HistoryEvent> history;
  final List<Note> notes;
  final Map<String, String> settings;
}

/// Onde os dados ficam guardados. O app conversa só com esta interface:
/// hoje é SQLite no aparelho ([SqliteStore]); nos testes é uma versão em memória.
abstract class AppStore {
  Future<StoreSnapshot> load();

  /// Cria ou substitui a tarefa. Tarefas nunca são apagadas: descartar é um
  /// estado.
  Future<void> upsertTask(Task task);

  Future<void> addHistory(HistoryEvent event);

  /// Usado só pelo "desfazer", que anula o registro que a ação acabou de criar.
  Future<void> deleteHistory(List<String> ids);

  /// Cria ou substitui a nota (e a "des-apaga", se ela estava apagada).
  Future<void> upsertNote(Note note);

  /// Remoção lógica: a nota some da lista, mas a linha continua no banco.
  Future<void> deleteNote(String id);

  Future<void> setSetting(String key, String value);

  /// Restauração: troca tarefas, histórico e notas pelo conteúdo de [snap], de
  /// uma vez só (tudo ou nada). As configurações de [snap] são gravadas por
  /// cima; as demais (como "último backup") ficam como estão.
  Future<void> replaceAll(StoreSnapshot snap);
}
