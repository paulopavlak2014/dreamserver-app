import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'player_screen.dart';

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
  bool _sidebarExpanded = false;

  static const _navItems = [
    _NavItem(Icons.home_rounded, 'Início'),
    _NavItem(Icons.live_tv_rounded, 'TV Ao Vivo'),
    _NavItem(Icons.movie_rounded, 'Filmes'),
    _NavItem(Icons.tv_rounded, 'Séries'),
    _NavItem(Icons.sports_soccer_rounded, 'Esportes'),
    _NavItem(Icons.replay_rounded, 'Replay'),
    _NavItem(Icons.favorite_rounded, 'Favoritos'),
    _NavItem(Icons.settings_rounded, 'Configurações'),
  ];

  Widget _buildPage() {
    switch (_tab) {
      case 0: return _HomePage(service: widget.service);
      case 1: return LiveScreen(service: widget.service);
      case 2: return MoviesScreen(service: widget.service);
      case 3: return SeriesScreen(service: widget.service);
      default: return _ComingSoon(label: _navItems[_tab].label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: _sidebarExpanded ? 200 : 64,
            color: const Color(0xFF0F0F0F),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                    child: Row(children: [
                      const Icon(Icons.play_circle_filled, color: kRed, size: 28),
                      if (_sidebarExpanded) ...[
                        const SizedBox(width: 8),
                        const Text('DREAM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (_, i) {
                      final item = _navItems[i];
                      final sel = _tab == i;
                      return GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sel ? kRed.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: sel ? Border.all(color: kRed.withOpacity(0.4)) : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(children: [
                            Icon(item.icon, color: sel ? kRed : Colors.grey, size: 22),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              Text(item.label, style: TextStyle(
                                color: sel ? Colors.white : Colors.grey,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              )),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }
}

// ── HOME PAGE ────────────────────────────────────────────
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
    final r = await Future.wait([widget.service.getLiveChannels(), widget.service.getMovies()]);
    if (mounted) setState(() { _live = r[0] as List<Channel>; _movies = r[1] as List<Movie>; _loading = false; });
  }

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kRed));
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _TopBar()),
      if (_live.isNotEmpty) SliverToBoxAdapter(child: _Banner(
        channels: _live.take(5).toList(), index: _bannerIndex, controller: _pageCtrl,
        onChanged: (i) => setState(() => _bannerIndex = i),
      )),
      if (_live.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: 'Canais em Destaque', onVerTodos: () {})),
        SliverToBoxAdapter(child: SizedBox(height: 110, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _live.take(10).length,
          itemBuilder: (_, i) => _ChannelCard(channel: _live[i]),
        ))),
      ],
      if (_movies.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: 'Filmes e Séries Populares', onVerTodos: () {})),
        SliverToBoxAdapter(child: SizedBox(height: 150, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _movies.take(10).length,
          itemBuilder: (_, i) => _MovieCard(movie: _movies[i]),
        ))),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
      child: Row(children: [
        const Spacer(),
        IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        const SizedBox(width: 4),
        Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Conectado', style: TextStyle(color: Colors.green, fontSize: 11)),
        ]),
        const SizedBox(width: 12),
        const CircleAvatar(backgroundColor: kRed, radius: 16, child: Icon(Icons.person, color: Colors.white, size: 18)),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final List<Channel> channels;
  final int index;
  final PageController controller;
  final ValueChanged<int> onChanged;
  const _Banner({required this.channels, required this.index, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: Stack(children: [
            PageView.builder(
              controller: controller,
              onPageChanged: onChanged,
              itemCount: channels.length,
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
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
                        child: const Row(children: [
                          Icon(Icons.circle, color: Colors.white, size: 6),
                          SizedBox(width: 4),
                          Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlayerScreen(title: ch.name, url: ch.streamUrl),
                        )),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Assistir Agora'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kRed, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]),
                  ),
                ]);
              },
            ),
            Positioned(
              bottom: 12, right: 16,
              child: Row(children: List.generate(channels.length, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == index ? 16 : 6, height: 6,
                decoration: BoxDecoration(color: i == index ? kRed : Colors.white38, borderRadius: BorderRadius.circular(3)),
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
  final VoidCallback onVerTodos;
  const _SectionHeader({required this.title, required this.onVerTodos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(children: [
        Container(width: 3, height: 18, decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const Spacer(),
        GestureDetector(onTap: onVerTodos, child: const Text('Ver todos >', style: TextStyle(color: kRed, fontSize: 12))),
      ]),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Channel channel;
  const _ChannelCard({required this.channel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(title: channel.name, url: channel.streamUrl),
      )),
      child: Container(
        width: 130, margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            channel.logo != null
                ? CachedNetworkImage(imageUrl: channel.logo!, width: 130, height: 110, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: kSurface, child: const Icon(Icons.live_tv, color: Colors.grey)))
                : Container(color: kSurface, child: const Icon(Icons.live_tv, color: Colors.grey, size: 32)),
            Positioned(top: 6, left: 6, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
              child: const Row(children: [
                Icon(Icons.circle, color: Colors.white, size: 5),
                SizedBox(width: 3),
                Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ]),
            )),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Text(channel.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            )),
          ]),
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlayerScreen(title: movie.name, url: movie.streamUrl),
      )),
      child: Container(
        width: 110, margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            movie.cover != null
                ? CachedNetworkImage(imageUrl: movie.cover!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.grey)))
                : Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.grey, size: 32)),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (movie.genre != null)
                  Text(movie.genre!, style: const TextStyle(color: Colors.grey, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.construction, color: kRed, size: 48),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Em breve...', style: TextStyle(color: Colors.grey)),
    ]));
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}