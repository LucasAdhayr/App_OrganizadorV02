import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/palette.dart';
import 'screens/agenda_screen.dart';
import 'screens/history_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/modules_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/today_screen.dart';
import 'sheets.dart';
import 'term_widgets.dart';

/// Moldura principal: histórico (esquerda) e configurações (direita) no topo,
/// e a barra HOJE · AGENDA · [+] · ENTRADA · MÓDULOS embaixo.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const List<String> _titles = ['HOJE', 'AGENDA', 'ENTRADA', 'MÓDULOS'];
  static const List<Widget> _screens = [
    TodayScreen(),
    AgendaScreen(),
    InboxScreen(),
    ModulesScreen(),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mantém o relógio e os atrasos em dia sem o usuário precisar fazer nada.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final s = AppScope.read(context);
      s.tick();
      s.replan(); // o limite de 50 lembretes avança com o tempo
      s.backup?.runAutoIfDue();
    });
    // Backup automático: ao abrir, se já passou das 23:00 sem backup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).backup?.runAutoIfDue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final s = AppScope.read(context);
      s.tick();
      s.backup?.runAutoIfDue();
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TermTopBar(
              leading: IconButton(
                tooltip: 'Histórico',
                icon: const Icon(Icons.history),
                onPressed: () => _push(const HistoryScreen()),
              ),
              title: _titles[_index],
              trailing: IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _push(const SettingsScreen()),
              ),
            ),
            if (AppScope.of(context).storageError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppScope.of(context).palette.surface,
                child: Text(
                  '[!] ${AppScope.of(context).storageError}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(child: IndexedStack(index: _index, children: _screens)),
          ],
        ),
      ),
      bottomNavigationBar: TermNavBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onAdd: () => showAddSheet(context),
      ),
    );
  }
}

class TermNavBar extends StatelessWidget {
  const TermNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;

    Widget item(int i, String label, IconData icon) => Expanded(
          child: _NavItem(
            label: label,
            icon: icon,
            selected: index == i,
            onTap: () => onSelect(i),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.dim.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              item(0, 'HOJE', Icons.today),
              item(1, 'AGENDA', Icons.event_note),
              Expanded(child: Center(child: _AddButton(onTap: onAdd))),
              item(2, 'ENTRADA', Icons.inbox),
              item(3, 'MÓDULOS', Icons.apps),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    // Selecionado = vídeo invertido; a informação não depende só de cor.
    final color = selected ? p.bg : p.dim;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          color: selected ? p.fg : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    shadows: selected ? const <Shadow>[] : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.palette;
    return Semantics(
      button: true,
      label: 'Registrar',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: p.fg,
            boxShadow: s.effects == EffectLevel.off
                ? null
                : [BoxShadow(color: p.fg.withValues(alpha: 0.35), blurRadius: 10)],
          ),
          child: Icon(Icons.add, size: 32, color: p.bg),
        ),
      ),
    );
  }
}
