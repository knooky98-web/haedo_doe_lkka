import '../core.dart';

/// =======================
/// Judge models (shared)
/// =======================

enum UserType { nightOwl, worker }

class Choice {
  final String text;
  final int delta;
  const Choice(this.text, this.delta);
}

class JudgeQuestion {
  final String id;
  final String title;
  final List<Choice> choices;
  final String group; // used for diversity picking

  // ✅ 질문 선택/다양성용 태그 (행동명, kind_good 등)
  final List<String> tags;
  const JudgeQuestion({
    required this.id,
    required this.title,
    required this.choices,
    this.group = 'base',
    this.tags = const <String>[],
  });
}

class JudgeOut {
  final String result; // STRONG_OK/OK/MAYBE/NO/STRONG_NO
  final int score;
  const JudgeOut({required this.result, required this.score});
}

class PatternStat {
  final int cnt3;
  final int cnt5;
  final int hoursSinceLast;
  final int streak;
  final DateTime? lastAt;
  const PatternStat({
    required this.cnt3,
    required this.cnt5,
    required this.hoursSinceLast,
    required this.streak,
    required this.lastAt,
  });
}