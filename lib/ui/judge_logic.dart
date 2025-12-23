import 'dart:math';
import 'judge_models.dart';

/// =======================
/// Judge selection logic
/// =======================
///
/// ✅ UX 유지
/// - 판단하기를 누를 때마다 nonce가 증가 → 질문 조합이 조금씩 달라짐
/// - 같은 행동에서 최근에 본 질문은 가능한 한 피함(recentQIdsByAction)
///
/// ✅ 구성 고정(3개)
/// 1) 행동 전용 질문(가능하면 1개)
/// 2) kind 연관 질문(가능하면 1개)
/// 3) 범용 질문(가능하면 1개)
List<JudgeQuestion> pickQuestions(
    List<JudgeQuestion> pool, {
      required String action,
      required int nonce,
      required Map<String, List<String>> recentQIdsByAction,
      int recentKeep = 12,
    }) {
  // 최근 질문(행동별)
  final recent = recentQIdsByAction[action] ?? const <String>[];
  final avoid = recent.toSet();
  bool usable(JudgeQuestion q) => !avoid.contains(q.id);

  // 1) 행동 전용(태그에 action 들어간 질문)
  final actionSpecific =
  pool.where((q) => q.tags.contains(action) && usable(q)).toList();

  // 2) kind 연관(태그에 kind_good/neutral/bad 중 하나라도 있는 질문)
  final kindRelated = pool.where((q) {
    final t = q.tags;
    final isKind = t.contains('kind_good') ||
        t.contains('kind_neutral') ||
        t.contains('kind_bad');
    return isKind && usable(q);
  }).toList();

  // 3) 범용(행동 태그가 없는 질문)
  final general =
  pool.where((q) => !q.tags.contains(action) && usable(q)).toList();

  // ✅ 시드 고정 랜덤 (action + nonce + 날짜)
  final now = DateTime.now();
  var seed = (now.year * 10000 + now.month * 100 + now.day) ^
  (action.hashCode * 73856093) ^
  (nonce * 19349663);

  int nextInt(int max) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return max <= 0 ? 0 : (seed % max);
  }

  T? pickOne<T>(List<T> list) {
    if (list.isEmpty) return null;
    final idx = nextInt(list.length);
    return list.removeAt(idx);
  }

  final picked = <JudgeQuestion>[];
  final usedGroups = <String>{};

  bool addIfOk(JudgeQuestion? q) {
    if (q == null) return false;
    if (picked.any((e) => e.id == q.id)) return false;
    if (usedGroups.contains(q.group)) return false;
    picked.add(q);
    usedGroups.add(q.group);
    return true;
  }

  // 1) 행동전용 1개
  addIfOk(pickOne(actionSpecific));

  // 없으면 general에서 하나라도 채움
  if (picked.isEmpty) {
    addIfOk(pickOne(general));
  }

  // 2) kindRelated 우선
  addIfOk(pickOne(kindRelated) ?? pickOne(general));

  // 3) general 우선
  addIfOk(pickOne(general) ?? pickOne(actionSpecific) ?? pickOne(kindRelated));

  // 그래도 부족하면 남은 풀에서 채움
  final remaining = pool.where(usable).toList();
  while (picked.length < 3 && remaining.isNotEmpty) {
    final q = remaining.removeAt(nextInt(remaining.length));
    if (picked.any((e) => e.id == q.id)) continue;
    picked.add(q);
  }

  // 최근 히스토리 갱신
  final nextRecent = <String>[...recent, ...picked.map((e) => e.id)];
  final keep = recentKeep.clamp(8, 60);
  recentQIdsByAction[action] = nextRecent.length <= keep
      ? nextRecent
      : nextRecent.sublist(nextRecent.length - keep);

  return picked.take(3).toList();
}
