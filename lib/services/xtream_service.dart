import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/epg.dart';

class XtreamService {
  static const String baseUrl = 'https://dreamserver.shop';

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
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map((j) => Channel.fromJson(j, baseUrl, username, password)).toList();
      }
    } catch (_) {}
    return [];
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

  /// Busca EPG simples por stream_id
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

  /// Busca a grade de EPG para uma lista de canais (usado na tela de EPG).
  /// Faz uma chamada por canal em paralelo (limitando concorrência) para
  /// evitar sobrecarregar o painel e travar a tela.
  Future<List<EpgChannel>> getEpg({
    required List<Channel> channels,
    int limit = 6,
  }) async {
    final result = <EpgChannel>[];
    const batchSize = 8; // evita disparar muitas requisições de uma vez

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

  /// Busca EPG de todos os canais (short EPG)
  Future<Map<String, List<EpgProgram>>> getShortEpg() async {
    try {
      final url = '$_api&action=get_short_epg&stream_id=all&limit=4';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final Map<String, List<EpgProgram>> result = {};
        if (data is Map) {
          data.forEach((key, value) {
            if (value is List) {
              result[key] = value.map((e) => EpgProgram.fromJson(e)).toList();
            }
          });
        }
        return result;
      }
    } catch (_) {}
    return {};
  }
}