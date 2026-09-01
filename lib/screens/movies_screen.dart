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
  State<MoviesScreen> createState() => MoviesScreenState();
}

class MoviesScreenState extends State<MoviesScreen> {
  List<Movie> _all = [];
  List<Category> _categories = [];
  String _selectedCat = '';
  String _search = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final _gridFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  int _focusedIndex = -1;
  int _columns = 4;

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
    _gridFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Foca o primeiro filme (chamado ao trocar de aba)
  void focusGrid() {
    if (_loading || _filtered.isEmpty) return;
    setState(() => _focusedIndex = 0);
    _gridFocus.requestFocus();
    _scrollToFocused();
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
      _focusedIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filtered.isNotEmpty) {
        _gridFocus.requestFocus();
        _scrollToFocused();
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
    final available = width - 24;
    return (available / 162).floor().clamp(2, 6);
  }

  void _scrollToFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedIndex < 0) return;
      final row = _focusedIndex ~/ _columns;
      final target = row * 240.0;
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  KeyEventResult _handleGridKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final items = _filtered;
    if (items.isEmpty) return KeyEventResult.ignored;

    if (_focusedIndex < 0) _focusedIndex = 0;

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_focusedIndex + 1 < items.length) {
        setState(() => _focusedIndex++);
        _scrollToFocused();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusedIndex % _columns == 0) {
        return KeyEventResult.ignored; // borda esquerda -> menu lateral
      }
      setState(() => _focusedIndex--);
      _scrollToFocused();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = _focusedIndex + _columns;
      if (next < items.length) {
        setState(() => _focusedIndex = next);
        _scrollToFocused();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex >= _columns) {
        setState(() => _focusedIndex -= _columns);
        _scrollToFocused();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // topo -> categorias
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _openMovie(items[_focusedIndex]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openMovie(Movie m) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _columns = _calcColumns(constraints.maxWidth);
        final items = _filtered;
        final rows = (items.length / _columns).ceil();

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
                          _scrollToFocused();
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
                      : Focus(
                          focusNode: _gridFocus,
                          autofocus: true,
                          onKeyEvent: (node, event) => _handleGridKey(event),
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                            itemCount: rows,
                            itemBuilder: (_, row) {
                              final start = row * _columns;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    for (var col = 0; col < _columns; col++) ...[
                                      if (col > 0) const SizedBox(width: 12),
                                      if (start + col < items.length)
                                        Expanded(
                                          child: _MovieTile(
                                            movie: items[start + col],
                                            isFocused: _focusedIndex == start + col,
                                            onOpen: () => _openMovie(items[start + col]),
                                          ),
                                        )
                                      else
                                        const Expanded(child: SizedBox()),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
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
        height: 180,
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