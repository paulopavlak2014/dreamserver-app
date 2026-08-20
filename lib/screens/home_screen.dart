import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'player_screen.dart';
import 'epg_screen.dart';
import 'settings_screen.dart';

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

  static const _navItems = [
    _NavItem(Icons.home_rounded, 'Início'),
    _NavItem(Icons.live_tv_rounded, 'TV Ao Vivo'),
    _NavItem(Icons.grid_view_rounded, 'EPG'),
    _NavItem(Icons.movie_rounded, 'Filmes'),
    _NavItem(Icons.tv_rounded, 'Séries'),
    _NavItem(Icons.sports_soccer_rounded, 'Esportes'),
    _NavItem(Icons.replay_rounded, 'Replay'),
    _NavItem(Icons.favorite_rounded, 'Favoritos'),
    _NavItem(Icons.settings_rounded, 'Config'),
  ];

  Widget _buildPage() {
    switch (_tab) {
      case 0: return _HomePage(service: widget.service);
      case 1: return LiveScreen(service: widget.service);
      case 2: return EpgScreen(service: widget.service);
      case 3: return MoviesScreen(service: widget.service);
      case 4: return SeriesScreen(service: widget.service);
      case 8: return SettingsScreen(service: widget.service);
      default: return _ComingSoon(label: _navItems[_tab].label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [
        // Sidebar — largura fixa pequena
        Container(
          width: 58,
          color: const Color(0xFF0F0F0F),
          child: Column(children: [
            const SizedBox(height: 16),
            // Logo
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
                  final sel = _tab == i;
                  return Tooltip(
                    message: item.label,
                    preferBelow: false,
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? kRed.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: sel ? Border.all(color: kRed.withOpacity(0.5)) : null,
                        ),
                        child: Icon(item.icon, color: sel ? kRed : Colors.grey, size: 22),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        // Main content
        Expanded(child: _buildPage()),
      ]),
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
        controller: _pageCtrl, onChanged: (i) => setState(() => _bannerIndex = i),
      )),
      if (_live.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: 'Canais em Destaque')),
        SliverToBoxAdapter(child: SizedBox(height: 100, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _live.take(10).length,
          itemBuilder: (_, i) => _ChannelCard(channel: _live[i]),
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
        IconButton(icon: const Icon(Icons.search, color: Colors.white, size: 20), onPressed: () {}),
        IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white, size: 20), onPressed: () {}),
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(color: Colors.green, fontSize: 10)),
        ]),
        const SizedBox(width: 8),
        const CircleAvatar(backgroundColor: kRed, radius: 14, child: Icon(Icons.person, color: Colors.white, size: 16)),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(4)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.circle, color: Colors.white, size: 5),
                          SizedBox(width: 3),
                          Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlayerScreen(title: ch.name, url: ch.streamUrl),
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
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const Spacer(),
        const Text('Ver todos >', style: TextStyle(color: kRed, fontSize: 11)),
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
        width: 120, margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            channel.logo != null
                ? CachedNetworkImage(imageUrl: channel.logo!, width: 120, height: 100, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: kSurface, child: const Icon(Icons.live_tv, color: Colors.grey)))
                : Container(color: kSurface, child: const Icon(Icons.live_tv, color: Colors.grey)),
            Positioned(top: 5, left: 5, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(3)),
              child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
            )),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Text(channel.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
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
        width: 95, margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(10)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            movie.cover != null
                ? CachedNetworkImage(imageUrl: movie.cover!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.grey)))
                : Container(color: kSurface, child: const Icon(Icons.movie, color: Colors.grey)),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
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
      const Icon(Icons.construction, color: kRed, size: 40),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Em breve...', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]));
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}