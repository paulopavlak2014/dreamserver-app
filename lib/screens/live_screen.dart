import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../models/epg.dart';
import '../services/favorites_service.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);
const _kCard = Color(0xFF161616);
const _kSurface = Color(0xFF1E1E1E);

// ── Parser M3U (para lista adicional) ────────────────────────────────────────

class _M3UChannel {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  const _M3UChannel({required this.name, required this.url, this.logo, this.group});
}

class _M3UParser {
  static List<_M3UChannel> parse(String content) {
    final channels = <_M3UChannel>[];
    final lines = content.split('\n');
    String? name, logo, group;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        name  = _attr(line, 'tvg-name') ?? _afterComma(line);
        logo  = _attr(line, 'tvg-logo');
        group = _attr(line, 'group-title');
      } else if (!line.startsWith('#') && name != null) {
        channels.add(_M3UChannel(name: name, url: line, logo: logo, group: group));
        name = logo = group = null;
      }
    }
    return channels;
  }
  static String? _attr(String line, String a) =>
      RegExp('$a="([^"]*)"').firstMatch(line)?.group(1);
  static String? _afterComma(String line) {
    final i = line.lastIndexOf(',');
    return i >= 0 ? line.substring(i + 1).trim() : null;
  }
}

/// Função top-level usada com compute() para parsear M3U em isolate.
List<_M3UChannel> _parseM3UInIsolate(String content) => _M3UParser.parse(content);

// ── LiveScreen ────────────────────────────────────────────────────────────────

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
  List<_M3UChannel> _m3uChannels = [];

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
    setState(() => _loading = true);

    // Xtream
    final results = await Future.wait([
      widget.service.getLiveChannels(),
      widget.service.getLiveCategories(),
    ]);
    final data = results[0] as List<Channel>;
    final cats  = results[1] as List<Category>;
    final usedIds  = data.map((c) => c.category).toSet();
    final usedCats = cats.where((c) => usedIds.contains(c.id)).toList();

    // M3U adicional
    final prefs  = await SharedPreferences.getInstance();
    final m3uUrl = prefs.getString('m3u_url') ?? '';
    List<_M3UChannel> m3u = [];
    if (m3uUrl.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(m3uUrl))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          final body = utf8.decode(res.bodyBytes);
          // Parse em isolate para listas grandes (>100KB) para não travar UI
          if (body.length > 100000) {
            m3u = await compute(_parseM3UInIsolate, body);
          } else {
            m3u = _M3UParser.parse(body);
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _channels    = data;
        _categories  = usedCats;
        _m3uChannels = m3u;
        _loading     = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _channels.where((c) {
        final matchesCat   = _selectedCategoryId == null || c.category == _selectedCategoryId;
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EpgSheet(service: widget.service, channel: channel),
    );
  }

  void _playChannel(Channel c) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: c.name,
        url: c.streamUrl,
        channelLogo: c.logo,
        channelId: c.id,
        service: widget.service,
      ),
    ));
  }

  void _playM3U(_M3UChannel c) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: c.name,
        url: c.url,
        channelLogo: c.logo,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Total visível na busca: canais xtream filtrados + m3u (filtro por nome)
    final q = _search.text.toLowerCase();
    final m3uFiltered = q.isEmpty
        ? _m3uChannels
        : _m3uChannels.where((c) => c.name.toLowerCase().contains(q)).toList();
    final totalCount = _filtered.length + m3uFiltered.length;

    return Column(children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          const Text('TV Ao Vivo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$totalCount canais',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
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
                onTap: () { setState(() => _selectedCategoryId = null); _applyFilter(); },
              ),
              ..._categories.map((cat) => _CategoryChip(
                    label: cat.name,
                    selected: _selectedCategoryId == cat.id,
                    onTap: () { setState(() => _selectedCategoryId = cat.id); _applyFilter(); },
                  )),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kRed))
            : (totalCount == 0)
                ? const Center(
                    child: Text('Nenhum canal',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    itemCount: _filtered.length + m3uFiltered.length,
                    itemBuilder: (_, i) {
                      if (i < _filtered.length) {
                        final c = _filtered[i];
                        return _FocusableChannelTile(
                          channel: c,
                          onPlay: () => _playChannel(c),
                          onEpg: () => _openEpg(context, c),
                        );
                      }
                      final m = m3uFiltered[i - _filtered.length];
                      return _M3UTile(channel: m, onPlay: () => _playM3U(m));
                    },
                  ),
      ),
    ]);
  }
}

// ── Tile M3U ──────────────────────────────────────────────────────────────────

class _M3UTile extends StatelessWidget {
  final _M3UChannel channel;
  final VoidCallback onPlay;
  const _M3UTile({required this.channel, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(8)),
            child: Container(
              width: 72,
              height: 52,
              color: _kSurface,
              child: channel.logo != null
                  ? CachedNetworkImage(
                      imageUrl: channel.logo!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.live_tv,
                          color: Colors.grey,
                          size: 20))
                  : const Icon(Icons.live_tv, color: Colors.grey, size: 20),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(channel.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (channel.group != null)
                    Text(channel.group!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('M3U',
                style: TextStyle(color: Colors.grey, fontSize: 9)),
          ),
        ]),
      ),
    );
  }
}

// ── FocusableChannelTile (original) ──────────────────────────────────────────

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
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) { widget.onPlay(); return null; }),
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
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(8)),
              child: Container(
                width: 72,
                height: 52,
                color: _kSurface,
                child: c.logo != null
                    ? CachedNetworkImage(
                        imageUrl: c.logo!,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.live_tv, color: Colors.grey, size: 20))
                    : const Icon(Icons.live_tv, color: Colors.grey, size: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        _focused ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            _FavButton(channel: c),
            IconButton(
              icon: const Icon(Icons.format_list_bulleted,
                  color: Colors.grey, size: 18),
              onPressed: widget.onEpg,
              tooltip: 'Programação',
            ),
          ]),
        ),
      ),
    );
  }
}

// ── FavButton ─────────────────────────────────────────────────────────────────

class _FavButton extends StatefulWidget {
  final Channel channel;
  const _FavButton({required this.channel});
  @override
  State<_FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<_FavButton> {
  bool _isFav = false;
  @override
  void initState() { super.initState(); _check(); }

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

// ── CategoryChip ──────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableActionDetector(
        onShowFocusHighlight: (_) {},
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) { onTap(); return null; }),
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
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── EpgSheet ──────────────────────────────────────────────────────────────────

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data =
          await widget.service.getEpgForChannel(widget.channel.id);
      if (mounted) setState(() { _programs = data; _loading = false; });
    } catch (e) {
      if (mounted)
        setState(() { _error = 'Erro ao carregar EPG'; _loading = false; });
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
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2))),
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
                errorWidget: (_, __, ___) => const Icon(
                    Icons.live_tv, color: Colors.grey, size: 18),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.channel.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ]),
        ),
        const Divider(color: Colors.white12, height: 16),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _kRed))
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.grey)))
                  : _programs.isEmpty
                      ? const Center(
                          child: Text(
                              'EPG não disponível para este canal',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: ctrl,
                          itemCount: _programs.length,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          itemBuilder: (_, i) {
                            final p = _programs[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: p.isLive
                                    ? _kRed.withOpacity(0.15)
                                    : _kSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: p.isLive
                                    ? Border.all(
                                        color: _kRed.withOpacity(0.5))
                                    : null,
                              ),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      if (p.isLive) ...[
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                              color: _kRed,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3)),
                                          child: const Text('AO VIVO',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(p.timeRange,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.title,
                                      style: TextStyle(
                                        color: p.isLive
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: p.isLive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (p.isLive) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: p.progress,
                                          minHeight: 3,
                                          backgroundColor:
                                              Colors.white12,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  _kRed),
                                        ),
                                      ),
                                    ],
                                    if (p.description != null &&
                                        p.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        p.description!,
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10),
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
