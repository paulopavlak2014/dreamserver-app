import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';

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
      setState(() => _filtered = q.isEmpty ? _series : _series.where((s) => s.name.toLowerCase().contains(q)).toList());
    });
  }

  Future<void> _load() async {
    final data = await widget.service.getSeries();
    setState(() { _series = data; _filtered = data; _loading = false; });
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final s = _filtered[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          s.cover != null
                              ? CachedNetworkImage(imageUrl: s.cover!, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A1A),
                                    child: const Icon(Icons.tv, color: Colors.grey, size: 40)))
                              : Container(color: const Color(0xFF1A1A1A),
                                  child: const Icon(Icons.tv, color: Colors.grey, size: 40)),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                              child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 11),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
