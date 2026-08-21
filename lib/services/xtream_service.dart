import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/epg.dart';

class XtreamService {
  static const String baseUrl = 'https://servertv.dreamserver.shop';

  final String username;
  final String password;

  XtreamService({required this.username, required this.password});

  String get _api => '$baseUrl/player_api.php?username=$username&password=$password';

  Future<bool> authenticate() async {
    try {
      final r = await http.get(Uri.parse(_api)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['user_info'] != null &&
            (data['user_info']['auth'] == 1 || data['user_info']['auth'] == '1');
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
          .timeout(const Duration(seconds: 45));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((j) => Channel.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Category>> getLiveCategories() => _getCategories('get_live_categories');
  Future<List<Category>> getVodCategories() => _getCategories('get_vod_categories');
  Future<List<Category>> getSeriesCategories() => _getCategories('get_series_categories');

  Future<List<Category>> _getCategories(String action) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=$action'))
          .timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        return decoded
            .whereType<Map>()
            .map((j) => Category.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Movie>> getMovies() async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_vod_streams'))
          .timeout(const Duration(seconds: 60));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is! List) return [];
        final list = <Movie>[];
        for (final j in decoded) {
          if (j is Map) {
            try {
              list.add(Movie.fromJson(Map<String, dynamic>.from(j), baseUrl, username, password));
            } catch (_) {}
          }
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  /// 1) Lista completa  2) Se vazio, carrega por categoria

  /// SEMPRE por categoria — get_series sem filtro só traz poucos itens no painel.
  Future<List<Series>> getSeries() async {
    final cats = await getSeriesCategories();
    final seen = <String>{};
    final result = <Series>[];

    if (cats.isNotEmpty) {
      for (final cat in cats) {
        final list = await _getSeriesRaw(cat.id);
        for (final s in list) {
          if (s.id.isNotEmpty && seen.add(s.id)) result.add(s);
        }
      }
    }

    // complementa com lista geral
    final all = await _getSeriesRaw(null);
    for (final s in all) {
      if (s.id.isNotEmpty && seen.add(s.id)) result.add(s);
    }
    return result;
  }

  Future<List<Series>> _getSeriesRaw(String? categoryId) async {
    try {
      var url = '$_api&action=get_series';
      if (categoryId != null && categoryId.isNotEmpty) {
        url += '&category_id=$categoryId';
      }
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
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSeriesInfo(String seriesId) async {
    try {
      final r = await http
          .get(Uri.parse('$_api&action=get_series_info&series_id=$seriesId'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  String seriesEpisodeUrl(String seriesId, String episodeId, String ext) {
    return '$baseUrl/series/$username/$password/$episodeId.$ext';
  }

  Future<List<EpgProgram>> getEpgForChannel(String streamId) async {
    try {
      final url = '$_api&action=get_simple_data_table&stream_id=$streamId';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
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

  Future<List<EpgChannel>> getEpg({
    required List<Channel> channels,
    int limit = 6,
  }) async {
    final result = <EpgChannel>[];
    const batchSize = 8;
    for (var i = 0; i < channels.length; i += batchSize) {
      final batch = channels.skip(i).take(batchSize).toList();
      final programsList = await Future.wait(
        batch.map((c) => _getSimpleEpg(c.id, limit: limit)),
      );
      for (var j = 0; j < batch.length; j++) {
        if (programsList[j].isNotEmpty) {
          result.add(EpgChannel(channel: batch[j], programs: programsList[j]));
        }
      }
    }
    return result;
  }

  Future<List<EpgProgram>> _getSimpleEpg(String streamId, {int limit = 6}) async {
    try {
      final url = '$_api&action=get_short_epg&stream_id=$streamId&limit=$limit';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final List epgList = data is Map ? (data['epg_listings'] ?? []) : [];
        return epgList
            .map((e) => EpgProgram.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
