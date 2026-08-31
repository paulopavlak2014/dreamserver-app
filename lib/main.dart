import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'services/auth_store.dart';
import 'services/xtream_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DreamServerApp());
}

class DreamServerApp extends StatelessWidget {
  const DreamServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamServer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE50914)),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF141414),
          indicatorColor: const Color(0xFFE50914),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        focusColor: const Color(0xFFE50914).withOpacity(0.35),
        highlightColor: const Color(0xFFE50914).withOpacity(0.2),
      ),
      home: const _AppShell(),
    );
  }
}

/// Shell global que intercepta teclas do controle remoto
/// e repassa como eventos de foco para o Flutter
class _AppShell extends StatefulWidget {
  const _AppShell();
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final FocusNode _rootFocus = FocusNode();

  @override
  void dispose() {
    _rootFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Mapeia teclas do controle remoto Firestick/TV Box
    final key = event.logicalKey;

    // D-pad e teclas de navegação — deixa o Flutter processar normalmente
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored; // Flutter gerencia navegação
    }

    // OK / Enter / Select / Centro do D-pad
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.mediaSelect) {
      // Simula ativação no widget focado
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null) {
        Actions.maybeInvoke(focused.context!, const ActivateIntent());
      }
      return KeyEventResult.ignored;
    }

    // Botão Voltar / Back
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      final nav = Navigator.of(context, rootNavigator: false);
      if (nav.canPop()) {
        nav.pop();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 1));
    final saved = await AuthStore.load();
    if (!mounted) return;
    if (saved != null) {
      final svc = XtreamService(username: saved['user']!, password: saved['pass']!);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomeScreen(service: svc)));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('DREAM',
                style: TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8)),
            Text('SERVER',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 12)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFE50914)),
          ],
        ),
      ),
    );
  }
}
