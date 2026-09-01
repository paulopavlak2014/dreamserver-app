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

  // Globals keys to request focus on grid when tab activates
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
    // Foca no grid da aba atual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (_lastTab) {
        case 0: // Home
          _homeKey.currentState?.focusFirst();
          break;
        case 3: // Movies
          _moviesKey.currentState?.focusGrid();
          break;
        case 4: // Series
          _seriesKey.currentState?.focusGrid();
          break;
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

        // ── Menu lateral com seu próprio FocusScope ──
        FocusScope(
          node: _sidebarFocusNode,
          onKeyEvent: (node, event) {
            // Seta direita: vai para o conteúdo
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

        // ── Conteúdo com seu próprio FocusScope ──
        Expanded(
          child: FocusScope(
            node: _contentFocusNode,
            onKeyEvent: (node, event) {
              // Seta esquerda na borda: volta pro menu lateral
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
                MoviesScreen(key: const ValueKey('movies'), service: widget.service),
                SeriesScreen(key: const ValueKey('series'), service: widget.service),
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

// ── Sidebar item ─────────────────────────────────────────────────────────────
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
      child: Focus(
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

// ── Home Page ────────────────────────────────────────────────────────────────
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
  final _homeFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final _channelScroll = ScrollController();
  final _movieScroll = ScrollController();
  final _seriesScroll = ScrollController();

  int _focusSection = 0;
  int _focusIndex = 0;

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
        setState(() { _focusSection = 0; _focusIndex = 0; });
        _homeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _homeFocus.dispose();
    _scrollCtrl.dispose();
    _channelScroll.dispose();
    _movieScroll.dispose();
    _seriesScroll.dispose();
    super.dispose();
  }

  void focusFirst() {
    if (_loading || _live.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() { _focusSection = 0; _focusIndex = 0; });
        _homeFocus.requestFocus();
      }
    });
  }

  int _channelCount() => _live.take(10).length;
  int _movieCount() => _movies.take(10).length;
  int _seriesCount() => _series.take(10).length;

  int _sectionCount() {
    if (_focusSection == 0) return _channelCount();
    if (_focusSection == 1) return _movieCount();
    return _seriesCount();
  }

  void _scrollSectionToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focusSection == 0 && _channelScroll.hasClients) {
        _channelScroll.animateTo(_focusIndex * 130.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else if (_focusSection == 1 && _movieScroll.hasClients) {
        _movieScroll.animateTo(_focusIndex * 105.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else if (_focusSection == 2 && _seriesScroll.hasClients) {
        _seriesScroll.animateTo(_focusIndex * 105.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  KeyEventResult _handleHomeKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_focusIndex + 1 < _sectionCount()) {
        setState(() => _focusIndex++);
        _scrollSectionToFocus();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_focusIndex == 0) {
        return KeyEventResult.ignored;
      }
      setState(() => _focusIndex--);
      _scrollSectionToFocus();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusSection < 2) {
        final nextCount = _focusSection == 0 ? _movieCount() : _seriesCount();
        if (nextCount > 0) {
          setState(() { _focusSection++; _focusIndex = 0; });
          _scrollSectionToFocus();
        }
      } else if (_focusIndex + 1 < _seriesCount()) {
        setState(() => _focusIndex++);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusSection > 0) {
        setState(() { _focusSection--; _focusIndex = 0; });
        _scrollSectionToFocus();
        return KeyEventResult.handled;
      }
      if (_focusSection == 0 && _focusIndex == 0) {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (_focusSection == 0 && _focusIndex < _channelCount()) {
        final ch = _live[_focusIndex];
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(title: ch.name, url: ch.streamUrl,
              channelLogo: ch.logo, channelId: ch.id, service: widget.service),
        ));
      } else if (_focusSection == 1 && _focusIndex < _movieCount()) {
        final m = _movies[_focusIndex];
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(title: m.name, url: m.streamUrl),
        ));
      } else if (_focusSection == 2 && _focusIndex < _seriesCount()) {
        final s = _series[_focusIndex];
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(title: s.name, url: s.streamUrl),
        ));
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kRed));

    final channels = _live.take(10).toList();
    final movies = _movies.take(10).toList();
    final series = _series.take(10).toList();

    return Focus(
      focusNode: _homeFocus,
      autofocus: true,
      onKeyEvent: (node, event) => _handleHomeKey(event),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _TopBar(),
          if (channels.isNotEmpty) ...[
            const _SectionHeader(title: 'Canais em Destaque'),
            SizedBox(
              height: 100,
              child: SingleChildScrollView(
                controller: _channelScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < channels.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _ChannelCard(
                        channel: channels[i],
                        service: widget.service,
                        isFocused: _focusSection == 0 && _focusIndex == i,
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
              height: 140,
              child: SingleChildScrollView(
                controller: _movieScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < movies.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _MovieCard(movie: movies[i], isFocused: _focusSection == 1 && _focusIndex == i),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (series.isNotEmpty) ...[
            const _SectionHeader(title: 'Séries Lançamentos'),
            SizedBox(
              height: 140,
              child: SingleChildScrollView(
                controller: _seriesScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < series.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _SeriesCard(series: series[i], isFocused: _focusSection == 2 && _focusIndex == i),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _SeriesCard extends StatefulWidget {
  final Series series;
  final bool isFocused;

  const _SeriesCard({required this.series, required this.isFocused});

  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard> {
  @override
  Widget build(BuildContext context) {
    final focused = widget.isFocused;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(title: widget.series.name, url: widget.series.streamUrl),
      )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 95,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
          boxShadow: focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
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

class _Banner extends StatelessWidget {
  final List<Channel> channels;
  final int index;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final XtreamService service;
  const _Banner({required this.channels, required this.index,
      required this.controller, required this.onChanged, required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 160,
          child: Stack(children: [
            PageView.builder(
              controller: controller, onPageChanged: onChanged, itemCount: channels.length,
              itemBuilder: (_, i) {
                final ch = channels[i];
                return Stack(fit: StackFit.expand, children: [
                  ch.logo != null
                      ? CachedNetworkImage(imageUrl: ch.logo!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: kSurface))
                      : Container(color: kSurface),
                  Container(decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.centerRight, end: Alignment.centerLeft,
                    colors: [Colors.transparent, Colors.black87],
                  ))),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
                        child: const Text('AO VIVO',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 6),
                      Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlayerScreen(title: ch.name, url: ch.streamUrl,
                              channelLogo: ch.logo, channelId: ch.id, service: service),
                        )),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ]),
                  ),
                ]);
              },
            ),
            Positioned(
              bottom: 10, right: 12,
              child: Row(children: List.generate(channels.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == index ? 14 : 5, height: 5,
                decoration: BoxDecoration(
                  color: i == index ? kRed : Colors.white38,
                  borderRadius: BorderRadius.circular(3)),
              ))),
            ),
          ]),
        ),
      ),
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
class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final XtreamService service;
  final bool isFocused;

  const _ChannelCard({required this.channel, required this.service, required this.isFocused});

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  @override
  Widget build(BuildContext context) {
    final focused = widget.isFocused;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(title: widget.channel.name, url: widget.channel.streamUrl,
            channelLogo: widget.channel.logo, channelId: widget.channel.id, service: widget.service),
      )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
          boxShadow: focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
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
    );
  }
}
class _MovieCard extends StatefulWidget {
  final Movie movie;
  final bool isFocused;

  const _MovieCard({required this.movie, required this.isFocused});

  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  @override
  Widget build(BuildContext context) {
    final focused = widget.isFocused;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(title: widget.movie.name, url: widget.movie.streamUrl),
      )),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 95,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: focused ? Colors.white : Colors.transparent, width: 2),
          boxShadow: focused ? [const BoxShadow(color: Colors.white38, blurRadius: 8, spreadRadius: 1)] : null,
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
    );
  }
}
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
