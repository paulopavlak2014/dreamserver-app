import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    PlayerPrefs.get().then((v) {
      if (mounted) setState(() => _player = v);
    });
  }

  Future<void> _setPlayer(String v) async {
    await PlayerPrefs.set(v);
    setState(() => _player = v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player: ${PlayerPrefs.options.firstWhere((e) => e.$1 == v).$2}'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
  }

  Future<void> _refreshContent() async {
    setState(() => _refreshing = true);
    try {
      // Força novas buscas no servidor (só valida se API responde)
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
        content: const Text(
          'Tem certeza que deseja sair?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair', style: TextStyle(color: _kRed, fontWeight: FontWeight.bold))),
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
    final keep = {'user', 'pass', 'favorites_v1', 'preferred_player'};
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
            const Center(child: Text('DreamServer IPTV', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _PlayerOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PlayerOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? _kRed : Colors.grey, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: selected ? Colors.white : Colors.grey, fontSize: 14)),
      ]),
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
      Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
