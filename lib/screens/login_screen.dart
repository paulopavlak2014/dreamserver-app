import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/xtream_service.dart';
import '../services/auth_store.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    final svc = XtreamService(username: _userCtrl.text.trim(), password: _passCtrl.text.trim());
    final ok = await svc.authenticate();
    if (!mounted) return;
    if (ok) {
      await AuthStore.save(_userCtrl.text.trim(), _passCtrl.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(service: svc)));
    } else {
      setState(() { _error = 'Usuário ou senha inválidos.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo_ds.jpg', height: 160, fit: BoxFit.contain),
                const SizedBox(height: 40),
                _TvField(ctrl: _userCtrl, label: 'Usuário', icon: Icons.person,
                    onSubmit: () => FocusScope.of(context).nextFocus()),
                const SizedBox(height: 16),
                _TvField(
                  ctrl: _passCtrl,
                  label: 'Senha',
                  icon: Icons.lock,
                  obscure: _obscure,
                  onSubmit: _loading ? null : _login,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFE50914))),
                ],
                const SizedBox(height: 24),
                _LoginButton(loading: _loading, onTap: _loading ? null : _login),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botão Entrar com foco TV ─────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _LoginButton({required this.loading, this.onTap});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [const BoxShadow(color: Colors.white24, blurRadius: 8, spreadRadius: 2)]
                : [],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Entrar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}

// ── Campo de texto com foco TV ───────────────────────────────────────────────
class _TvField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final VoidCallback? onSubmit;

  const _TvField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      onSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE50914), width: 2),
        ),
      ),
    );
  }
}
