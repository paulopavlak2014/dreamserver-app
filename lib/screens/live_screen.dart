import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

class LiveScreen extends StatefulWidget {
  final XtreamService service;
  const LiveScreen({super.key, required this.service});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Channel> _channels = [];
  List<Channel> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty ? _channels : _channels.where((c) => c.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getLiveChannels();
    setState(() { _channels = data; _filtered = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar canal...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    return ListTile(
                      leading: c.logo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: c.logo!,
                                width: 48, height: 32,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.live_tv, color: Colors.grey),
                      title: Text(c.name, style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlayerScreen(title: c.name, url: c.streamUrl),
                      )),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
