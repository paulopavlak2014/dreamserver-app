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
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _loginFocus = FocusNode();

  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Coloca o foco no campo Usuário assim que a tela abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final svc = XtreamService(
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );

    final ok = await svc.authenticate();
    if (!mounted) return;

    if (ok) {
      await AuthStore.save(_userCtrl.text.trim(), _passCtrl.text.trim());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(service: svc)),
      );
    } else {
      setState(() {
        _error = 'Usuário ou senha inválidos.';
        _loading = false;
      });
      _userFocus.requestFocus();
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_ds.jpg',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // Campo Usuário
                _TvTextField(
                  controller: _userCtrl,
                  focusNode: _userFocus,
                  label: 'Usuário',
                  icon: Icons.person,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passFocus.requestFocus(),
                ),

                const SizedBox(height: 18),

                // Campo Senha
                _TvTextField(
                  controller: _passCtrl,
                  focusNode: _passFocus,
                  label: 'Senha',
                  icon: Icons.lock,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Botão Entrar
                _LoginButton(
                  focusNode: _loginFocus,
                  loading: _loading,
                  onPressed: _loading ? null : _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Campo de texto otimizado para TV / controle remoto
// ─────────────────────────────────────────────────────────────
class _TvTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _TvTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus ? const Color(0xFFE50914) : Colors.transparent,
                width: 3,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: const Color(0xFFE50914),
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: hasFocus ? const Color(0xFFE50914) : Colors.grey,
                ),
                prefixIcon: Icon(
                  icon,
                  color: hasFocus ? const Color(0xFFE50914) : Colors.grey,
                ),
                suffixIcon: suffix,
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Botão Entrar otimizado para TV
// ─────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback? onPressed;

  const _LoginButton({
    required this.focusNode,
    required this.loading,
    this.onPressed,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: hasFocus
                    ? [
                        const BoxShadow(
                          color: Colors.white38,
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: widget.loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}