import 'package:flutter/material.dart';
import '../services/xtream_service.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'epg_screen.dart';

class HomeScreen extends StatefulWidget {
  final XtreamService service;
  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: IndexedStack(
        index: _tab,
        children: [
          LiveScreen(service: widget.service),
          EpgScreen(service: widget.service),
          MoviesScreen(service: widget.service),
          SeriesScreen(service: widget.service),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF141414),
        indicatorColor: const Color(0xFFE50914),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv), label: 'Ao Vivo'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'EPG'),
          NavigationDestination(icon: Icon(Icons.movie), label: 'Filmes'),
          NavigationDestination(icon: Icon(Icons.tv), label: 'Séries'),
        ],
      ),
    );
  }
}
