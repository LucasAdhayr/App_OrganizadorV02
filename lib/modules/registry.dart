import 'package:flutter/material.dart';

import '../ui/screens/date_form_screen.dart';
import '../ui/screens/dates_screen.dart';
import '../ui/screens/books_screen.dart';
import '../ui/screens/classes_screen.dart';
import '../ui/screens/exercise_screen.dart';
import '../ui/screens/finance_screen.dart';
import '../ui/screens/food_screen.dart';
import '../ui/screens/inbox_screen.dart';
import '../ui/screens/medication_screen.dart';
import '../ui/screens/task_form_screen.dart';
import '../ui/screens/water_screen.dart';
import '../ui/screens/tasks_module_screen.dart';

/// Cada módulo se declara aqui. As telas MÓDULOS e o menu "+" são gerados
/// a partir desta lista, então um módulo novo não mexe no núcleo do app.
class ModuleDef {
  const ModuleDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.blurb,
    this.screen,
    this.form,
    this.quickAdd,
    this.addLabel,
  });

  final String id;

  /// Nome na tela MÓDULOS.
  final String label;
  final IconData icon;
  final String blurb;

  /// Tela principal do módulo. Nula = ainda não implementado.
  final WidgetBuilder? screen;

  /// Formulário aberto pelo "+". Nulo = ainda não implementado.
  final WidgetBuilder? form;

  /// Ação direta do "+" (uma folha ou um registro rápido), no lugar de abrir
  /// uma tela de formulário.
  final Future<void> Function(BuildContext context)? quickAdd;

  /// Nome do tipo no menu "+". Nulo = não aparece no menu.
  final String? addLabel;

  bool get ready => screen != null;

  /// O "+" já sabe criar este tipo?
  bool get canAdd => form != null || quickAdd != null;
}

Widget _tasksScreen(BuildContext context) => const TasksModuleScreen();
Widget _taskForm(BuildContext context) => const TaskFormScreen();
Widget _datesScreen(BuildContext context) => const DatesScreen();
Widget _dateForm(BuildContext context) => const DateFormScreen();
Widget _ideasScreen(BuildContext context) => const IdeasScreen();
Widget _waterScreen(BuildContext context) => const WaterScreen();
Widget _foodScreen(BuildContext context) => const FoodScreen();
Widget _exerciseScreen(BuildContext context) => const ExerciseScreen();
Widget _booksScreen(BuildContext context) => const BooksScreen();
Widget _medScreen(BuildContext context) => const MedicationScreen();
Widget _classesScreen(BuildContext context) => const ClassesScreen();
Widget _financeScreen(BuildContext context) => const FinanceScreen();

Future<void> _logWater(BuildContext context) async => logWater(context);
Future<void> _addMeal(BuildContext context) => showMealSheet(context);
Future<void> _addExercise(BuildContext context) => addExerciseChoice(context);
Future<void> _addBook(BuildContext context) => showBookSheet(context);
Future<void> _addMed(BuildContext context) => showMedicationSheet(context);
Future<void> _addClass(BuildContext context) => addClassChoice(context);
Future<void> _addFinance(BuildContext context) => addFinanceChoice(context);

const List<ModuleDef> kModules = [
  ModuleDef(
    id: 'tarefas',
    label: 'TAREFAS',
    icon: Icons.checklist,
    blurb: 'Recorrentes, únicas e reutilizáveis',
    screen: _tasksScreen,
    form: _taskForm,
    addLabel: 'TAREFA',
  ),
  ModuleDef(
    id: 'aulas',
    label: 'AULAS',
    icon: Icons.school_outlined,
    blurb: 'Horários, notas, faltas, provas e trabalhos',
    screen: _classesScreen,
    quickAdd: _addClass,
    addLabel: 'AULA (DISCIPLINA, PROVA)',
  ),
  ModuleDef(
    id: 'aniversarios',
    label: 'ANIVERSÁRIOS',
    icon: Icons.cake_outlined,
    blurb: 'Datas que não podem passar',
    screen: _datesScreen,
    form: _dateForm,
    addLabel: 'ANIVERSÁRIO OU DATA',
  ),
  ModuleDef(
    id: 'ideias',
    label: 'IDEIAS',
    icon: Icons.lightbulb_outline,
    blurb: 'Notas que você marcou como ideia',
    screen: _ideasScreen,
  ),
  ModuleDef(
    id: 'livros',
    label: 'LIVROS',
    icon: Icons.menu_book_outlined,
    blurb: 'Progresso de leitura',
    screen: _booksScreen,
    quickAdd: _addBook,
    addLabel: 'LIVRO',
  ),
  ModuleDef(
    id: 'agua',
    label: 'ÁGUA',
    icon: Icons.water_drop_outlined,
    blurb: 'Hidratação sem medir ao mililitro',
    screen: _waterScreen,
    quickAdd: _logWater,
    addLabel: 'ÁGUA (+200 ML)',
  ),
  ModuleDef(
    id: 'alimentacao',
    label: 'ALIMENTAÇÃO',
    icon: Icons.restaurant_outlined,
    blurb: 'Bloco de notas do que você comeu',
    screen: _foodScreen,
    quickAdd: _addMeal,
    addLabel: 'REFEIÇÃO',
  ),
  ModuleDef(
    id: 'exercicios',
    label: 'EXERCÍCIOS',
    icon: Icons.fitness_center,
    blurb: 'Rotinas que se repetem e treinos feitos',
    screen: _exerciseScreen,
    quickAdd: _addExercise,
    addLabel: 'EXERCÍCIO',
  ),
  ModuleDef(
    id: 'medicamentos',
    label: 'MEDICAMENTOS',
    icon: Icons.medication_outlined,
    blurb: 'Alarmes, horários e estoque',
    screen: _medScreen,
    quickAdd: _addMed,
    addLabel: 'MEDICAMENTO',
  ),
  ModuleDef(
    id: 'financas',
    label: 'FINANÇAS',
    icon: Icons.payments_outlined,
    blurb: 'Contas a pagar, vencimentos e gastos',
    screen: _financeScreen,
    quickAdd: _addFinance,
    addLabel: 'FINANÇAS (CONTA OU GASTO)',
  ),
];
