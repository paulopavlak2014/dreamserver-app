import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../models/epg.dart';
import 'player_screen.dart';

const _kRed = Color(0xFFE50914);
const _kBg = Color(0xFF0A0A0A);
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
  Map<String, List<EpgProgram>> _epg = {};
  bool _loading = true;
  bool _loadingEpg = false;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty
          ? _channels
          : _channels.where((c) => c.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getLiveChannels();
    setState(() {
      _channels = data;
      _filtered = data;
      _loading = false;
    });
    _loadEpg();
  }

  Future<void> _loadEpg() async {
    setState(() => _loadingEpg = true);
    final epg = await widget.service.getShortEpg();
    if (mounted) setState(() { _epg = epg; _loadingEpg = false; });
  }

  List<EpgProgram> _epgFor(String channelId) {
    return _epg[channelId] ?? _epg[channelId.toString()] ?? [];
  }

  EpgProgram? _currentProgram(String channelId) {
    final list = _epgFor(channelId);
    try {
      return list.firstWhere((e) => e.isLive);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 48),
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          const Text('TV Ao Vivo', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_loadingEpg)
            const Row(children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: _kRed, strokeWidth: 2)),
              SizedBox(width: 6),
              Text('Carregando EPG...', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
        ]),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Buscar canal...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: _kCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kRed))
            : _filtered.isEmpty
                ? const Center(child: Text('Nenhum canal encontrado', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      final current = _currentProgram(c.id);
                      return _ChannelTile(
                        channel: c,
                        currentProgram: current,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PlayerScreen(title: c.name, url: c.streamUrl),
                        )),
                        onEpgTap: () => _showEpgSheet(context, c),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _showEpgSheet(BuildContext context, Channel channel) {
    final programs = _epgFor(channel.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            if (channel.logo != null)
              CachedNetworkImage(imageUrl: channel.logo!, width: 40, height: 26, fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.grey)),
            const SizedBox(width: 10),
            Expanded(child: Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white12),
        Expanded(
          child: programs.isEmpty
              ? const Center(child: Text('EPG não disponível', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: programs.length,
                  itemBuilder: (_, i) {
                    final p = programs[i];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.isLive ? _kRed.withOpacity(0.15) : _kSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: p.isLive ? Border.all(color: _kRed.withOpacity(0.5)) : null,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (p.isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(4)),
                              child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(p.timeRange, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        Text(p.title, style: TextStyle(color: p.isLive ? Colors.white : Colors.white70, fontWeight: p.isLive ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                        if (p.isLive) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: p.progress,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(_kRed),
                              minHeight: 4,
                            ),
                          ),
                        ],
                        if (p.description != null && p.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(p.description!, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
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

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final EpgProgram? currentProgram;
  final VoidCallback onTap;
  final VoidCallback onEpgTap;

  const _ChannelTile({required this.channel, this.currentProgram, required this.onTap, required this.onEpgTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          // Logo
          Container(
            width: 80, height: 60,
            decoration: const BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: channel.logo != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    child: CachedNetworkImage(imageUrl: channel.logo!, fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv, color: Colors.grey)))
                : const Icon(Icons.live_tv, color: Colors.grey),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (currentProgram != null) ...[
                  const SizedBox(height: 4),
                  Text(currentProgram!.title, style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: currentProgram!.progress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(_kRed),
                      minHeight: 3,
                    ),
                  ),
                ],
              ]),
            ),
          ),
          // EPG button
          IconButton(
            icon: const Icon(Icons.format_list_bulleted, color: Colors.grey, size: 20),
            onPressed: onEpgTap,
            tooltip: 'Ver programação',
          ),
        ]),
      ),
    );
  }
}