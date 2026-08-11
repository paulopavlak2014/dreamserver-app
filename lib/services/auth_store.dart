import 'package:shared_preferences/shared_preferences.dart';

class AuthStore {
  static Future<void> save(String user, String pass) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('user', user);
    await p.setString('pass', pass);
  }

  static Future<Map<String, String>?> load() async {
    final p = await SharedPreferences.getInstance();
    final u = p.getString('user');
    final pw = p.getString('pass');
    if (u != null && pw != null) return {'user': u, 'pass': pw};
    return null;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('user');
    await p.remove('pass');
  }
}
