import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_store.dart';
import 'services/xtream_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      ),
      home: const SplashScreen(),
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(service: svc)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
            Text('DREAM', style: TextStyle(color: Color(0xFFE50914), fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: 8)),
            Text('SERVER', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300, letterSpacing: 12)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFE50914)),
          ],
        ),
      ),
    );
  }
}