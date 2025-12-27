import 'package:shared_preferences/shared_preferences.dart';

class AiUsageStore {
  static const _kDate = 'ai_used_date';
  static const _kCount = 'ai_used_count';

  // ✅ 예약 카운트 (광고 보기 직전에 잠깐 잡아두는 용도)
  // - AI 성공하면 유지(= commit)
  // - AI 실패하면 rollback
  static const _kReserved = 'ai_used_reserved';

  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

  static Future<_State> _loadState(SharedPreferences prefs) async {
    final today = _todayKey(DateTime.now());
    final savedDate = prefs.getString(_kDate);

    if (savedDate != today) {
      // 날짜 바뀌면 초기화
      await prefs.setString(_kDate, today);
      await prefs.setInt(_kCount, 0);
      await prefs.setInt(_kReserved, 0);
      return _State(date: today, used: 0, reserved: 0);
    }

    final used = prefs.getInt(_kCount) ?? 0;
    final reserved = prefs.getInt(_kReserved) ?? 0;
    return _State(date: today, used: used, reserved: reserved);
  }

  /// ✅ 오늘 “실사용 + 예약” 합계 기준으로 남은 횟수
  static Future<int> remainingToday({int limit = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);
    final total = s.used + s.reserved;
    final rem = limit - total;
    return rem < 0 ? 0 : rem;
  }

  /// ✅ 광고 보여주기 직전에 1회 “예약”
  /// - true면 예약 성공(한도 안 넘김) → 광고 진행 가능
  /// - false면 오늘 한도 초과 → 광고/AI 진행 금지
  static Future<bool> reserve({int limit = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);

    final total = s.used + s.reserved;
    if (total >= limit) return false;

    await prefs.setInt(_kReserved, s.reserved + 1);
    return true;
  }

  /// ✅ AI 성공 후 확정: reserved 1개를 used로 이동
  static Future<void> commit() async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);

    if (s.reserved <= 0) return; // 예약 없이 commit 호출 방어

    await prefs.setInt(_kReserved, s.reserved - 1);
    await prefs.setInt(_kCount, s.used + 1);
  }

  /// ✅ AI 실패/취소 시 롤백: reserved 1개 감소
  static Future<void> rollback() async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);

    if (s.reserved <= 0) return;
    await prefs.setInt(_kReserved, s.reserved - 1);
  }

  /// (옵션) UI에 표시할 “확정 사용 횟수”
  static Future<int> getUsedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);
    return s.used;
  }

  /// (옵션) UI에 표시할 “예약 포함 총 사용량”
  static Future<int> getUsedOrReservedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);
    return s.used + s.reserved;
  }

  // ✅ 호환용(기존 코드 컴파일 유지)
  // 기존 decide_tab.dart에서 AiUsageStore.increment()를 쓰는 경우를 위해 제공
  // ⚠️ 이 함수는 "예약/커밋" 방식과 함께 쓰면 로직이 섞일 수 있어.
  // 일단 빌드/실행부터 살리는 용도.
  static Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final s = await _loadState(prefs);
    await prefs.setInt(_kCount, s.used + 1);
  }
}

class _State {
  final String date;
  final int used;
  final int reserved;
  _State({required this.date, required this.used, required this.reserved});
}
