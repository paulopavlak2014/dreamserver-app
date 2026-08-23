import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/player_screen.dart';

// ─── Modelos ──────────────────────────────────────────────────────────────────

class LiveChannel {
  final String name;
  final String url;
  final String? logo;
  final String? group;
  final String source; // 'xtream' | 'm3u'

  const LiveChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group,
    required this.source,
  });
}

// ─── Parser M3U ───────────────────────────────────────────────────────────────

class M3UParser {
  static List<LiveChannel> parse(String content) {
    final channels = <LiveChannel>[];
    final lines = content.split('\n');

    String? currentName;
    String? currentLogo;
    String? currentGroup;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        currentName = _extract(line, 'tvg-name') ?? _extractAfterComma(line);
        currentLogo = _extract(line, 'tvg-logo');
        currentGroup = _extract(line, 'group-title');
      } else if (!line.startsWith('#') && line.isNotEmpty) {
        if (currentName != null) {
          channels.add(LiveChannel(
            name: currentName,
            url: line,
            logo: currentLogo,
            group: currentGroup,
            source: 'm3u',
          ));
        }
        currentName = null;
        currentLogo = null;
        currentGroup = null;
      }
    }
    return channels;
  }

  static String? _extract(String line, String attr) {
    final regex = RegExp('$attr="([^"]*)"');
    return regex.firstMatch(line)?.group(1);
  }

  static String? _extractAfterComma(String line) {
    final idx = line.lastIndexOf(',');
    return idx >= 0 ? line.substring(idx + 1).trim() : null;
  }
}

// ─── Tela principal ───────────────────────────────────────────────────────────

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveChannel> _allChannels = [];
  List<LiveChannel> _filtered = [];
  Map<String, List<LiveChannel>> _grouped = {};

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedGroup;
  List<String> _groups = [];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Carregamento ────────────────────────────────────────────────────────────

  Future<void> _loadChannels() async {
    setState(() { _loading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    final m3uUrl = prefs.getString('m3u_url');
    final xtreamServer = prefs.getString('server_url');
    final xtreamUser = prefs.getString('username');
    final xtreamPass = prefs.getString('password');

    final results = await Future.wait([
      if (m3uUrl != null && m3uUrl.isNotEmpty) _fetchM3U(m3uUrl),
      if (xtreamServer != null && xtreamUser != null && xtreamPass != null)
        _fetchXtream(xtreamServer, xtreamUser, xtreamPass),
    ]);

    final all = results.expand((r) => r).toList();

    if (!mounted) return;

    if (all.isEmpty && _error == null) {
      setState(() {
        _loading = false;
        _error = 'Nenhuma fonte configurada.\nAcesse Configurações e adicione um servidor ou URL M3U.';
      });
      return;
    }

    // Ordenar: Xtream primeiro, depois M3U, por nome dentro de cada grupo
    all.sort((a, b) {
      if (a.source != b.source) return a.source == 'xtream' ? -1 : 1;
      return a.name.compareTo(b.name);
    });

    final groups = all
        .map((c) => c.group ?? 'Sem categoria')
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _allChannels = all;
      _groups = ['Todos', ...groups];
      _selectedGroup = 'Todos';
      _loading = false;
      _applyFilters();
    });
  }

  Future<List<LiveChannel>> _fetchM3U(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        return M3UParser.parse(utf8.decode(res.bodyBytes));
      }
      setState(() => _error = 'Erro M3U: HTTP ${res.statusCode}');
    } catch (e) {
      setState(() => _error = 'Erro ao carregar M3U: $e');
    }
    return [];
  }

  Future<List<LiveChannel>> _fetchXtream(
      String server, String user, String pass) async {
    try {
      final base = server.endsWith('/') ? server.dropLast(1) : server;
      final uri = Uri.parse(
          '$base/player_api.php?username=$user&password=$pass&action=get_live_streams');
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((ch) {
          final streamId = ch['stream_id']?.toString() ?? '';
          final ext = ch['container_extension'] ?? 'ts';
          final streamUrl = '$base/live/$user/$pass/$streamId.$ext';
          return LiveChannel(
            name: ch['name'] ?? 'Canal $streamId',
            url: streamUrl,
            logo: ch['stream_icon'],
            group: ch['category_name'],
            source: 'xtream',
          );
        }).toList();
      }
    } catch (e) {
      setState(() => _error = 'Erro Xtream: $e');
    }
    return [];
  }

  // ── Filtros ─────────────────────────────────────────────────────────────────

  void _applyFilters() {
    var list = _allChannels;

    if (_selectedGroup != null && _selectedGroup != 'Todos') {
      list = list
          .where((c) => (c.group ?? 'Sem categoria') == _selectedGroup)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    // Agrupa para exibição em seções
    final grouped = <String, List<LiveChannel>>{};
    for (final ch in list) {
      final g = ch.group ?? 'Sem categoria';
      grouped.putIfAbsent(g, () => []).add(ch);
    }

    setState(() {
      _filtered = list;
      _grouped = grouped;
    });
  }

  void _onSearch(String q) {
    _searchQuery = q;
    _applyFilters();
  }

  void _selectGroup(String group) {
    setState(() => _selectedGroup = group);
    _applyFilters();
  }

  // ── Navegação ────────────────────────────────────────────────────────────────

  void _openChannel(LiveChannel ch) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: ch.url,
        title: ch.name,
        logo: ch.logo,
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          _buildHeader(),
          if (!_loading && _error == null) _buildGroupFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          const Text(
            'Ao Vivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_allChannels.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_allChannels.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadChannels,
            tooltip: 'Recarregar',
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilter() {
    return Container(
      height: 44,
      color: const Color(0xFF1A1A1A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _groups.length,
        itemBuilder: (_, i) {
          final g = _groups[i];
          final selected = g == _selectedGroup;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectGroup(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  g,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null && _allChannels.isEmpty) return _buildError();

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildChannelList()),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB71C1C)),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando canais...',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: _loadChannels,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar canal...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildChannelList() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum canal encontrado',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    // Exibe em seções por grupo quando "Todos" está selecionado
    if (_selectedGroup == 'Todos' && _searchQuery.isEmpty) {
      return _buildSectionedList();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildChannelTile(_filtered[i]),
    );
  }

  Widget _buildSectionedList() {
    final sections = _grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sections.fold(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (ctx, idx) {
        // Mapeia índice flat para seção + item
        var remaining = idx;
        for (final section in sections) {
          if (remaining == 0) return _buildGroupHeader(section.key);
          remaining--;
          if (remaining < section.value.length) {
            return _buildChannelTile(section.value[remaining]);
          }
          remaining -= section.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGroupHeader(String group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        group.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFB71C1C),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildChannelTile(LiveChannel ch) {
    return ListTile(
      onTap: () => _openChannel(ch),
      leading: _buildLogo(ch),
      title: Text(
        ch.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: ch.group != null
          ? Text(
              ch.group!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        Icons.play_circle_outline,
        color: Colors.white.withOpacity(0.2),
        size: 22,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _buildLogo(LiveChannel ch) {
    if (ch.logo != null && ch.logo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          ch.logo!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultLogo(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _defaultLogo(),
        ),
      );
    }
    return _defaultLogo();
  }

  Widget _defaultLogo() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.tv, color: Colors.white24, size: 22),
    );
  }
}

// ── Extensão auxiliar ─────────────────────────────────────────────────────────
extension on String {
  String dropLast(int n) => substring(0, length - n);
}
