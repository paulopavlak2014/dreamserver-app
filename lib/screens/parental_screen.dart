import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kRed = Color(0xFFE50914);
const _kCard = Color(0xFF161616);
const _kSurface = Color(0xFF1E1E1E);

class ParentalScreen extends StatefulWidget {
  const ParentalScreen({super.key});

  @override
  State<ParentalScreen> createState() => _ParentalScreenState();
}

class _ParentalScreenState extends State<ParentalScreen> {
  static const _pinKey = 'parental_pin';
  static const _enabledKey = 'parental_enabled';

  bool _enabled = false;
  bool _pinSet = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey) ?? '';
    setState(() {
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _pinSet = pin.isNotEmpty;
    });
  }

  Future<void> _savePin() async {
    final pin = _newPinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();

    if (pin.length != 4) {
      _showSnack('O PIN precisa ter exatamente 4 dígitos', isError: true);
      return;
    }
    if (pin != confirm) {
      _showSnack('Os PINs não coincidem', isError: true);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_enabledKey, true);
    _newPinCtrl.clear();
    _confirmPinCtrl.clear();
    _load();
    _showSnack('PIN salvo! Controle parental ativado.');
  }

  Future<void> _toggleEnabled(bool val) async {
    // Pede confirmação com PIN atual
    final confirmed = await _askPin();
    if (!confirmed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, val);
    setState(() => _enabled = val);
    _showSnack(val ? 'Controle parental ativado' : 'Controle parental desativado');
  }

  Future<void> _removePin() async {
    final confirmed = await _askPin();
    if (!confirmed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_enabledKey, false);
    _load();
    _showSnack('PIN removido. Controle parental desativado.');
  }

  /// Exibe dialog pedindo o PIN atual. Retorna true se correto.
  Future<bool> _askPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey) ?? '';
    final ctrl = TextEditingController();
    bool? result;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: const Text('Confirme seu PIN', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _kCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { result = false; Navigator.pop(ctx); },
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            onPressed: () {
              result = ctrl.text == savedPin;
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == false && mounted) {
      _showSnack('PIN incorreto', isError: true);
    }
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Controle Parental',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            const Text('Proteja conteúdo adulto com um PIN de 4 dígitos.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 28),

            // Status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: (_enabled ? _kRed : Colors.grey).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: _enabled ? _kRed : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _enabled ? 'Ativado' : 'Desativado',
                      style: TextStyle(
                          color: _enabled ? Colors.white : Colors.grey,
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _pinSet ? 'PIN definido' : 'Defina um PIN abaixo para ativar',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ]),
                ),
                Switch(
                  value: _enabled,
                  activeColor: _kRed,
                  onChanged: _pinSet ? _toggleEnabled : null,
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // Definir PIN
            const Text('DEFINIR / ALTERAR PIN',
                style: TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _PinField(
                  controller: _newPinCtrl,
                  hint: 'Novo PIN (4 dígitos)',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 10),
                _PinField(
                  controller: _confirmPinCtrl,
                  hint: 'Confirmar PIN',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _savePin,
                    child: Text(_pinSet ? 'Alterar PIN' : 'Salvar PIN',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),

            if (_pinSet) ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: _removePin,
                  icon: const Icon(Icons.no_encryption_gae_rounded, color: Colors.grey, size: 18),
                  label: const Text('Remover PIN e desativar',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ),
            ],

            const SizedBox(height: 32),
            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withOpacity(0.2)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: _kRed, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quando ativado, canais e conteúdos marcados como adulto '
                    'serão bloqueados e exigirão o PIN para acesso.',
                    style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PinField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 18),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 0),
        filled: true,
        fillColor: const Color(0xFF0D0D0D),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey, size: 18),
          onPressed: onToggle,
        ),
      ),
    );
  }
}