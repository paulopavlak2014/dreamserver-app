import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class XtreamService {
  // ── CONFIGURAÇÃO ─────────────────────────────────────────
  static const String baseUrl = 'https://dreamserver.shop';
  // ────────────────────────────────────────────────────────

  final String username;
  final String password;

  XtreamService({required this.username, required this.password});

  String get _api => '$baseUrl/player_api.php?username=$username&password=$password';

  Future<bool> authenticate() async {
    try {
      final r = await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['user_info'] != null &&
            data['user_info']['auth'] == 1 || data['user_info']['auth'] == '1';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Channel>> getLiveChannels() async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_live_streams'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map((j) => Channel.fromJson(j, baseUrl, username, password)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, String>> getLiveCategories() async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_live_categories'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return {
          for (final c in data)
            (c['category_id'] ?? '').toString(): (c['category_name'] ?? '').toString()
        };
      }
    } catch (_) {}
    return {};
  }

  /// Busca EPG via API Xtream (JSON) para um canal específico ou todos.
  /// [streamId] null = todos os canais (pode ser pesado); forneça o id para buscar um canal.
  /// [limit] número de programas por canal (padrão 4 — atual + próximos).
  Future<List<EpgChannel>> getEpg({
    String? streamId,
    List<Channel>? channels,
    int limit = 4,
  }) async {
    try {
      // Endpoint de EPG curto (atual + próximos) — leve e suportado pelo xmltv.php
      final url = streamId != null
          ? '$_api&action=get_short_epg&stream_id=$streamId&limit=$limit'
          : '$_api&action=get_short_epg&limit=$limit';

      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return [];

      final body = jsonDecode(r.body);

      // Formato: { "epg_listings": [ { channel_id, title, start, end, ... } ] }
      // ou ao buscar todos: { "123": [ {...} ], "456": [ {...} ] }
      final List<EpgChannel> result = [];

      if (body is Map && body.containsKey('epg_listings')) {
        // Um canal específico
        final listings = body['epg_listings'] as List? ?? [];
        final programs = listings.map((e) => _parseProgram(e, streamId ?? '')).whereType<EpgProgram>().toList();
        if (channels != null && streamId != null) {
          final ch = channels.firstWhere((c) => c.id == streamId, orElse: () => Channel(id: streamId, name: streamId, streamUrl: ''));
          result.add(EpgChannel(channel: ch, programs: programs));
        }
      } else if (body is Map) {
        // Múltiplos canais
        for (final entry in body.entries) {
          final cid = entry.key.toString();
          final listings = (entry.value as List?) ?? [];
          final programs = listings.map((e) => _parseProgram(e, cid)).whereType<EpgProgram>().toList();
          Channel? ch;
          if (channels != null) {
            try {
              ch = channels.firstWhere((c) => c.id == cid);
            } catch (_) {}
          }
          ch ??= Channel(id: cid, name: 'Canal $cid', streamUrl: '');
          result.add(EpgChannel(channel: ch, programs: programs));
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  /// Busca EPG completo de um canal (hoje) via get_simple_data_table
  Future<List<EpgProgram>> getChannelEpgToday(String streamId) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_simple_data_table&stream_id=$streamId'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body);
      final listings = body['epg_listings'] as List? ?? [];
      return listings.map((e) => _parseProgram(e, streamId)).whereType<EpgProgram>().toList();
    } catch (_) {
      return [];
    }
  }

  EpgProgram? _parseProgram(dynamic e, String channelId) {
    try {
      // título pode estar em base64
      String title = e['title'] ?? '';
      try {
        final decoded = utf8.decode(base64Decode(title));
        if (decoded.isNotEmpty) title = decoded;
      } catch (_) {}

      String? desc = e['description'];
      if (desc != null && desc.isNotEmpty) {
        try {
          desc = utf8.decode(base64Decode(desc));
        } catch (_) {}
      }

      // start/end podem ser unix timestamp (int ou string) ou ISO string
      DateTime parseTime(dynamic v) {
        if (v == null) throw Exception('null time');
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        final s = v.toString();
        // Tenta unix timestamp como string
        final n = int.tryParse(s);
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        // ISO 8601
        return DateTime.parse(s).toLocal();
      }

      final start = parseTime(e['start'] ?? e['start_timestamp']);
      final end = parseTime(e['stop'] ?? e['end'] ?? e['stop_timestamp']);

      return EpgProgram(
        title: title.isEmpty ? 'Sem informação' : title,
        description: (desc?.isEmpty ?? true) ? null : desc,
        start: start,
        end: end,
        channelId: e['channel_id']?.toString() ?? channelId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Movie>> getMovies() async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_vod_streams'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map((j) => Movie.fromJson(j, baseUrl, username, password)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Series>> getSeries() async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_series'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map((j) => Series.fromJson(j)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getSeriesInfo(String seriesId) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_series_info&series_id=$seriesId'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  String seriesEpisodeUrl(String seriesId, String episodeId, String ext) {
    return '$baseUrl/series/$username/$password/$episodeId.$ext';
  }
}
