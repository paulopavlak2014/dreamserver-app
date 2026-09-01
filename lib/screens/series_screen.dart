import 'package:flutter/material.dart';
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
  State<SeriesScreen> createState() => SeriesScreenState();
}

class SeriesScreenState extends State<SeriesScreen> {
  List<Series> _all = [];
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
    return _focusNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'series_$i'));
  }

  /// Foca o primeiro item (chamado ao trocar de aba)
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
      widget.service.getSeries(),
      widget.service.getSeriesCategories(),
    ]);

    if (!mounted) return;

    setState(() {
      _all = results[0] as List<Series>;
      _categories = results[1] as List<Category>;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filtered.isNotEmpty) {
        _nodeFor(0).requestFocus();
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
                    Text('Carregando séries...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                )
              : items.isEmpty
                  ? const Center(child: Text('Nenhuma série encontrada', style: TextStyle(color: Colors.grey)))
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
                      itemBuilder: (_, i) => _SeriesTile(
                        key: ValueKey('series_${items[i].id}_$i'),
                        series: items[i],
                        focusNode: _nodeFor(i),
                        onOpen: () => _openSeries(items[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

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
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) { widget.onTap(); return null; },
        ),
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

class _SeriesTile extends StatefulWidget {
  final Series series;
  final FocusNode focusNode;
  final VoidCallback onOpen;

  const _SeriesTile({
    super.key,
    required this.series,
    required this.focusNode,
    required this.onOpen,
  });

  @override
  State<_SeriesTile> createState() => _SeriesTileState();
}

class _SeriesTileState extends State<_SeriesTile> {
  bool _isFav = false;
  bool _focused = false;

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
                  child: Text(s.name,
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