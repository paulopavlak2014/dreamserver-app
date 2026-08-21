import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../services/favorites_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);

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
      setState(() => _filtered = q.isEmpty
          ? _movies
          : _movies.where((m) => m.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getMovies();
    setState(() {
      _movies = data;
      _filtered = data;
      _loading = false;
    });
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _kRed),
                      SizedBox(height: 16),
                      Text('Carregando filmes por categoria...',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('Pode levar 1–3 minutos na 1ª vez',
                          style: TextStyle(color: Colors.white24, fontSize: 11)),
                    ],
                  ),
                )
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
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
                        return _MovieTile(movie: m);
                      },
                    ),
        ),
      ],
    );
  }
}

class _MovieTile extends StatefulWidget {
  final Movie movie;
  const _MovieTile({required this.movie});

  @override
  State<_MovieTile> createState() => _MovieTileState();
}

class _MovieTileState extends State<_MovieTile> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await FavoritesService.isFavorite(widget.movie.streamUrl);
    if (mounted) setState(() => _isFav = ok);
  }

  Future<void> _toggleFav() async {
    await FavoritesService.toggle({
      'id': widget.movie.id,
      'title': widget.movie.name,
      'url': widget.movie.streamUrl,
      'type': 'movie',
      'category': widget.movie.categoryId ?? '',
    });
    if (mounted) setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            m.cover != null
                ? CachedNetworkImage(
                    imageUrl: m.cover!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.movie, color: Colors.grey, size: 32),
                    ),
                  )
                : Container(
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(Icons.movie, color: Colors.grey, size: 32),
                  ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _isFav ? Colors.amber : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  m.name,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
