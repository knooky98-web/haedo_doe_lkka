import 'package:shared_preferences/shared_preferences.dart';

class AiUsageStore {
  static const _kDate = 'ai_used_date';
  static const _kCount = 'ai_used_count';

  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

  static Future<int> getUsedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());

    final savedDate = prefs.getString(_kDate);
    if (savedDate != today) {
      await prefs.setString(_kDate, today);
      await prefs.setInt(_kCount, 0);
      return 0;
    }
    return prefs.getInt(_kCount) ?? 0;
  }

  static Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());

    final savedDate = prefs.getString(_kDate);
    if (savedDate != today) {
      await prefs.setString(_kDate, today);
      await prefs.setInt(_kCount, 1);
      return;
    }
    final cur = prefs.getInt(_kCount) ?? 0;
    await prefs.setInt(_kCount, cur + 1);
  }
}
