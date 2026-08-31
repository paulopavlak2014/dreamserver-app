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

  // Força orientação landscape (TV)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Remove barra de status / navegação (melhor em TV)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
        focusColor: const Color(0xFFE50914),
        highlightColor: const Color(0xFFE50914).withOpacity(0.25),
        // Importante para TV: mostra claramente o foco
        visualDensity: VisualDensity.comfortable,
      ),
      home: const _AppShell(),
    );
  }
}

/// Shell global que captura teclas do controle remoto
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final FocusNode _rootFocus = FocusNode(debugLabel: 'RootFocus');

  @override
  void dispose() {
    _rootFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // === Setas do D-pad → deixa o Flutter navegar normalmente ===
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }

    // === OK / Select / Enter / Centro do D-pad ===
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null && focused.context != null) {
        // Tenta ativar o widget focado
        final result = Actions.maybeInvoke(
          focused.context!,
          const ActivateIntent(),
        );
        if (result != null) {
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // === Botão Voltar (Back) ===
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.backspace) {
      final navigator = Navigator.of(context, rootNavigator: false);
      if (navigator.canPop()) {
        navigator.pop();
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
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final saved = await AuthStore.load();
    if (!mounted) return;

    if (saved != null) {
      final svc = XtreamService(
        username: saved['user']!,
        password: saved['pass']!,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(service: svc)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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
            Text(
              'DREAM',
              style: TextStyle(
                color: Color(0xFFE50914),
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
            Text(
              'SERVER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 12,
              ),
            ),
            SizedBox(height: 36),
            CircularProgressIndicator(color: Color(0xFFE50914)),
          ],
        ),
      ),
    );
  }
}