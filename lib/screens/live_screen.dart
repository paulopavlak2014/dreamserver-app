import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../models/epg.dart';
import '../services/favorites_service.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);
const _kCard = Color(0xFF161616);
const _kSurface = Color(0xFF1E1E1E);

class LiveScreen extends StatefulWidget {
  final XtreamService service;
  const LiveScreen({super.key, required this.service});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Channel> _channels = [];
  List<Channel> _filtered = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_applyFilter);
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.service.getLiveChannels(),
      widget.service.getLiveCategories(),
    ]);
    final data = results[0] as List<Channel>;
    final cats = results[1] as List<Category>;
    final usedIds = data.map((c) => c.category).toSet();
    final usedCats = cats.where((c) => usedIds.contains(c.id)).toList();
    if (mounted) {
      setState(() {
        _channels = data;
        _categories = usedCats;
        _loading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _channels.where((c) {
        final matchesCat = _selectedCategoryId == null || c.category == _selectedCategoryId;
        final matchesQuery = q.isEmpty || c.name.toLowerCase().contains(q);
        return matchesCat && matchesQuery;
      }).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openEpg(BuildContext context, Channel channel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EpgSheet(service: widget.service, channel: channel),
    );
  }

  void _playChannel(Channel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: c.name,
          url: c.streamUrl,
          channelLogo: c.logo,
          channelId: c.id,
          service: widget.service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          const Text('TV Ao Vivo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_filtered.length} canais', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar canal...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
            filled: true,
            fillColor: _kCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      if (_categories.isNotEmpty)
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _CategoryChip(
                label: 'Todos',
                selected: _selectedCategoryId == null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  _applyFilter();
                },
              ),
              ..._categories.map((cat) => _CategoryChip(
                    label: cat.name,
                    selected: _selectedCategoryId == cat.id,
                    onTap: () {
                      setState(() => _selectedCategoryId = cat.id);
                      _applyFilter();
                    },
                  )),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kRed))
            : _filtered.isEmpty
                ? const Center(child: Text('Nenhum canal', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return _FocusableChannelTile(
                        channel: c,
                        onPlay: () => _playChannel(c),
                        onEpg: () => _openEpg(context, c),
                      );
                    },
                  ),
      ),
    ]);
  }
}

/// Tile com foco visível para controle remoto / TV
class _FocusableChannelTile extends StatefulWidget {
  final Channel channel;
  final VoidCallback onPlay;
  final VoidCallback onEpg;
  const _FocusableChannelTile({
    required this.channel,
    required this.onPlay,
    required this.onEpg,
  });

  @override
  State<_FocusableChannelTile> createState() => _FocusableChannelTileState();
}

class _FocusableChannelTileState extends State<_FocusableChannelTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPlay();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: _focused ? _kRed.withOpacity(0.18) : _kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? _kRed : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              child: Container(
                width: 72,
                height: 52,
                color: _kSurface,
                child: c.logo != null
                    ? CachedNetworkImage(
                        imageUrl: c.logo!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.live_tv, color: Colors.grey, size: 20))
                    : const Icon(Icons.live_tv, color: Colors.grey, size: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: _focused ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _FavButton(channel: c),
            IconButton(
              icon: const Icon(Icons.format_list_bulleted, color: Colors.grey, size: 18),
              onPressed: widget.onEpg,
              tooltip: 'Programação',
            ),
          ]),
        ),
      ),
    );
  }
}

class _FavButton extends StatefulWidget {
  final Channel channel;
  const _FavButton({required this.channel});

  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await FavoritesService.isFavorite(widget.channel.streamUrl);
    if (mounted) setState(() => _isFav = ok);
  }

  Future<void> _toggle() async {
    await FavoritesService.toggle({
      'id': widget.channel.id,
      'title': widget.channel.name,
      'url': widget.channel.streamUrl,
      'type': 'live',
      'category': widget.channel.category ?? '',
    });
    if (mounted) setState(() => _isFav = !_isFav);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isFav ? Icons.star_rounded : Icons.star_border_rounded,
        color: _isFav ? Colors.amber : Colors.grey,
        size: 20,
      ),
      onPressed: _toggle,
      tooltip: 'Favorito',
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableActionDetector(
        onShowFocusHighlight: (_) {},
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            onTap();
            return null;
          }),
        },
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _kRed : _kCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: focused
                      ? Colors.white
                      : (selected ? _kRed : Colors.white12),
                  width: focused ? 2 : 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EpgSheet extends StatefulWidget {
  final XtreamService service;
  final Channel channel;
  const _EpgSheet({required this.service, required this.channel});
  @override
  State<_EpgSheet> createState() => _EpgSheetState();
}

class _EpgSheetState extends State<_EpgSheet> {
  List<EpgProgram> _programs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.service.getEpgForChannel(widget.channel.id);
      if (mounted) setState(() { _programs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro ao carregar EPG'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (widget.channel.logo != null)
              CachedNetworkImage(
                imageUrl: widget.channel.logo!,
                width: 36,
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.grey, size: 18),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.channel.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ]),
        ),
        const Divider(color: Colors.white12, height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kRed))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
                  : _programs.isEmpty
                      ? const Center(child: Text('EPG não disponível para este canal', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: ctrl,
                          itemCount: _programs.length,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemBuilder: (_, i) {
                            final p = _programs[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: p.isLive ? _kRed.withOpacity(0.15) : _kSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: p.isLive ? Border.all(color: _kRed.withOpacity(0.5)) : null,
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  if (p.isLive) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(3)),
                                      child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(p.timeRange, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ]),
                                const SizedBox(height: 4),
                                Text(
                                  p.title,
                                  style: TextStyle(
                                    color: p.isLive ? Colors.white : Colors.white70,
                                    fontWeight: p.isLive ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                if (p.isLive) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: p.progress,
                                      minHeight: 3,
                                      backgroundColor: Colors.white12,
                                      valueColor: const AlwaysStoppedAnimation(_kRed),
                                    ),
                                  ),
                                ],
                                if (p.description != null && p.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    p.description!,
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ]),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
