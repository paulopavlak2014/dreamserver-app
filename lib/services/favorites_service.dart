import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites_v1';

  static Future<List<Map<String, String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> toggle(Map<String, String> item) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await load();
    final exists = favs.any((f) => f['url'] == item['url']);
    if (exists) {
      favs.removeWhere((f) => f['url'] == item['url']);
    } else {
      favs.add(item);
    }
    await prefs.setString(_key, jsonEncode(favs));
  }

  static Future<bool> isFavorite(String url) async {
    final favs = await load();
    return favs.any((f) => f['url'] == url);
  }
}