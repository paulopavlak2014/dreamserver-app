import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import 'player_screen.dart';

class SeriesScreen extends StatefulWidget {
  final XtreamService service;
  const SeriesScreen({super.key, required this.service});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Series> _series = [];
  List<Series> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      final q = _search.text.toLowerCase();
      setState(() => _filtered = q.isEmpty
          ? _series
          : _series.where((s) => s.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getSeries();
    setState(() {
      _series = data;
      _filtered = data;
      _loading = false;
    });
  }

  Future<void> _openSeries(Series s) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );

    final info = await widget.service.getSeriesInfo(s.id);
    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível carregar os episódios.')),
      );
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
        const SnackBar(content: Text('Nenhum episódio encontrado.')),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: episodes.length,
                    itemBuilder: (_, i) {
                      final ep = episodes[i];
                      final title = ep['title']?.toString() ??
                          'Episódio ${ep['episode_num'] ?? (i + 1)}';
                      final id = ep['id']?.toString() ?? '';
                      final ext = ep['container_extension']?.toString() ?? 'mp4';
                      return ListTile(
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'S${ep['season'] ?? '?'} E${ep['episode_num'] ?? '?'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.play_arrow, color: Color(0xFFE50914)),
                        onTap: () {
                          Navigator.pop(ctx);
                          final url = widget.service.seriesEpisodeUrl(s.id, id, ext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(title: title, url: url),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
              hintText: 'Buscar série...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                )
              : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma série encontrada',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 110,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2 / 3,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        return GestureDetector(
                          onTap: () => _openSeries(s),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                s.cover != null
                                    ? CachedNetworkImage(
                                        imageUrl: s.cover!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            Container(
                                          color: const Color(0xFF1A1A1A),
                                          child: const Icon(
                                            Icons.tv,
                                            color: Colors.grey,
                                            size: 32,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF1A1A1A),
                                        child: const Icon(
                                          Icons.tv,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      s.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
