import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'player_screen.dart';
import 'epg_screen.dart';
import 'settings_screen.dart';
import 'sports_screen.dart';
import 'favorites_screen.dart';

const kRed = Color(0xFFE50914);
const kBg = Color(0xFF0A0A0A);
const kCard = Color(0xFF161616);
const kSurface = Color(0xFF1E1E1E);

class HomeScreen extends StatefulWidget {
  final XtreamService service;
  const HomeScreen({super.key, required this.service});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _lastTab = -1;
  bool _sidebarFocused = true;

  final _sidebarFocusNode = FocusScopeNode();
  final _contentFocusNode = FocusScopeNode();

  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<MoviesScreenState> _moviesKey = GlobalKey<MoviesScreenState>();
  final GlobalKey<SeriesScreenState> _seriesKey = GlobalKey<SeriesScreenState>();

  static const _navItems = [
    _NavItem(Icons.home_rounded,          'Início'),
    _NavItem(Icons.live_tv_rounded,       'TV Ao Vivo'),
    _NavItem(Icons.grid_view_rounded,     'EPG'),
    _NavItem(Icons.movie_rounded,         'Filmes'),
    _NavItem(Icons.tv_rounded,            'Séries'),
    _NavItem(Icons.sports_soccer_rounded, 'Esportes'),
    _NavItem(Icons.star_rounded,          'Favoritos'),
    _NavItem(Icons.settings_rounded,      'Config'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sidebarFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _sidebarFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _goToContent() {
    setState(() {
      _sidebarFocused = false;
      _lastTab = _tab;
    });
    _contentFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (_lastTab) {
        case 0: _homeKey.currentState?.focusFirst(); break;
        case 3: _moviesKey.currentState?.focusGrid(); break;
        case 4: _seriesKey.currentState?.focusGrid(); break;
      }
    });
  }

  void _goToSidebar() {
    setState(() => _sidebarFocused = true);
    _sidebarFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [
        FocusScope(
          node: _sidebarFocusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _goToContent();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 64,
            color: const Color(0xFF0F0F0F),
            child: Column(children: [
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.play_circle_filled, color: kRed, size: 26),
              ),
              const Divider(color: Colors.white12, height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _navItems.length,
                  itemBuilder: (_, i) {
                    final item = _navItems[i];
                    return _SidebarItem(
                      icon: item.icon,
                      label: item.label,
                      selected: _tab == i,
                      onTap: () {
                        setState(() => _tab = i);
                        _goToContent();
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: FocusScope(
            node: _contentFocusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (_sidebarFocused) return KeyEventResult.ignored;
                _goToSidebar();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: IndexedStack(
              index: _tab,
              children: [
                _HomePage(key: _homeKey, service: widget.service),
                LiveScreen(service: widget.service),
                EpgScreen(service: widget.service),
                MoviesScreen(key: _moviesKey, service: widget.service),
                SeriesScreen(key: _seriesKey, service: widget.service),
                const SportsScreen(),
                const FavoritesScreen(),
                SettingsScreen(key: const ValueKey('settings'), service: widget.service),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;
    return Tooltip(
      message: widget.label,
      preferBelow: false,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) { widget.onTap(); return null; },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? kRed.withOpacity(0.25) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused ? kRed : widget.selected ? kRed.withOpacity(0.5) : Colors.transparent,
                width: _focused ? 2 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, color: active ? kRed : Colors.grey, size: 22),
              if (_focused) ...[
                const SizedBox(height: 4),
                Text(widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  final XtreamService service;
  const _HomePage({super.key, required this.service});
  @override
  State<_HomePage> createState() => HomePageState();
}

class HomePageState extends State<_HomePage> {
  List<Channel> _live = [];
  List<Movie> _movies = [];
  List<Series> _series = [];
  bool _loading = true;

  final _channelScr = ScrollController();
  final _movieScr = ScrollController();
  final _seriesScr = ScrollController();
  final _firstChannelFocus = FocusNode();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await Future.wait([
      widget.service.getLiveChannels(),
      widget.service.getMovies(),
      widget.service.getSeries(),
    ]);
    if (mounted) setState(() {
      _live = r[0] as List<Channel>;
      _movies = r[1] as List<Movie>;
      _series = r[2] as List<Series>;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _live.isNotEmpty) {
        _firstChannelFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _channelScr.dispose();
    _movieScr.dispose();
    _seriesScr.dispose();
    _firstChannelFocus.dispose();
    super.dispose();
  }

  void focusFirst() {
    if (_loading || _live.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstChannelFocus.requestFocus();
    });
  }

  void _openChannel(Channel ch) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(title: ch.name, url: ch.streamUrl,
          channelLogo: ch.logo, channelId: ch.id, service: widget.service),
    ));
  }

  void _openMovie(Movie m) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl, isVod: true),
    ));
  }

  Future<void> _openSeries(Series s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kRed)),
    );

    final info = await widget.service.getSeriesInfo(s.id);
    if (!mounted) return;
    Navigator.pop(context);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar os episodios.')));
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
          const SnackBar(content: Text('Nenhum episodio encontrado.')));
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
                        'Episodio ${ep['episode_num'] ?? (i + 1)}';
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
                                builder: (_) => PlayerScreen(title: title, url: url, isVod: true)));
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: kRed));

    final channels = _live.take(10).toList();
    final movies = _movies.take(10).toList();
    final series = _series.take(10).toList();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _TopBar(),
        if (channels.isNotEmpty) ...[
          const _SectionHeader(title: 'Canais em Destaque'),
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              controller: _channelScr,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < channels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _ChannelCard(
                      channel: channels[i],
                      service: widget.service,
                      firstCard: i == 0,
                      firstFocus: i == 0 ? _firstChannelFocus : null,
                      onOpen: () => _openChannel(channels[i]),
                      scr: _channelScr,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (movies.isNotEmpty) ...[
          const _SectionHeader(title: 'Filmes Lançamentos'),
          SizedBox(
            height: 170,
            child: SingleChildScrollView(
              controller: _movieScr,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < movies.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _MovieCard(
                      movie: movies[i],
                      onOpen: () => _openMovie(movies[i]),
                      scr: _movieScr,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (series.isNotEmpty) ...[
          const _SectionHeader(title: 'Séries Lançamentos'),
          SizedBox(
            height: 170,
            child: SingleChildScrollView(
              controller: _seriesScr,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < series.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _SeriesCard(
                      series: series[i],
                      onOpen: () => _openSeries(series[i]),
                      scr: _seriesScr,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final XtreamService service;
  final bool firstCard;
  final FocusNode? firstFocus;
  final VoidCallback onOpen;
  final ScrollController scr;

  const _ChannelCard({
    required this.channel,
    required this.service,
    required this.firstCard,
    required this.onOpen,
    required this.scr,
    this.firstFocus,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _focused = false;
  final _focus = FocusNode(debugLabel: 'home_channel');

  @override
  void initState() {
    super.initState();
    if (widget.firstCard && widget.firstFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.firstFocus!.requestFocus();
      });
    }
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focus.context != null) {
        Scrollable.ensureVisible(_focus.context!, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.firstCard ? widget.firstFocus : _focus,
      onShowFocusHighlight: (v) { setState(() => _focused = v); if (v) _ensureVisible(); },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) { widget.onOpen(); return null; },
        ),
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
            boxShadow: _focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(children: [
              widget.channel.logo != null
                  ? CachedNetworkImage(imageUrl: widget.channel.logo!, width: 120, height: 100, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: kSurface,
                          child: const Icon(Icons.live_tv, color: Colors.grey)))
                  : Container(color: kSurface, child: const Icon(Icons.live_tv, color: Colors.grey)),
              Positioned(top: 5, left: 5, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(3)),
                child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              )),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black, Colors.transparent]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(widget.channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onOpen;
  final ScrollController scr;

  const _MovieCard({required this.movie, required this.onOpen, required this.scr});

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  bool _focused = false;
  final _focus = FocusNode(debugLabel: 'home_movie');

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focus.context != null) {
        Scrollable.ensureVisible(_focus.context!, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _focus,
      onShowFocusHighlight: (v) { setState(() => _focused = v); if (v) _ensureVisible(); },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) { widget.onOpen(); return null; },
        ),
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 95,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
            boxShadow: _focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              widget.movie.cover != null
                  ? CachedNetworkImage(imageUrl: widget.movie.cover!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: kSurface,
                          child: const Icon(Icons.movie, color: Colors.grey)))
                  : Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.grey)),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black, Colors.transparent]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(widget.movie.name,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatefulWidget {
  final Series series;
  final VoidCallback onOpen;
  final ScrollController scr;

  const _SeriesCard({required this.series, required this.onOpen, required this.scr});

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  bool _focused = false;
  final _focus = FocusNode(debugLabel: 'home_series');

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focus.context != null) {
        Scrollable.ensureVisible(_focus.context!, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _focus,
      onShowFocusHighlight: (v) { setState(() => _focused = v); if (v) _ensureVisible(); },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) { widget.onOpen(); return null; },
        ),
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 95,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
            boxShadow: _focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              widget.series.cover != null
                  ? CachedNetworkImage(imageUrl: widget.series.cover!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: kSurface,
                          child: const Icon(Icons.tv, color: Colors.grey)))
                  : Container(color: kSurface, child: const Icon(Icons.tv, color: Colors.grey)),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black, Colors.transparent]),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                ),
                child: Text(widget.series.name,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
            ]),
          ),
        ),
      ),
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
          trailing: const Icon(Icons.play_arrow, color: kRed),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(children: [
        const Text('DREAM', style: TextStyle(color: kRed, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3)),
        const Spacer(),
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(color: Colors.green, fontSize: 10)),
        ]),
        const SizedBox(width: 8),
        const CircleAvatar(backgroundColor: kRed, radius: 14,
            child: Icon(Icons.person, color: Colors.white, size: 16)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
    child: Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 7),
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      const Spacer(),
      const Text('Ver todos >', style: TextStyle(color: kRed, fontSize: 11)),
    ]),
  );
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}