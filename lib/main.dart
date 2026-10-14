import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_state.dart';
import 'app/palette.dart';
import 'app/theme.dart';
import 'data/sqlite_store.dart';
import 'ui/home_shell.dart';
import 'ui/term_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
  final state = AppState();
  try {
    final store = await SqliteStore.open();
    state.attachStore(store);
    await state.load();
  } catch (e) {
    // Sem banco o app ainda abre, mas avisa que nada será salvo.
    state.storageError = 'Banco de dados indisponível: $e';
  }
  runApp(OrganizadorApp(state: state));
}

class OrganizadorApp extends StatefulWidget {
  const OrganizadorApp({super.key, required this.state});

  final AppState state;

  @override
  State<OrganizadorApp> createState() => _OrganizadorAppState();
}

class _OrganizadorAppState extends State<OrganizadorApp> {
  AppState get _state => widget.state;

  // O tema só é recalculado quando paleta ou efeitos mudam.
  AppPalette? _themePalette;
  EffectLevel? _themeEffects;
  ThemeData? _theme;

  ThemeData _themeFor(AppPalette p, EffectLevel fx) {
    if (_theme == null || _themePalette != p || _themeEffects != fx) {
      _theme = buildTheme(p, fx);
      _themePalette = p;
      _themeEffects = fx;
    }
    return _theme!;
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: Builder(
        builder: (context) {
          final s = AppScope.of(context);
          final p = s.palette;
          return MaterialApp(
            title: 'Organizador',
            debugShowCheckedModeBanner: false,
            theme: _themeFor(p, s.effects),
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: p.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child ?? const SizedBox.shrink(),
                  Positioned.fill(child: CrtOverlay(level: s.effects)),
                ],
              ),
            ),
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
