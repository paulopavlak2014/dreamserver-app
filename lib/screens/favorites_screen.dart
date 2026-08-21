import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);
const _kCard = Color(0xFF161616);

class FavoritesScreen extends StatefulWidget {
  final XtreamService? service;
  const FavoritesScreen({super.key, this.service});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, String>> _favs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await FavoritesService.load();
    if (mounted) setState(() { _favs = favs; _loading = false; });
  }

  Future<void> _remove(Map<String, String> item) async {
    await FavoritesService.toggle(item);
    await _load();
  }

  void _play(Map<String, String> item) {
    final url = item['url'] ?? '';
    final type = item['type'] ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL do favorito inválida'), backgroundColor: Colors.red),
      );
      return;
    }
    if (type == 'serie' || url.startsWith('series:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abra Séries no menu e busque pelo nome para assistir'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: item['title'] ?? '',
          url: url,
          channelId: item['id'],
          service: widget.service,
        ),
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'live':  return Icons.live_tv_rounded;
      case 'movie': return Icons.movie_rounded;
      case 'serie': return Icons.tv_rounded;
      default:      return Icons.play_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Favoritos',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_favs.length} item${_favs.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kRed)))
          else if (_favs.isEmpty)
            Expanded(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.star_border_rounded, color: Colors.grey.shade700, size: 56),
                  const SizedBox(height: 16),
                  const Text('Nenhum favorito ainda',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Toque na estrela ⭐ em qualquer canal',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _favs.length,
                itemBuilder: (_, i) {
                  final item = _favs[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _play(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _kRed.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconForType(item['type']), color: _kRed, size: 20),
                          ),
                          title: Text(item['title'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: item['category'] != null && item['category']!.isNotEmpty
                              ? Text(item['category']!,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11))
                              : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.play_circle_fill, color: _kRed, size: 28),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                              onPressed: () => _remove(item),
                              splashRadius: 18,
                            ),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
