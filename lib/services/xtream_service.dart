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

  // ── Cache em MEMÓRIA (instantâneo ao trocar de aba) ──────────────────────
  List<Channel>? _memChannels;
  List<Movie>?   _memMovies;
  List<Series>?  _memSeries;
  List<Category>? _memLiveCats;
  List<Category>? _memVodCats;
  List<Category>? _memSeriesCats;

  /// Flags para evitar complementações paralelas
  bool _moviesBgRunning = false;
  bool _seriesBgRunning = false;

  /// Limpa cache de memória e disco (chamado pelo botão Atualizar e Limpar cache)
  void clearMemoryCache() {
    _memChannels  = null;
    _memMovies    = null;
    _memSeries    = null;
    _memLiveCats  = null;
    _memVodCats   = null;
    _memSeriesCats = null;
  }

  /// Limpa TUDO (memória + disco). Usado pelo botão "Atualizar conteúdos"
  /// para forçar nova consulta ao servidor.
  Future<void> clearAllCache() async {
    clearMemoryCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith('cache_') || k.endsWith('_ts')).toList();
      for (final k in keys) await prefs.remove(k);
    } catch (_) {}
  }

  // ── Cache em disco (30 min) ───────────────────────────────────────────────
  static const _cacheTtl = Duration(hours: 6);

  Future<String?> _getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('${key}_ts');
      if (ts == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtl.inMilliseconds) {
        // Limpa entradas expiradas para não acumular lixo em disco
        await prefs.remove(key);
        await prefs.remove('${key}_ts');
        return null;
      }
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

  Future<void> clearCache() => clearAllCache();

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<bool> authenticate() async {
    try {
      final r = await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['user_info'] != null &&
            (data['user_info']['auth'] == 1 || data['user_info']['auth'] == '1');
      }
      return false;
    } catch (_) { return false; }
  }

  // ── Canais ao vivo ────────────────────────────────────────────────────────
  Future<List<Channel>> getLiveChannels() async {
    // 1º: memória
    if (_memChannels != null) return _memChannels!;

    // 2º: disco
    const cacheKey = 'cache_live';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        _memChannels = decoded.whereType<Map>()
            .map((j) => Channel.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password))
            .toList();
        return _memChannels!;
      } catch (_) {}
    }

    // 3º: servidor
    try {
      final r = await http.get(Uri.parse('$_api&action=get_live_streams'))
          .timeout(const Duration(seconds: 45));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        await _setCache(cacheKey, r.body);
        _memChannels = decoded.whereType<Map>()
            .map((j) => Channel.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password))
            .toList();
        return _memChannels!;
      }
    } catch (_) {}
    return [];
  }

  // ── Categorias ────────────────────────────────────────────────────────────
  Future<List<Category>> getLiveCategories()   => _getCategories('get_live_categories',   () => _memLiveCats,   (v) => _memLiveCats = v);
  Future<List<Category>> getVodCategories()    => _getCategories('get_vod_categories',    () => _memVodCats,    (v) => _memVodCats = v);
  Future<List<Category>> getSeriesCategories() => _getCategories('get_series_categories', () => _memSeriesCats, (v) => _memSeriesCats = v);

  Future<List<Category>> _getCategories(
    String action,
    List<Category>? Function() getCache,
    void Function(List<Category>) setCache,
  ) async {
    // 1º: memória
    final mem = getCache();
    if (mem != null) return mem;

    // 2º: disco
    final cacheKey = 'cache_$action';
    final cached = await _getCached(cacheKey);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = decoded.whereType<Map>()
            .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        setCache(list);
        return list;
      } catch (_) {}
    }

    // 3º: servidor
    try {
      final r = await http.get(Uri.parse('$_api&action=$action'))
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        await _setCache(cacheKey, r.body);
        final list = decoded.whereType<Map>()
            .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        setCache(list);
        return list;
      }
    } catch (_) {}
    return [];
  }

  // ── Filmes ────────────────────────────────────────────────────────────────
  Future<List<Movie>> getMovies() async {
    // 1º: memória
    if (_memMovies != null) return _memMovies!;

    // 2º: disco
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
        if (list.isNotEmpty) {
          _memMovies = list;
          return _memMovies!;
        }
      } catch (_) {}
    }

    // 3º: servidor
    final futures = await Future.wait([
      _getMoviesRaw(null),
      getVodCategories(),
    ]);

    final general = futures[0] as List<Movie>;
    final cats    = futures[1] as List<Category>;

    if (general.isNotEmpty) {
      _memMovies = general;
      await _cacheMovies(general);
      _complementMoviesInBackground(general, cats);
      return _memMovies!;
    }

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
    if (result.isNotEmpty) {
      _memMovies = result;
      await _cacheMovies(result);
    }
    return result;
  }

  void _complementMoviesInBackground(List<Movie> existing, List<Category> cats) async {
    if (_moviesBgRunning) return;
    _moviesBgRunning = true;
    try {
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
        _memMovies = [...existing, ...extra];
        await _cacheMovies(_memMovies!);
      }
    } finally {
      _moviesBgRunning = false;
    }
  }

  Future<void> _cacheMovies(List<Movie> list) async {
    try {
      // Guarda os dados completos para não perder plot/genre/rating/year
      // ao ler do cache.
      final full = list.map((m) => {
        'stream_id': m.id,
        'name': m.name,
        'stream_icon': m.cover ?? '',
        'category_id': m.categoryId ?? '',
        'plot': m.plot ?? '',
        'genre': m.genre ?? '',
        'rating': m.rating ?? '',
        'year': m.year ?? '',
      }).toList();
      await _setCache('cache_movies', jsonEncode(full));
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

  // ── Séries ────────────────────────────────────────────────────────────────
  Future<List<Series>> getSeries() async {
    // 1º: memória
    if (_memSeries != null) return _memSeries!;

    // 2º: disco
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
        if (list.isNotEmpty) {
          _memSeries = list;
          return _memSeries!;
        }
      } catch (_) {}
    }

    // 3º: servidor
    final futures = await Future.wait([
      _getSeriesRaw(null),
      getSeriesCategories(),
    ]);

    final general = futures[0] as List<Series>;
    final cats    = futures[1] as List<Category>;

    if (general.isNotEmpty) {
      _memSeries = general;
      await _cacheSeries(general);
      _complementSeriesInBackground(general, cats);
      return _memSeries!;
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
    if (result.isNotEmpty) {
      _memSeries = result;
      await _cacheSeries(result);
    }
    return result;
  }

  void _complementSeriesInBackground(List<Series> existing, List<Category> cats) async {
    if (_seriesBgRunning) return;
    _seriesBgRunning = true;
    try {
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
      if (extra.isNotEmpty) {
        _memSeries = [...existing, ...extra];
        await _cacheSeries(_memSeries!);
      }
    } finally {
      _seriesBgRunning = false;
    }
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

  // ── Series info / EPG ─────────────────────────────────────────────────────
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
