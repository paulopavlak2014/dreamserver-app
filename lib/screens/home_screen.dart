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
  // Controla se o foco está no menu lateral ou no conteúdo
  bool _sidebarFocused = true;

  final _sidebarFocusNode = FocusScopeNode();
  final _contentFocusNode = FocusScopeNode();

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
  void dispose() {
    _sidebarFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _goToContent() {
    setState(() => _sidebarFocused = false);
    _contentFocusNode.requestFocus();
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
                // Só vai pro sidebar se não há filho que consuma o evento
                if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
                _goToSidebar();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: IndexedStack(
              index: _tab,
              children: [
                _HomePage(service: widget.service),
                LiveScreen(service: widget.service),
                EpgScreen(service: widget.service),
                MoviesScreen(service: widget.service),
                SeriesScreen(service: widget.service),
                const SportsScreen(),
                const FavoritesScreen(),
                SettingsScreen(service: widget.service),
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
  const _HomePage({required this.service});
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  List<Channel> _live = [];
  List<Movie> _movies = [];
  bool _loading = true;
  int _bannerIndex = 0;
  final _pageCtrl = PageController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await Future.wait([
      widget.service.getLiveChannels(),
      widget.service.getMovies(),
    ]);
    if (mounted) setState(() {
      _live = r[0] as List<Channel>;
      _movies = r[1] as List<Movie>;
      _loading = false;
    });
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kRed));
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _TopBar()),
      if (_live.isNotEmpty) SliverToBoxAdapter(child: _Banner(
        channels: _live.take(5).toList(), index: _bannerIndex,
        controller: _pageCtrl,
        onChanged: (i) => setState(() => _bannerIndex = i),
        service: widget.service,
      )),
      if (_live.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: 'Canais em Destaque')),
        SliverToBoxAdapter(child: SizedBox(height: 100, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _live.take(10).length,
          itemBuilder: (_, i) => _ChannelCard(channel: _live[i], service: widget.service),
        ))),
      ],
      if (_movies.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: 'Filmes Populares')),
        SliverToBoxAdapter(child: SizedBox(height: 140, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _movies.take(10).length,
          itemBuilder: (_, i) => _MovieCard(movie: _movies[i]),
        ))),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }
}

class _TopBar extends StatelessWidget {
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
  const _ChannelCard({required this.channel, required this.service});
  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlayerScreen(title: widget.channel.name, url: widget.channel.streamUrl,
                channelLogo: widget.channel.logo, channelId: widget.channel.id, service: widget.service),
          ));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(title: widget.channel.name, url: widget.channel.streamUrl,
              channelLogo: widget.channel.logo, channelId: widget.channel.id, service: widget.service),
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
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
  const _MovieCard({required this.movie});
  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlayerScreen(title: widget.movie.name, url: widget.movie.streamUrl),
          ));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PlayerScreen(title: widget.movie.name, url: widget.movie.streamUrl),
        )),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 95, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 2),
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

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
