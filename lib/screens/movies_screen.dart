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

  // Índice focado no grid (-1 = nenhum)
  int _focusedIndex = -1;

  // Mapa de índice → FocusNode
  final Map<int, FocusNode> _focusNodes = {};

  // Número de colunas atual (calculado no build)
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
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(int index) {
    if (!_focusNodes.containsKey(index)) {
      _focusNodes[index] = FocusNode(debugLabel: 'movie_$index');
    }
    return _focusNodes[index]!;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Limpa focus nodes ao recarregar
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _focusedIndex = -1;

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

  /// Calcula quantas colunas cabem com maxCrossAxisExtent=110
  int _calcColumns(double width) {
    final padding = 12.0 * 2;
    final available = width - padding;
    return (available / (110 + 10)).floor().clamp(1, 999);
  }

  // Move foco para [newIndex], retorna true se conseguiu
  bool _moveFocus(int newIndex, List<Movie> items) {
    if (newIndex < 0 || newIndex >= items.length) return false;
    setState(() => _focusedIndex = newIndex);
    // Solicita foco no próximo frame (o node precisa existir no tree)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _nodeFor(newIndex);
      if (node.context != null) node.requestFocus();
    });
    return true;
  }

  KeyEventResult _handleGridKey(KeyEvent event, int index, List<Movie> items) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final cols = _columnCount;

    if (key == LogicalKeyboardKey.arrowRight) {
      // Último da linha → para aí (não volta para menu)
      if ((index + 1) % cols == 0 || index + 1 >= items.length) {
        return KeyEventResult.handled; // bloqueia, não faz nada
      }
      _moveFocus(index + 1, items);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      // Primeiro da linha → volta para menu lateral
      if (index % cols == 0) {
        return KeyEventResult.ignored; // deixa o Flutter navegar para o menu
      }
      _moveFocus(index - 1, items);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + cols;
      if (next >= items.length) return KeyEventResult.handled; // bloqueia saída
      _moveFocus(next, items);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index < cols) return KeyEventResult.handled; // primeira linha → bloqueia
      _moveFocus(index - cols, items);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
                  width: 3, height: 16,
                  decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                const Text('Filmes',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${items.length} filmes',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                  onPressed: _load,
                  tooltip: 'Recarregar',
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar filme...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
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
                          _focusedIndex = -1;
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
                        Text('Carregando filmes...',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('Pode levar alguns instantes',
                            style: TextStyle(color: Colors.white24, fontSize: 11)),
                      ]),
                    )
                  : items.isEmpty
                      ? const Center(
                          child: Text('Nenhum filme encontrado',
                              style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 110,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _MovieTile(
                            key: ValueKey('movie_${items[i].id}_$i'),
                            movie: items[i],
                            focusNode: _nodeFor(i),
                            isFocused: _focusedIndex == i,
                            onFocusChange: (focused) {
                              if (focused) {
                                setState(() => _focusedIndex = i);
                              }
                            },
                            onKeyEvent: (event) => _handleGridKey(event, i, items),
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
  final FocusNode focusNode;
  final bool isFocused;
  final ValueChanged<bool> onFocusChange;
  final KeyEventResult Function(KeyEvent) onKeyEvent;

  const _MovieTile({
    super.key,
    required this.movie,
    required this.focusNode,
    required this.isFocused,
    required this.onFocusChange,
    required this.onKeyEvent,
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

  void _openPlayer(BuildContext context) {
    final m = widget.movie;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl)));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    final focused = widget.isFocused;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: (node, event) {
        // Enter/Select → abre player
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          _openPlayer(context);
          return KeyEventResult.handled;
        }
        // Setas → controladas pelo pai (grid)
        return widget.onKeyEvent(event);
      },
      child: GestureDetector(
        onTap: () => _openPlayer(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(fit: StackFit.expand, children: [
              m.cover != null
                  ? CachedNetworkImage(
                      imageUrl: m.cover!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.movie, color: Colors.grey, size: 32),
                      ))
                  : Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.movie, color: Colors.grey, size: 32)),

              if (focused)
                Container(color: Colors.white10),

              Positioned(
                top: 4, right: 4,
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
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(m.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
