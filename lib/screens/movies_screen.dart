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
  State<MoviesScreen> createState() => MoviesScreenState();
}

class MoviesScreenState extends State<MoviesScreen> {
  List<Movie> _all = [];
  List<Category> _categories = [];
  String _selectedCat = '';
  String _search = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final Map<int, FocusNode> _focusNodes = {};
  final _gridScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _gridScrollCtrl.dispose();
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(int i) {
    return _focusNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'movie_$i'));
  }

  /// Foca o primeiro filme (chamado ao trocar de aba)
  void focusGrid() {
    if (_loading || _filtered.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _filtered.isEmpty) return;
      _nodeFor(0).requestFocus();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      widget.service.getMovies(),
      widget.service.getVodCategories(),
    ]);

    if (!mounted) return;

    setState(() {
      _all = results[0] as List<Movie>;
      _categories = results[1] as List<Category>;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filtered.isNotEmpty) {
        _nodeFor(0).requestFocus();
      }
    });
  }

  List<Movie> get _filtered {
    var list = _all;
    if (_selectedCat.isNotEmpty) {
      list = list.where((m) => m.categoryId == _selectedCat).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((m) => m.name.toLowerCase().contains(_search)).toList();
    }
    return list;
  }

  void _openMovie(Movie m) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            const Text('Filmes',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${items.length} filmes', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
              onPressed: _load,
              tooltip: 'Recarregar',
            ),
          ]),
        ),
        if (_categories.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length + 1,
              itemBuilder: (_, i) {
                final isAll = i == 0;
                final cat = isAll ? null : _categories[i - 1];
                final active = isAll ? _selectedCat.isEmpty : _selectedCat == cat!.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(isAll ? 'Todos' : cat!.name,
                        style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 11)),
                    selected: active,
                    onSelected: (_) => setState(() {
                      _selectedCat = isAll ? '' : cat!.id;
                    }),
                    selectedColor: _kRed,
                    backgroundColor: const Color(0xFF1E1E1E),
                    side: BorderSide(color: active ? _kRed : Colors.white12),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: _kRed),
                    SizedBox(height: 16),
                    Text('Carregando filmes...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                )
              : items.isEmpty
                  ? const Center(child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      controller: _gridScrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2 / 3,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _MovieTile(
                        key: ValueKey('movie_${items[i].id}_$i'),
                        movie: items[i],
                        focusNode: _nodeFor(i),
                        onOpen: () => _openMovie(items[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _MovieTile extends StatefulWidget {
  final Movie movie;
  final FocusNode focusNode;
  final VoidCallback onOpen;

  const _MovieTile({
    super.key,
    required this.movie,
    required this.focusNode,
    required this.onOpen,
  });

  @override
  State<_MovieTile> createState() => _MovieTileState();
}

class _MovieTileState extends State<_MovieTile> {
  bool _isFav = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FavoritesService.isFavorite(widget.movie.streamUrl)
        .then((v) { if (mounted) setState(() => _isFav = v); });
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

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) { widget.onOpen(); return null; },
        ),
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused ? _kRed : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(color: _kRed.withOpacity(0.4), blurRadius: 12, spreadRadius: 2),
                    const BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 2),
                  ]
                : [const BoxShadow(color: Colors.black38, blurRadius: 4)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(fit: StackFit.expand, children: [
              m.cover != null
                  ? CachedNetworkImage(
                      imageUrl: m.cover!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.movie, color: Colors.grey, size: 32),
                      ))
                  : Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.movie, color: Colors.grey, size: 32)),
              if (_focused)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kRed.withOpacity(0.15), Colors.transparent],
                    ),
                  ),
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
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(m.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              if (_focused)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('▶', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}