import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class XtreamService {
  // ── CONFIGURAÇÃO HARDCODADA ──────────────────────────────
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
            data['user_info']['auth'] == 1;
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
}
