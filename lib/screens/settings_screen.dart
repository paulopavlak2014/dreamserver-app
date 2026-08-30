import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_store.dart';
import '../services/xtream_service.dart';
import '../services/player_prefs.dart';
import 'login_screen.dart';

const _kRed = Color(0xFFE50914);

class SettingsScreen extends StatefulWidget {
  final XtreamService service;
  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _player = 'internal';
  bool _refreshing = false;

  final _m3uCtrl = TextEditingController();
  bool _savingM3u = false;

  @override
  void initState() {
    super.initState();
    PlayerPrefs.get().then((v) {
      if (mounted) setState(() => _player = v);
    });
    _loadM3u();
  }

  Future<void> _loadM3u() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('m3u_url') ?? '';
    if (mounted) _m3uCtrl.text = saved;
  }

  Future<void> _saveM3u() async {
    setState(() => _savingM3u = true);
    final prefs = await SharedPreferences.getInstance();
    final url = _m3uCtrl.text.trim();
    await prefs.setString('m3u_url', url);
    setState(() => _savingM3u = false);
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(url.isEmpty ? 'Lista M3U removida' : 'Lista M3U salva'),
      backgroundColor: const Color(0xFF1A1A1A),
    ));
  }

  @override
  void dispose() {
    _m3uCtrl.dispose();
    super.dispose();
  }

  Future<void> _setPlayer(String v) async {
    await PlayerPrefs.set(v);
    setState(() => _player = v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Player: ${PlayerPrefs.options.firstWhere((e) => e.$1 == v).$2}'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
  }

  Future<void> _refreshContent() async {
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        widget.service.getLiveChannels(),
        widget.service.getMovies(),
        widget.service.getSeries(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conteúdos atualizados. Volte nas abas para ver a lista nova.'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sair da conta', style: TextStyle(color: Colors.white)),
        content: const Text('Tem certeza que deseja sair?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair',
                  style: TextStyle(color: _kRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm == true) {
      await AuthStore.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keep = {'user', 'pass', 'favorites_v1', 'preferred_player', 'm3u_url'};
    for (final k in prefs.getKeys().toList()) {
      if (!keep.contains(k)) await prefs.remove(k);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache limpo'), backgroundColor: Color(0xFF1A1A1A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configurações',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            _SectionCard(children: [
              _InfoRow(icon: Icons.person, label: 'Usuário', value: widget.service.username),
              const Divider(color: Color(0xFF2A2A2A), height: 24),
              _InfoRow(icon: Icons.dns_rounded, label: 'Servidor', value: XtreamService.baseUrl),
            ]),
            const SizedBox(height: 16),

            const Text('Lista M3U adicional', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            _SectionCard(children: [
              const Text(
                'Cole a URL de uma lista M3U para adicionar canais extras na aba TV Ao Vivo.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _m3uCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'http://servidor.com/lista.m3u',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F0F0F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.list_alt_rounded, color: Colors.white38, size: 18),
                  suffixIcon: _m3uCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () {
                            _m3uCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _TvFocusButton(
                  onTap: _savingM3u ? null : _saveM3u,
                  child: _savingM3u
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Salvar lista M3U',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            const Text('Player', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            _SectionCard(children: [
              for (var i = 0; i < PlayerPrefs.options.length; i++) ...[
                if (i > 0) const Divider(color: Color(0xFF2A2A2A), height: 16),
                _PlayerOption(
                  label: PlayerPrefs.options[i].$2,
                  selected: _player == PlayerPrefs.options[i].$1,
                  onTap: () => _setPlayer(PlayerPrefs.options[i].$1),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            _SectionCard(children: [
              _ActionRow(
                icon: Icons.sync_rounded,
                label: _refreshing ? 'Atualizando...' : 'Atualizar conteúdos',
                color: Colors.white,
                onTap: _refreshing ? null : _refreshContent,
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 24),
              _ActionRow(
                icon: Icons.cleaning_services_rounded,
                label: 'Limpar cache',
                color: Colors.white,
                onTap: _clearCache,
              ),
              const Divider(color: Color(0xFF2A2A2A), height: 24),
              _ActionRow(
                icon: Icons.logout_rounded,
                label: 'Sair da conta',
                color: _kRed,
                onTap: _confirmLogout,
              ),
            ]),
            const SizedBox(height: 24),
            const Center(
              child: Text('DreamServer IPTV', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão com foco para TV ──────────────────────────────────────────────────

class _TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _TvFocusButton({required this.child, this.onTap});

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? Colors.white24 : _kRed,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

class _PlayerOption extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PlayerOption({required this.label, required this.selected, required this.onTap});

  @override
  State<_PlayerOption> createState() => _PlayerOptionState();
}

class _PlayerOptionState extends State<_PlayerOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _focused ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Icon(
                widget.selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: widget.selected ? _kRed : Colors.grey,
                size: 20),
            const SizedBox(width: 12),
            Text(widget.label,
                style: TextStyle(
                    color: widget.selected ? Colors.white : Colors.grey, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.grey, size: 20),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const Spacer(),
      Flexible(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right)),
    ]);
  }
}

class _ActionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, this.onTap});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
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
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: _focused ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Icon(widget.icon, color: widget.color, size: 20),
            const SizedBox(width: 12),
            Text(widget.label,
                style: TextStyle(color: widget.color, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
