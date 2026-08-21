import 'package:flutter/material.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);

/// Fonte diária de jogos — o servidor atualiza o conteúdo desse link
/// automaticamente todo dia.
const _sportsUrl = 'https://uploads.xui-managers.site/6480001-jogos.mp4';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  @override
  void initState() {
    super.initState();
    // Abre o player automaticamente (vídeo já rodando, sem precisar dar play)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PlayerScreen(
            title: 'Jogos de Hoje',
            url: _sportsUrl,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esportes',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Jogos do dia — toque para assistir',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlayerScreen(
                      title: 'Jogos de Hoje',
                      url: _sportsUrl,
                    ),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text('Assistir Jogos de Hoje',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Inicia automaticamente ao abrir',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
