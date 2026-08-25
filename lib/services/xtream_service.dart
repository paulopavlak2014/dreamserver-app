import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';
import '../models/epg.dart';

class XtreamService {
  static const String baseUrl = 'https://serverbr.dreamserver.shop';

  final String username;
  final String password;

  XtreamService({required this.username, required this.password});

  String get _api => '$baseUrl/player_api.php?username=$username&password=$password';

  // ── Cache local ──────────────────────────────────────────
  // Validade do cache: 30 minutos
  static const _cacheTtl = Duration(minutes: 30);

  Future<String?> _getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('${key}_ts');
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtl.inMilliseconds) return null;
      return prefs.getString(key);
    } catch (_) { return null; }
  }

  Future<void> _setCache(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith('cache_') || k.endsWith('_ts')).toList();
      for (final k in keys) await prefs.remove(k);
    } catch (_) {}
  }

  // ── Auth ────────────────────────────────────────────────
  Future<bool> authenticate() async {
    try {
      final r = await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['user_info'] != null &&
            (data['user_info']['auth'] == 1 || data['user_info']['auth'] == '1');
      }
      return false;
    } catch (_) { return false; }
  }

  // ── Canais ao vivo ───────────────────────────────────────
  Future<List<Channel>> getLiveChannels() async {
    const cacheKey = 'cache_live';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded.whereType<Map>()
            .map((j) => Channel.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password))
            .toList();
      } catch (_) {}
    }

    try {
      final r = await http.get(Uri.parse('$_api&action=get_live_streams'))
          .timeout(const Duration(seconds: 45));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        await _setCache(cacheKey, r.body);
        return decoded.whereType<Map>()
            .map((j) => Channel.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Categorias ───────────────────────────────────────────
  Future<List<Category>> getLiveCategories() => _getCategories('get_live_categories');
  Future<List<Category>> getVodCategories() => _getCategories('get_vod_categories');
  Future<List<Category>> getSeriesCategories() => _getCategories('get_series_categories');

  Future<List<Category>> _getCategories(String action) async {
    final cacheKey = 'cache_$action';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded.whereType<Map>()
            .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      } catch (_) {}
    }

    try {
      final r = await http.get(Uri.parse('$_api&action=$action'))
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        await _setCache(cacheKey, r.body);
        return decoded.whereType<Map>()
            .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Filmes — 1 request só, paralelo com categorias ───────
  Future<List<Movie>> getMovies() async {
    const cacheKey = 'cache_movies';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = <Movie>[];
        for (final j in decoded) {
          if (j is Map) {
            try { list.add(Movie.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password)); }
            catch (_) {}
          }
        }
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // Faz lista geral + categorias em paralelo
    final futures = await Future.wait([
      _getMoviesRaw(null),           // lista geral primeiro
      getVodCategories(),
    ]);

    final general = futures[0] as List<Movie>;
    final cats    = futures[1] as List<Category>;

    // Se a lista geral já tem tudo, usa ela
    if (general.isNotEmpty) {
      await _cacheMovies(general);
      // Ainda busca por categoria em paralelo para complementar
      _complementMoviesInBackground(general, cats);
      return general;
    }

    // Se lista geral veio vazia, busca por categoria em paralelo (lotes de 5)
    final seen = <String>{};
    final result = <Movie>[];
    const batchSize = 5;
    for (var i = 0; i < cats.length; i += batchSize) {
      final batch = cats.skip(i).take(batchSize).toList();
      final lists = await Future.wait(batch.map((c) => _getMoviesRaw(c.id)));
      for (final list in lists) {
        for (final m in list) {
          if (m.id.isNotEmpty && seen.add(m.id)) result.add(m);
        }
      }
    }
    if (result.isNotEmpty) await _cacheMovies(result);
    return result;
  }

  void _complementMoviesInBackground(List<Movie> existing, List<Category> cats) async {
    // Roda em background sem bloquear a UI
    final seen = existing.map((m) => m.id).toSet();
    final extra = <Movie>[];
    const batchSize = 5;
    for (var i = 0; i < cats.length; i += batchSize) {
      final batch = cats.skip(i).take(batchSize).toList();
      final lists = await Future.wait(batch.map((c) => _getMoviesRaw(c.id)));
      for (final list in lists) {
        for (final m in list) {
          if (m.id.isNotEmpty && seen.add(m.id)) extra.add(m);
        }
      }
    }
    if (extra.isNotEmpty) {
      await _cacheMovies([...existing, ...extra]);
    }
  }

  Future<void> _cacheMovies(List<Movie> list) async {
    try {
      // Salva só os campos essenciais para não estourar o limite do SharedPreferences
      final slim = list.map((m) => {
        'stream_id': m.id, 'name': m.name,
        'stream_url': m.streamUrl, 'stream_icon': m.cover ?? '',
        'category_id': m.categoryId ?? '',
      }).toList();
      await _setCache('cache_movies', jsonEncode(slim));
    } catch (_) {}
  }

  Future<List<Movie>> _getMoviesRaw(String? categoryId) async {
    try {
      var url = '$_api&action=get_vod_streams';
      if (categoryId != null && categoryId.isNotEmpty) url += '&category_id=$categoryId';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (r.statusCode != 200 || r.body.isEmpty) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is! List) return [];
      final list = <Movie>[];
      for (final j in decoded) {
        if (j is Map) {
          try { list.add(Movie.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password)); }
          catch (_) {}
        }
      }
      return list;
    } catch (_) { return []; }
  }

  // ── Séries — mesmo padrão paralelo ───────────────────────
  Future<List<Series>> getSeries() async {
    const cacheKey = 'cache_series';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = <Series>[];
        for (final j in decoded) {
          if (j is Map) {
            try {
              final s = Series.fromJson(Map<String, dynamic>.from(j));
              if (s.id.isNotEmpty) list.add(s);
            } catch (_) {}
          }
        }
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    final futures = await Future.wait([
      _getSeriesRaw(null),
      getSeriesCategories(),
    ]);

    final general = futures[0] as List<Series>;
    final cats    = futures[1] as List<Category>;

    if (general.isNotEmpty) {
      await _cacheSeries(general);
      _complementSeriesInBackground(general, cats);
      return general;
    }

    final seen = <String>{};
    final result = <Series>[];
    const batchSize = 5;
    for (var i = 0; i < cats.length; i += batchSize) {
      final batch = cats.skip(i).take(batchSize).toList();
      final lists = await Future.wait(batch.map((c) => _getSeriesRaw(c.id)));
      for (final list in lists) {
        for (final s in list) {
          if (s.id.isNotEmpty && seen.add(s.id)) result.add(s);
        }
      }
    }
    if (result.isNotEmpty) await _cacheSeries(result);
    return result;
  }

  void _complementSeriesInBackground(List<Series> existing, List<Category> cats) async {
    final seen = existing.map((s) => s.id).toSet();
    final extra = <Series>[];
    const batchSize = 5;
    for (var i = 0; i < cats.length; i += batchSize) {
      final batch = cats.skip(i).take(batchSize).toList();
      final lists = await Future.wait(batch.map((c) => _getSeriesRaw(c.id)));
      for (final list in lists) {
        for (final s in list) {
          if (s.id.isNotEmpty && seen.add(s.id)) extra.add(s);
        }
      }
    }
    if (extra.isNotEmpty) await _cacheSeries([...existing, ...extra]);
  }

  Future<void> _cacheSeries(List<Series> list) async {
    try {
      final slim = list.map((s) => {
        'series_id': s.id, 'name': s.name,
        'cover': s.cover ?? '', 'category_id': s.categoryId ?? '',
      }).toList();
      await _setCache('cache_series', jsonEncode(slim));
    } catch (_) {}
  }

  Future<List<Series>> _getSeriesRaw(String? categoryId) async {
    try {
      var url = '$_api&action=get_series';
      if (categoryId != null && categoryId.isNotEmpty) url += '&category_id=$categoryId';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (r.statusCode != 200 || r.body.isEmpty) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is! List) return [];
      final list = <Series>[];
      for (final j in decoded) {
        if (j is Map) {
          try {
            final s = Series.fromJson(Map<String, dynamic>.from(j));
            if (s.id.isNotEmpty) list.add(s);
          } catch (_) {}
        }
      }
      return list;
    } catch (_) { return []; }
  }

  // ── EPG ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getSeriesInfo(String seriesId) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_series_info&series_id=$seriesId'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  String seriesEpisodeUrl(String seriesId, String episodeId, String ext) =>
      '$baseUrl/series/$username/$password/$episodeId.$ext';

  Future<List<EpgProgram>> getEpgForChannel(String streamId) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_simple_data_table&stream_id=$streamId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final List epgList = data['epg_listings'] ?? [];
        return epgList.map((e) => EpgProgram.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<EpgProgram?> getCurrentProgram(String streamId) async {
    final list = await getEpgForChannel(streamId);
    final now = DateTime.now();
    for (final p in list) {
      if (now.isAfter(p.start) && now.isBefore(p.end)) return p;
    }
    return null;
  }

  Future<List<EpgChannel>> getEpg({required List<Channel> channels, int limit = 6}) async {
    final result = <EpgChannel>[];
    const batchSize = 8;
    for (var i = 0; i < channels.length; i += batchSize) {
      final batch = channels.skip(i).take(batchSize).toList();
      final programsList = await Future.wait(batch.map((c) => _getSimpleEpg(c.id, limit: limit)));
      for (var j = 0; j < batch.length; j++) {
        if (programsList[j].isNotEmpty) result.add(EpgChannel(channel: batch[j], programs: programsList[j]));
      }
    }
    return result;
  }

  Future<List<EpgProgram>> _getSimpleEpg(String streamId, {int limit = 6}) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_short_epg&stream_id=$streamId&limit=$limit'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final List epgList = data is Map ? (data['epg_listings'] ?? []) : [];
        return epgList.map((e) => EpgProgram.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
