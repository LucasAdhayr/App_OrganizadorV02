import 'package:flutter/material.dart';

import '../ui/screens/date_form_screen.dart';
import '../ui/screens/dates_screen.dart';
import '../ui/screens/inbox_screen.dart';
import '../ui/screens/task_form_screen.dart';
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

  /// Nome do tipo no menu "+". Nulo = não aparece no menu.
  final String? addLabel;

  bool get ready => screen != null;
}

Widget _tasksScreen(BuildContext context) => const TasksModuleScreen();
Widget _taskForm(BuildContext context) => const TaskFormScreen();
Widget _datesScreen(BuildContext context) => const DatesScreen();
Widget _dateForm(BuildContext context) => const DateFormScreen();
Widget _ideasScreen(BuildContext context) => const IdeasScreen();

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
    addLabel: 'LIVRO',
  ),
  ModuleDef(
    id: 'agua',
    label: 'ÁGUA',
    icon: Icons.water_drop_outlined,
    blurb: 'Hidratação sem medir ao mililitro',
    addLabel: 'REGISTRO DE ÁGUA',
  ),
  ModuleDef(
    id: 'alimentacao',
    label: 'ALIMENTAÇÃO',
    icon: Icons.restaurant_outlined,
    blurb: 'Bloco de notas do que você comeu',
    addLabel: 'REFEIÇÃO',
  ),
  ModuleDef(
    id: 'exercicios',
    label: 'EXERCÍCIOS',
    icon: Icons.fitness_center,
    blurb: 'Treinos e esportes',
    addLabel: 'EXERCÍCIO',
  ),
  ModuleDef(
    id: 'medicamentos',
    label: 'MEDICAMENTOS',
    icon: Icons.medication_outlined,
    blurb: 'Horários e estoque',
    addLabel: 'MEDICAMENTO',
  ),
  ModuleDef(
    id: 'financas',
    label: 'FINANÇAS',
    icon: Icons.payments_outlined,
    blurb: 'Contas a pagar e vencimentos',
    addLabel: 'CONTA A PAGAR',
  ),
];
