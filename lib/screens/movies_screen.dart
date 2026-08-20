import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

class MoviesScreen extends StatefulWidget {
  final XtreamService service;
  const MoviesScreen({super.key, required this.service});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Movie> _movies = [];
  List<Movie> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty ? _movies : _movies.where((m) => m.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getMovies();
    setState(() { _movies = data; _filtered = data; _loading = false; });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar filme...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
              : _filtered.isEmpty
                  ? const Center(child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.grey)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Tamanho de capa fixo (110px) — mais colunas em telas
                        // grandes (TV/tablet), menos em celular. Evita capas
                        // gigantes em qualquer tamanho de tela.
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 110,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final m = _filtered[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl),
                              )),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    m.cover != null
                                        ? CachedNetworkImage(imageUrl: m.cover!, fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A),
                                              child: const Icon(Icons.movie, color: Colors.grey, size: 32)))
                                        : Container(color: const Color(0xFF1A1A1A),
                                            child: const Icon(Icons.movie, color: Colors.grey, size: 32)),
                                    Positioned(
                                      bottom: 0, left: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [Colors.black87, Colors.transparent],
                                          ),
                                        ),
                                        child: Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 10),
                                            maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
