import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../services/favorites_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);

class SeriesScreen extends StatefulWidget {
  final XtreamService service;
  const SeriesScreen({super.key, required this.service});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Series> _all = [];
  List<Category> _categories = [];
  String _selectedCat = '';
  String _search = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  int _focusedIndex = -1;
  final Map<int, FocusNode> _focusNodes = {};
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
      _focusNodes[index] = FocusNode(debugLabel: 'series_$index');
    }
    return _focusNodes[index]!;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _focusedIndex = -1;

    final results = await Future.wait([
      widget.service.getSeries(),
      widget.service.getSeriesCategories(),
    ]);

    if (!mounted) return;

    setState(() {
      _all = results[0] as List<Series>;
      _categories = results[1] as List<Category>;
      _loading = false;
    });

    // Foca no primeiro item automaticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filtered.isNotEmpty) {
        _moveFocus(0, _filtered);
      }
    });
  }

  List<Series> get _filtered {
    var list = _all;
    if (_selectedCat.isNotEmpty) {
      list = list.where((s) => s.categoryId == _selectedCat).toList();
    }
    if (_search.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(_search)).toList();
    }
    return list;
  }

  int _calcColumns(double width) {
    final padding = 12.0 * 2;
    final available = width - padding;
    return (available / (110 + 10)).floor().clamp(1, 999);
  }

  bool _moveFocus(int newIndex, List<Series> items) {
    if (newIndex < 0 || newIndex >= items.length) return false;
    setState(() => _focusedIndex = newIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final node = _nodeFor(newIndex);
      if (node.context != null) node.requestFocus();
    });
    return true;
  }

  KeyEventResult _handleGridKey(KeyEvent event, int index, List<Series> items) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final cols = _columnCount;

    if (key == LogicalKeyboardKey.arrowRight) {
      if (index + 1 < items.length) {
        _moveFocus(index + 1, items);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % cols == 0) {
        // Primeira coluna → deixa ir para o menu lateral
        return KeyEventResult.ignored;
      }
      _moveFocus(index - 1, items);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + cols;
      if (next < items.length) {
        _moveFocus(next, items);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index >= cols) {
        _moveFocus(index - cols, items);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _openSeries(Series s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _kRed)),
    );

    final info = await widget.service.getSeriesInfo(s.id);
    if (!mounted) return;
    Navigator.pop(context);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar os episódios.')));
      return;
    }

    final episodes = <Map<String, dynamic>>[];
    final seasons = info['episodes'];
    if (seasons is Map) {
      for (final seasonEpisodes in seasons.values) {
        if (seasonEpisodes is List) {
          for (final ep in seasonEpisodes) {
            if (ep is Map<String, dynamic>) episodes.add(ep);
          }
        }
      }
    }

    if (episodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum episódio encontrado.')));
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(s.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: episodes.length,
                  itemBuilder: (_, i) {
                    final ep = episodes[i];
                    final title = ep['title']?.toString() ??
                        'Episódio ${ep['episode_num'] ?? (i + 1)}';
                    final id = ep['id']?.toString() ?? '';
                    final ext = ep['container_extension']?.toString() ?? 'mp4';
                    return _EpisodeTile(
                      title: title,
                      subtitle: 'S${ep['season'] ?? '?'} E${ep['episode_num'] ?? '?'}',
                      onTap: () {
                        Navigator.pop(ctx);
                        final url = widget.service.seriesEpisodeUrl(s.id, id, ext);
                        Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => PlayerScreen(title: title, url: url)));
                      },
                    );
                  },
                ),
              ),
            ]);
          },
        );
      },
    );
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
                const Text('Séries',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${items.length} séries', style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
                  hintText: 'Buscar série...',
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
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_filtered.isNotEmpty) _moveFocus(0, _filtered);
                          });
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
                        Text('Carregando séries...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    )
                  : items.isEmpty
                      ? const Center(child: Text('Nenhuma série encontrada', style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 110,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _SeriesTile(
                            key: ValueKey('series_${items[i].id}_$i'),
                            series: items[i],
                            focusNode: _nodeFor(i),
                            isFocused: _focusedIndex == i,
                            onFocusChange: (focused) {
                              if (focused) setState(() => _focusedIndex = i);
                            },
                            onKeyEvent: (event) => _handleGridKey(event, i, items),
                            onOpen: () => _openSeries(items[i]),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

// ── Episode tile ────────────────────────────────────────────────────────────
class _EpisodeTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EpisodeTile({required this.title, required this.subtitle, required this.onTap});

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _focused ? Colors.white12 : Colors.transparent,
          border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          title: Text(widget.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(widget.subtitle, style: const TextStyle(color: Colors.grey)),
          trailing: const Icon(Icons.play_arrow, color: _kRed),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

// ── Series tile ─────────────────────────────────────────────────────────────
class _SeriesTile extends StatefulWidget {
  final Series series;
  final FocusNode focusNode;
  final bool isFocused;
  final ValueChanged<bool> onFocusChange;
  final KeyEventResult Function(KeyEvent) onKeyEvent;
  final VoidCallback onOpen;

  const _SeriesTile({
    super.key,
    required this.series,
    required this.focusNode,
    required this.isFocused,
    required this.onFocusChange,
    required this.onKeyEvent,
    required this.onOpen,
  });

  @override
  State<_SeriesTile> createState() => _SeriesTileState();
}

class _SeriesTileState extends State<_SeriesTile> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    FavoritesService.isFavorite('series:${widget.series.id}')
        .then((v) { if (mounted) setState(() => _isFav = v); });
  }

  Future<void> _toggleFav() async {
    final key = 'series:${widget.series.id}';
    await FavoritesService.toggle({
      'id': widget.series.id,
      'title': widget.series.name,
      'url': key,
      'type': 'serie',
      'category': widget.series.categoryId ?? '',
    });
    if (mounted) setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final focused = widget.isFocused;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onOpen();
          return KeyEventResult.handled;
        }
        return widget.onKeyEvent(event);
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: 3,
            ),
            boxShadow: focused
                ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(fit: StackFit.expand, children: [
              s.cover != null
                  ? CachedNetworkImage(
                      imageUrl: s.cover!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.tv, color: Colors.grey, size: 32),
                      ))
                  : Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.tv, color: Colors.grey, size: 32)),
              if (focused) Container(color: Colors.white10),
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
                  child: Text(s.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}