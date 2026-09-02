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
  final _userFocus = FocusNode(debugLabel: 'user');
  final _passFocus = FocusNode(debugLabel: 'pass');
  final _btnFocus = FocusNode(debugLabel: 'btn');

  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Força o foco no campo usuário depois que a tela montar
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _userFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _btnFocus.dispose();
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

    bool ok;
    try {
      ok = await svc.authenticate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível conectar ao servidor. Verifique sua internet e tente novamente.';
      });
      return;
    }
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
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo_ds.jpg', height: 140, fit: BoxFit.contain),
                  const SizedBox(height: 36),

                  // ===== CAMPO USUÁRIO =====
                  _buildField(
                    controller: _userCtrl,
                    focusNode: _userFocus,
                    label: 'Usuário',
                    icon: Icons.person,
                    onSubmitted: (_) => _passFocus.requestFocus(),
                  ),

                  const SizedBox(height: 18),

                  // ===== CAMPO SENHA =====
                  _buildField(
                    controller: _passCtrl,
                    focusNode: _passFocus,
                    label: 'Senha',
                    icon: Icons.lock,
                    obscure: _obscure,
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
                    Text(_error!, style: const TextStyle(color: Color(0xFFE50914))),
                  ],

                  const SizedBox(height: 28),

                  // ===== BOTÃO ENTRAR =====
                  Focus(
                    focusNode: _btnFocus,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        _login();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(builder: (context) {
                      final hasFocus = Focus.of(context).hasFocus;
                      return GestureDetector(
                        onTap: _loading ? null : _login,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: hasFocus ? const Color(0xFFB0060F) : const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasFocus ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: hasFocus
                                ? [
                                    const BoxShadow(color: Colors.white54, blurRadius: 14, spreadRadius: 1),
                                    BoxShadow(
                                      color: const Color(0xFFE50914).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, color: Colors.white, size: hasFocus ? 22 : 18),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Entrar',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          // Seleciona todo o texto ao focar com OK/Enter
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(builder: (context) {
        final hasFocus = Focus.of(context).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFocus ? const Color(0xFFE50914) : const Color(0xFF2A2A2A),
              width: hasFocus ? 3 : 1.5,
            ),
            boxShadow: hasFocus
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: const Color(0xFFE50914),
            textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: hasFocus ? const Color(0xFFE50914) : Colors.grey,
                fontSize: hasFocus ? 15 : 14,
              ),
              prefixIcon: Icon(
                icon,
                color: hasFocus ? const Color(0xFFE50914) : Colors.grey,
                size: hasFocus ? 24 : 20,
              ),
              suffixIcon: suffix,
              filled: true,
              fillColor: hasFocus ? const Color(0xFF222222) : const Color(0xFF1A1A1A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );
      }),
    );
  }
}