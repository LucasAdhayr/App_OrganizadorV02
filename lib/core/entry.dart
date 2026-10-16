/// Módulos simples (água, alimentação, exercícios, livros) guardam seus
/// registros no mesmo formato: um instante, o módulo e um mapa de campos.
/// Assim, um módulo novo não exige tabela nova nem mudança no backup.
class Entry {
  Entry({
    required this.id,
    required this.module,
    required this.at,
    Map<String, Object?>? data,
    required this.createdAt,
    DateTime? updatedAt,
  })  : data = data ?? <String, Object?>{},
        updatedAt = updatedAt ?? createdAt;

  final String id;

  /// Identificador do módulo (veja as constantes `kMod...`).
  final String module;

  /// Quando aconteceu (refeição, treino, copo...). Pode ser corrigido.
  DateTime at;

  /// Campos do módulo. Só valores simples (texto, número, booleano), para
  /// caber em JSON.
  Map<String, Object?> data;

  final DateTime createdAt;
  DateTime updatedAt;

  String text(String key) => (data[key] as String?) ?? '';

  int? number(String key) {
    final v = data[key];
    return v is num ? v.toInt() : null;
  }
}

const String kModWater = 'agua';
const String kModFood = 'alimentacao';
const String kModExercise = 'exercicios';
const String kModBook = 'livros';
