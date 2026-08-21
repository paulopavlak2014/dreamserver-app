import 'package:shared_preferences/shared_preferences.dart';

/// Player preferido: internal | vlc | mx | system
class PlayerPrefs {
  static const _key = 'preferred_player';

  static Future<String> get() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) ?? 'internal';
  }

  static Future<void> set(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, value);
  }

  static const options = [
    ('internal', 'Player interno (leve)'),
    ('vlc', 'VLC'),
    ('mx', 'MX Player'),
    ('system', 'Player do sistema'),
  ];
}
