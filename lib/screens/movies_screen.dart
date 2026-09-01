import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<Movie> _all = [];
  List<Category> _categories = [];
  String _selectedCat = '';
  String _search = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final _gridFocusNode = FocusNode();

  int _focusedIndex = -1;
  int _columnCount = 4;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() {
        _search = _searchCtrl.text.toLowerCase();
        _focusedIndex = -1;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _gridFocusNode.dispose();
    super.dispose();
  }

  /// Chama este método para focar o primeiro item do grid (usado ao trocar de aba)
  void focusGrid() {
    _gridFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusedIndex < 0) {
        setState(() => _focusedIndex = 0);
      }
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
        _gridFocusNode.requestFocus();
        setState(() => _focusedIndex = 0);
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

  int _calcColumns(double width) {
    final padding = 12.0 * 2;
    final available = width - padding;
    return (available / (150 + 12)).floor().clamp(2, 999);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _columnCount = _calcColumns(constraints.maxWidth);
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
                          _focusedIndex = 0;
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
                      : _buildGrid(items),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(List<Movie> items) {
    final cols = _columnCount;
    final totalRows = (items.length / cols).ceil();
    final focusedRow = _focusedIndex >= 0 ? _focusedIndex ~/ cols : 0;
    final scrollOffset = focusedRow * 170.0;

    return Focus(
      focusNode: _gridFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        if (_focusedIndex < 0) {
          if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
            setState(() => _focusedIndex = 0);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        if (key == LogicalKeyboardKey.arrowRight) {
          if (_focusedIndex + 1 < items.length) {
            setState(() => _focusedIndex = _focusedIndex + 1);
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowLeft) {
          if (_focusedIndex % cols == 0) {
            return KeyEventResult.ignored;
          }
          setState(() => _focusedIndex = _focusedIndex - 1);
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowDown) {
          final next = _focusedIndex + cols;
          if (next < items.length) {
            setState(() => _focusedIndex = next);
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowUp) {
          if (_focusedIndex >= cols) {
            setState(() => _focusedIndex = _focusedIndex - cols);
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space) {
          final m = items[_focusedIndex];
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)));
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: GridView.builder(
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
          isFocused: _focusedIndex == i,
          onOpen: () {
            final m = items[i];
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)));
          },
        ),
      ),
    );
  }
}

class _MovieTile extends StatefulWidget {
  final Movie movie;
  final bool isFocused;
  final VoidCallback onOpen;

  const _MovieTile({
    super.key,
    required this.movie,
    required this.isFocused,
    required this.onOpen,
  });

  @override
  State<_MovieTile> createState() => _MovieTileState();
}

class _MovieTileState extends State<_MovieTile> {
  bool _isFav = false;

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
    final focused = widget.isFocused;

    return GestureDetector(
      onTap: widget.onOpen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: focused ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: focused ? _kRed : Colors.transparent,
            width: 3,
          ),
          boxShadow: focused
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
            if (focused)
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
                      fontWeight: focused ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            if (focused)
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
    );
  }
}
