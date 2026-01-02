import 'dart:math';
import 'package:flutter/material.dart';
import '../core/reason_texts.dart';

import '../core.dart';

import 'judge_models.dart';
import 'judge_questions.dart';
import 'judge_logic.dart';

/// =======================
/// 2) 해도될까 탭 (질문 기반 판단 시스템 v2 - 5단계)
/// - ✅ UI/배치/동작은 기존 그대로 유지
/// - ✅ 판단하기 → "질문 3개"만 랜덤 노출
/// - ✅ 결과는 5단계:
///    🔥 STRONG_OK / ⭕ OK / ⚠️ MAYBE(주의) / 🟡 NO / ❌ STRONG_NO
/// - ✅ ⚠️(주의)일 때만:
///    - 추가 질문 1개(선택, 스킵 가능)
///    - “선(시간/예산)” 자동 제안 문구 생성
///    - reason2 / 이유더보기 반영
///
/// ✅ 변경점(중요)
/// - AI 기능 완전 제거
///   - 광고 닫히면 질문 시작
///   - 광고 실패/미로드면 그냥 바로 질문 시작
///   "이유 더 보기"는 보상형(Rewarded)을 시도하되,
///   ✅ 실패/미로드여도 그냥 이유를 바로 보여줘서 불편 최소화
/// =======================

class DecideTab extends StatefulWidget {
  final List<ActionDef> actions;
  final List<LogItem> logs; // ✅ 최근 패턴 계산용(최근 3일/5일/마지막 간격)

  final void Function({
  required String action,
  String? subtype,
  int? minutes,
  bool isCustomMinutes,
  String? purchaseType,
  }) onSaveFromJudge;

  const DecideTab({
    super.key,
    required this.actions,
    required this.logs,
    required this.onSaveFromJudge,
  });

  @override
  State<DecideTab> createState() => _DecideTabState();
}

class _DecideTabState extends State<DecideTab> {
  int _questionNonce = 0; // ✅ 질문 조합 다양화용
  final Map<String, List<String>> _recentQIdsByAction = {};
  static const int _recentQKeep = 12;

  bool _judgeBusy = false; // ✅ 연타/중복 실행 방지

  String selected = '자기관리';

  /// 5단계 결과 문자열 (기존 result(String?) 구조 유지)
  /// - STRONG_OK / OK / MAYBE / NO / STRONG_NO
  String? result;
  String reason1 = '최근 패턴을 보면 무난해요.';
  String reason2 = '다만 연속성이 있으면 강도를 낮춰도 좋아요.';

  // 질문/답변 상태
  List<JudgeQuestion> _asked = [];
  final Map<String, int> _answers = {}; // qid -> choiceIndex(0..)

  // ✅ ⚠️(주의)일 때만 추가로 받는 “선 질문” (선택)
  String? _limitSuggestion; // "선(시간/예산)" 자동 제안 문구

  // 이유 더 보기(무료)
  List<String> _moreReasons = [];

  double _sheetBottomPad(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    return 16 + mq.padding.bottom + kBottomNavigationBarHeight + 12;
  }

  // ==========================
  // ✅ 커스텀 행동 "준-기본" 승격 + 태그 기반 전용 질문
  // ==========================
  static const Set<String> _builtInActions = {
    '자기관리',
    '휴식',
    '자기전 폰',
    '술',
    '폭식',
    '구매',
    '게임',
    '카페인',
    '청소',
  };

  bool _isCustomAction(String action) => !_builtInActions.contains(action);

  ({int total, int cnt14, int days7}) _customStats(String action) {
    final now = DateTime.now();
    final since14 = now.subtract(const Duration(days: 14));
    final since7 = now.subtract(const Duration(days: 7));

    int total = 0;
    int cnt14 = 0;
    final days = <String>{};

    for (final l in widget.logs) {
      if (l.action != action) continue;
      total++;
      if (l.at.isAfter(since14)) cnt14++;
      if (l.at.isAfter(since7)) {
        final d = DateTime(l.at.year, l.at.month, l.at.day);
        days.add('${d.year}-${d.month}-${d.day}');
      }
    }
    return (total: total, cnt14: cnt14, days7: days.length);
  }

  // ✅ 패턴 통계(최근 n일 빈도/연속 등)
  PatternStat _patternOf(String action) {
    return patternOf(widget.logs, action);
  }

  // --------------------------
  // 3) 결과 계산 (5단계)
  // --------------------------
  JudgeOut _computeJudge({
    required String action,
    required ActionKind kind,
    required List<JudgeQuestion> asked,
    required Map<String, int> answers,
  }) {
    int score = 0;

    // ✅ 최근 패턴(실제 로그 기반)
    final stat = _patternOf(action);

    // 행동 성격 점수
    switch (kind) {
      case ActionKind.good:
        score += 8;
        break;
      case ActionKind.neutral:
        score += 0;
        break;
      case ActionKind.bad:
        score -= 8;
        break;
    }

    // ✅ 패턴 점수(최근 5일/3일 + 마지막 간격)
    int pat = 0;

    // 빈도(최근 5일)
    if (stat.cnt5 == 0) {
      pat += 10;
    } else if (stat.cnt5 == 1) {
      pat += 6;
    } else if (stat.cnt5 == 2) {
      pat += 2;
    } else if (stat.cnt5 == 3) {
      pat += -2;
    } else if (stat.cnt5 >= 4) {
      pat += -8;
    }

    // 최근 3일 쏠림
    if (stat.cnt3 >= 3) pat += -8;
    if (stat.cnt3 == 2) pat += -4;

    // 마지막 간격(시간)
    final h = stat.hoursSinceLast;
    if (h >= 96) {
      pat += 8;
    } else if (h >= 72) {
      pat += 6;
    } else if (h >= 48) {
      pat += 4;
    } else if (h >= 24) {
      pat += 2;
    } else if (h <= 6) {
      pat += -10;
    } else if (h <= 12) {
      pat += -6;
    }

    // 연속일(스트릭)
    if (stat.streak >= 4) pat += -10;
    if (stat.streak == 3) pat += -6;
    if (stat.streak == 2) pat += -3;

    // kind별 보정
    switch (kind) {
      case ActionKind.good:
        pat = (pat * 0.7).round();
        break;
      case ActionKind.neutral:
        pat = (pat * 0.9).round();
        break;
      case ActionKind.bad:
        break;
    }

    score += pat;

    // 질문 점수 합산
    for (final q in asked) {
      final idx = answers[q.id] ?? 0;
      score += q.choices[idx].delta;
    }

    // ✅ 확정 구간
    if (score >= 20) return JudgeOut(result: 'STRONG_OK', score: score);
    if (score <= -20) return JudgeOut(result: 'STRONG_NO', score: score);

    // ✅ 중간 구간 가중 랜덤 + 점수 보정
    final w = <String, int>{
      'STRONG_OK': 15,
      'OK': 25,
      'MAYBE': 25,
      'NO': 20,
      'STRONG_NO': 15,
    };

    if (score >= 10) {
      w['STRONG_OK'] = w['STRONG_OK']! + 10;
      w['OK'] = w['OK']! + 8;
      w['STRONG_NO'] = max(3, w['STRONG_NO']! - 8);
      w['NO'] = max(5, w['NO']! - 6);
    } else if (score >= 6) {
      w['OK'] = w['OK']! + 8;
      w['STRONG_OK'] = w['STRONG_OK']! + 4;
      w['STRONG_NO'] = max(3, w['STRONG_NO']! - 6);
      w['NO'] = max(5, w['NO']! - 4);
    } else if (score <= -10) {
      w['STRONG_NO'] = w['STRONG_NO']! + 10;
      w['NO'] = w['NO']! + 8;
      w['STRONG_OK'] = max(3, w['STRONG_OK']! - 8);
      w['OK'] = max(5, w['OK']! - 6);
    } else if (score <= -6) {
      w['NO'] = w['NO']! + 8;
      w['STRONG_NO'] = w['STRONG_NO']! + 4;
      w['STRONG_OK'] = max(3, w['STRONG_OK']! - 6);
      w['OK'] = max(5, w['OK']! - 4);
    } else {
      w['MAYBE'] = w['MAYBE']! + 6;
    }

    // 시드 고정 랜덤
    final now = DateTime.now();
    final seed = (now.year * 10000 + now.month * 100 + now.day) ^
    action.hashCode ^
    answers.entries
        .map((e) => e.key.hashCode ^ e.value)
        .fold(0, (a, b) => a ^ b);
    final r = Random(seed);

    final pick = _weightedPick(r, w);
    return JudgeOut(result: pick, score: score);
  }

  String _weightedPick(Random r, Map<String, int> w) {
    final total = w.values.fold<int>(0, (a, b) => a + b);
    int roll = r.nextInt(max(1, total));
    for (final e in w.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return 'MAYBE';
  }

  // --------------------------
  // ✅ ⚠️(주의)일 때만: “선 질문 1개(선택)” + 자동 제안 생성
  // --------------------------
  JudgeQuestion _buildLimitQuestion({required String action}) {
    if (action == '구매') {
      return const JudgeQuestion(
        id: 'limit_buy',
        title: '⚠️ 주의 모드야. “선(예산)”을 정하면 더 안전해. 어느 쪽이 좋아?',
        choices: [
          Choice('상한선: 예산 안에서만', 0),
          Choice('상한선: “필요 1개만”', 0),
          Choice('상한선: 24시간 보류(장바구니만)', 0),
        ],
      );
    }
    if (action == '술') {
      return const JudgeQuestion(
        id: 'limit_alcohol',
        title: '⚠️ 주의 모드야. “선(강도)”을 정하면 더 안전해. 어느 쪽이 좋아?',
        choices: [
          Choice('선: 1~2잔까지만', 0),
          Choice('선: 2차 없이 귀가', 0),
          Choice('선: 물/안주/수면까지 챙기기', 0),
        ],
      );
    }
    if (action == '자기전 폰') {
      return const JudgeQuestion(
        id: 'limit_phone',
        title: '⚠️ 주의 모드야. “선(시간)”을 정하면 더 안전해. 어느 쪽이 좋아?',
        choices: [
          Choice('선: 10분 타이머', 0),
          Choice('선: 침대 밖에서만', 0),
          Choice('선: 자극적인 콘텐츠 금지', 0),
        ],
      );
    }
    if (action == '폭식') {
      return const JudgeQuestion(
        id: 'limit_binge',
        title: '⚠️ 주의 모드야. “선(대체)”을 정하면 더 안전해. 어느 쪽이 좋아?',
        choices: [
          Choice('선: “단백질/물” 먼저', 0),
          Choice('선: 정해진 양만 + 추가 금지', 0),
          Choice('선: 10분만 산책 후 결정', 0),
        ],
      );
    }

    return const JudgeQuestion(
      id: 'limit_general',
      title: '⚠️ 주의 모드야. “선(시간/강도)”을 정하면 더 안전해. 어느 쪽이 좋아?',
      choices: [
        Choice('선: 20분만 하고 종료', 0),
        Choice('선: 30~60분까지만', 0),
        Choice('선: “끝나고 할 일 1개”까지 세트', 0),
      ],
    );
  }

  String _limitSuggestionFromAnswer({
    required String action,
    required JudgeQuestion q,
    required int choiceIdx,
  }) {
    final c = q.choices[choiceIdx].text;

    if (action == '구매') {
      if (c.contains('예산')) return '선 추천: 오늘은 “예산 안”에서만 구매하기.';
      if (c.contains('필요 1개')) return '선 추천: 오늘은 “필요한 것 1개만” 사고 종료하기.';
      if (c.contains('24시간')) return '선 추천: 오늘은 결제 보류하고 “장바구니/위시리스트”만.';
      return '선 추천: 예산 상한선을 정하고 들어가기.';
    }

    if (action == '술') {
      if (c.contains('1~2잔')) return '선 추천: “1~2잔”까지만.';
      if (c.contains('2차')) return '선 추천: “2차 없이 귀가”를 선으로 걸기.';
      if (c.contains('물/안주')) return '선 추천: 물/안주/수면까지 “풀세트로 챙기기”.';
      return '선 추천: 강도(잔 수/시간)를 선으로 정하기.';
    }

    if (action == '자기전 폰') {
      if (c.contains('10분')) return '선 추천: “10분 타이머” 걸고 종료.';
      if (c.contains('침대 밖')) return '선 추천: “침대 밖에서만” 보기.';
      if (c.contains('자극')) return '선 추천: “자극 콘텐츠는 금지”하고 가벼운 것만.';
      return '선 추천: 시간/콘텐츠 선을 정하고 들어가기.';
    }

    if (action == '폭식') {
      if (c.contains('단백질')) return '선 추천: 먼저 물/단백질로 “급한 허기”부터 낮추기.';
      if (c.contains('정해진 양')) return '선 추천: “정해둔 양만” 먹고 추가 금지.';
      if (c.contains('산책')) return '선 추천: 10분만 움직이고 다시 결정.';
      return '선 추천: 대체 플랜을 1개 정하고 시작하기.';
    }

    if (c.contains('20분')) return '선 추천: “20분만” 하고 종료.';
    if (c.contains('30~60')) return '선 추천: “30~60분” 상한선 걸기.';
    if (c.contains('할 일 1개')) return '선 추천: 끝나고 “할 일 1개”까지 세트로.';
    return '선 추천: 시간/강도 선을 정하고 들어가기.';
  }

  Future<String?> _askLimitIfNeeded({
    required BuildContext context,
    required String action,
  }) async {
    final q = _buildLimitQuestion(action: action);
    final idx = await _showLimitQuestion(context, q: q); // null이면 스킵
    if (idx == null) return null;
    return _limitSuggestionFromAnswer(action: action, q: q, choiceIdx: idx);
  }

  // --------------------------
  // 4) 이유 템플릿 생성(무료 2단계) - 5단계 반영
  // --------------------------
  List<String> _buildReasons({
    required String result,
    required String action,
    required ActionKind kind,
    required int score,
    required List<JudgeQuestion> asked,
    required Map<String, int> answers,
    String? limitSuggestion,
  }) {
    final now = DateTime.now();
    final hour = now.hour;

    final seed = now.millisecondsSinceEpoch ^ action.hashCode ^ (score * 9973);
    final r = Random(seed);
    String pick(List<String> xs) => xs.isEmpty ? '' : xs[r.nextInt(xs.length)];

    final headStrongOk = <String>[
      '가자. “$action”은 지금 딱 좋아.',
      '좋아. 지금은 “$action”이 플러스야.',
      '지금 이 타이밍엔 “$action” 해도 돼.',
      '오늘은 “$action”이 너를 살릴 쪽이야.',
      '오케이. “$action”으로 텐션 올려도 괜찮아.',
      '지금 하면 오히려 루틴이 더 탄탄해질 수 있어.',
      '해도 돼. 지금은 리스크보다 이득이 커.',
      '이건 “해도 됨” 쪽에 확실히 한 표.',
    ];

    final headOk = <String>[
      '해도 돼. “$action”은 무난해.',
      '오케이. “$action” 가능.',
      '지금은 “$action” 해도 큰 문제 없겠어.',
      '괜찮아. 다만 강도만 조절하자.',
      '해도 되는데, “적당히”가 포인트야.',
      '지금은 무리만 안 하면 OK.',
      '해도 돼. 대신 선을 하나 정하자.',
      '가능. 오늘 컨디션만 체크하고 가자.',
    ];

    final headMaybe = <String>[
      '“$action”… 애매해. 네가 결정하면 돼.',
      '지금은 반반이야. “$action”은 조건부로 가능.',
      '해도 되긴 하는데, 지금은 “선”이 중요해.',
      '애매한데… 목적이 뭐냐가 갈라.',
      '가능/비추 사이. “왜 하려는지”만 확인하자.',
      '지금 느낌상은 “조절하면 가능” 쪽이야.',
      '해도 되지만, 오늘은 과하면 바로 손해로 간다.',
      '지금은 “진짜 필요한가”만 체크하면 답이 나와.',
    ];

    final headNo = <String>[
      '지금은 “$action”은 비추야.',
      '오늘은 “$action” 말고 다른 선택이 더 좋아.',
      '지금 하면 손해가 날 확률이 높아.',
      '오늘은 “$action”이 너를 깎을 수 있어.',
      '지금은 미루는 게 더 현명해 보여.',
      '오늘은 다른 걸로 만족하는 게 낫겠다.',
      '지금은 “$action” 대신 대안을 고르자.',
      '비추. 지금 타이밍이 별로야.',
    ];

    final headStrongNo = <String>[
      '오늘은 “$action”은 쉬자.',
      '스탑. 오늘은 “$action” 하면 안 돼.',
      '지금은 회복/루틴이 먼저야. “$action”은 멈추자.',
      '오늘은 끊는 게 이득이야. “$action”은 NO.',
      '이건 위험 쪽이야. “$action”은 접자.',
      '지금 하면 내일이 무너질 수 있어. 오늘은 쉬자.',
      '오늘은 “$action” 안 하는 게 승리야.',
      '강하게 말할게. 오늘은 하지 마.',
    ];

    final lateNight = (hour >= 22 || hour <= 3);

    List<String> bodyStrongOk() {
      final base = <String>[
        '지금은 에너지/집중을 “올리는 행동”으로 쓰기 좋아. 다만 끝나는 시간을 미리 정하면 더 깔끔해.',
        '최근 패턴을 보면 과하게 꼬인 느낌은 아니야. 오늘은 “한 번 잘 하고 끝내는” 쪽이 좋아.',
        '리스크보다 이득이 더 크게 보이네. 시작하기 전에 딱 한 가지 목표만 정하고 들어가자.',
        '오늘은 “$action”이 루틴/기분을 살리는 쪽에 가까워. 마무리만 깔끔하게 하면 완벽해.',
        '지금은 흐름이 좋아. 과몰입만 피하면 “잘했다”로 끝날 확률이 높아.',
      ];
      if (kind == ActionKind.bad) {
        base.addAll([
          '평소엔 조심해야 하는 쪽이지만, 지금은 조건이 괜찮아 보여. “선”을 정하고 하면 충분히 컨트롤 가능해.',
          '오늘은 예외적으로 괜찮아. 대신 시간/예산 같은 한계를 먼저 걸고 시작하자.',
        ]);
      }
      if (lateNight) {
        base.addAll([
          '다만 지금 시간대엔 수면을 깎기 쉬워. 종료 시각만 박아두고 하자.',
          '늦은 시간이면 끝나는 선을 꼭 정해. 내일의 나를 지키는 게 핵심이야.',
        ]);
      }
      return base;
    }

    List<String> bodyOk() {
      final base = <String>[
        '가능해. 다만 “강도/시간”만 조절하면 더 안전해.',
        '큰 문제는 없어 보여. 그래도 컨디션을 해치지 않게 선을 정하자.',
        '지금은 무난한 선택이야. 시작 전에 “얼마나 할지”만 정하면 된다.',
        '해도 되는데, 과하면 갑자기 손해로 뒤집힐 수 있어. 딱 적당히만.',
        '괜찮아. 끝난 뒤 후회 없게 “마무리 규칙” 하나만 만들자.',
      ];
      if (lateNight) {
        base.addAll([
          '시간이 늦으면 회복이 우선이니까, 짧게 하고 자는 쪽이 좋아.',
          '늦은 시간엔 “짧게 하고 마감”이 정답이야.',
        ]);
      }
      return base;
    }

    List<String> bodyMaybe() {
      final base = <String>[
        '지금은 “목적”이 관건이야. 회복/필요 때문에 하는 거면 괜찮고, 그냥 습관이면 손해가 될 수 있어.',
        '해도 되긴 하는데, 선을 안 정하면 바로 과해질 확률이 커. 시작 전에 기준을 잡자.',
        '가능/비추 사이야. “오늘 이걸 하고 나서 내가 더 나아질까?”만 체크해봐.',
        '지금은 조건부로 가능. 시간/예산/강도 중 하나는 반드시 제한 걸고 가자.',
        '애매할 땐 작은 버전으로 테스트하는 게 좋아. 10분만 해보고 계속할지 결정하자.',
        '지금은 “진짜 필요한가”만 확인하면 답이 나와. 필요하면 하고, 아니면 미루자.',
      ];
      if (lateNight) {
        base.addAll([
          '특히 이 시간대엔 수면/회복 리스크가 커. “짧게” 아니면 아예 미루는 게 낫다.',
          '늦은 시간이면 감정/충동이 커질 수 있어. 더더욱 선이 필요해.',
        ]);
      }
      return base;
    }

    List<String> bodyNo() {
      final base = <String>[
        '지금 하면 얻는 것보다 잃는 게 커질 수 있어. 대안을 고르면 컨디션을 지키는 데 도움 돼.',
        '지금 타이밍엔 “$action”이 후회로 이어질 확률이 높아 보여. 오늘은 다른 선택이 낫다.',
        '이건 지금의 나를 깎을 가능성이 있어. 내일로 미루면 훨씬 깔끔해질 수 있어.',
        '오늘은 회복/루틴 쪽에 투자하는 게 더 이득이야. “$action”은 잠깐 내려놓자.',
        '지금은 감정/충동이 섞이면 손해가 커져. 잠깐 거리 두는 게 좋아.',
      ];
      if (lateNight) {
        base.addAll([
          '특히 늦은 시간엔 후회 확률이 올라가. 오늘은 쉬고 내일 맑은 머리로 결정하자.',
          '이 시간엔 판단이 흐려지기 쉬워. 오늘은 멈추는 게 안전해.',
        ]);
      }
      return base;
    }

    List<String> bodyStrongNo() {
      final base = <String>[
        '내일 컨디션/루틴을 생각하면 지금은 회복이 더 이득이야. 오늘은 쉬는 쪽으로 가자.',
        '지금 하면 다음 날까지 여파가 남을 가능성이 커. 오늘은 끊는 게 맞아.',
        '오늘은 “안 하는 선택”이 장기적으로 이득이야. 회복/정리부터 하자.',
        '이건 한 번 시작하면 선 넘기 쉬워. 오늘은 강하게 스탑하자.',
        '지금은 손실 쪽으로 기울어. 오늘은 보호 모드로 가자.',
      ];
      if (lateNight) {
        base.addAll([
          '늦은 시간엔 더 위험해져. 수면/회복 먼저 챙기자.',
          '이 시간대엔 충동이 세져서 더 위험해. 오늘은 무조건 쉬자.',
        ]);
      }
      return base;
    }

    String head;
    String body;

    switch (result) {
      case 'STRONG_OK':
        head = pick(headStrongOk);
        body = pick(bodyStrongOk());
        break;
      case 'OK':
        head = pick(headOk);
        body = pick(bodyOk());
        break;
      case 'NO':
        head = pick(headNo);
        body = pick(bodyNo());
        break;
      case 'STRONG_NO':
        head = pick(headStrongNo);
        body = pick(bodyStrongNo());
        break;
      default: // MAYBE
        head = pick(headMaybe);
        body = pick(bodyMaybe());
        break;
    }

    if (result == 'MAYBE' && limitSuggestion != null && limitSuggestion.isNotEmpty) {
      body = '$body\n\n• 추천 선: $limitSuggestion';
    }

    final picks = asked.map((q) {
      final idx = answers[q.id] ?? 0;
      final c = q.choices[idx].text;
      return '- Q: ${q.title}\n  A: $c';
    }).toList();

    final expand = <String>[
      if (result == 'STRONG_OK') '핵심은 “지금 하면 성장/루틴에 도움이 된다”는 거야. 다만 과하지만 않게 마무리하자.',
      if (result == 'OK') '핵심은 “가능하지만 적당히”야. 선을 정하면 후회 확률이 확 줄어.',
      if (result == 'NO') '핵심은 “지금은 손해가 커질 수 있다”는 거야. 대안을 고르는 게 현명해.',
      if (result == 'STRONG_NO') '핵심은 “오늘은 회복/루틴 보호”야. 내일을 살리는 선택이 더 이득이야.',
      if (result == 'MAYBE') '핵심은 “선(시간/예산/강도)”이야. 선을 정하면 해도 되고, 못 정하겠으면 미루는 게 맞아.',
      if (lateNight) '추가 메모: 늦은 시간엔 수면/회복 비용이 커져. “짧게” 아니면 “내일”이 더 좋을 때가 많아.',
      if (kind == ActionKind.bad) '추가 메모: 이 행동은 “선”을 안 정하면 과해지기 쉬워. 선을 먼저 고정하자.',
      if (limitSuggestion != null && limitSuggestion.isNotEmpty) '추가로 추천한 선은: $limitSuggestion',
      '지금 체크한 포인트는 아래야:\n${picks.join('\n')}',
    ];

    _moreReasons = expand;

    final stat = _patternOf(action);

// ✅ Reason 엔진에 넣을 패턴 변환
    final p = PatternLite(
      cnt3: stat.cnt3,
      cnt5: stat.cnt5,
      hoursSinceLast: stat.hoursSinceLast,
      streak: stat.streak,
    );

// ✅ 행동 타입 추론(돈/술/폰/운동/카페인/수면 등)
    final aType = actionTypeFromActionName(action);

// ✅ 3단 문구(팩트+해석+대안) 생성
    final pack = buildReasonPack(
      result: result ?? 'MAYBE',
      pattern: p,
      seed: DateTime.now().millisecondsSinceEpoch ^ action.hashCode ^ score,
      actionType: aType,
    );

// ✅ 결과 카드에는 "한 줄(해석)"만 보여주기
    head = pack.interpret;   // 예: "지금은 미루는 게 더 현명해보여."
    body = '';               // 결과 카드에서 상세 문구 제거(상세는 '이유 더 보기'에서만)


// ✅ 기존 freq/gap 요약은 하단에 그대로 붙임(원하면 삭제 가능)
    final freqText = (stat.cnt5 == 0) ? '최근 5일간 0회' : '최근 5일간 ${stat.cnt5}회';
    final gapText = stat.lastAt == null ? '최근 기록 없음' : '마지막이 ${stat.hoursSinceLast}시간 전';
    body = '$body\n\n• $freqText · $gapText';

// ✅ “이유 더 보기” 리스트도 풍부하게
    _moreReasons = [
      ..._moreReasons,
      pack.fact,
      pack.interpret,
      pack.alternative,
    ];

    return [head, body];}




    // --------------------------
// ✅ 이유 더 보기: 하루 2회까지만 "보상형(Rewarded)" 시도
// 실패/미로드여도 이유는 항상 보여줌
// --------------------------
  Future<void> _onReasonMorePressed() async {
    if (result == null) return;

    // 🔥 하루 2회 제한 초과면 광고 없이 바로 이유
    if (!await AdDailyLimit.canShowRewarded()) {
      await _showMoreReasons();
      return;
    }

    // 1) 로드 안 됐으면 → 그냥 이유 보여주고, 다음을 위해 로드만
    if (!rewardedAds.isLoaded) {
      rewardedAds.load();
      await _showMoreReasons();
      return;
    }

    // 2) 보상형(Rewarded) "시도"
    await rewardedAds.show(
      onRewarded: () async {
        // ✅ 끝까지 봤을 때만 카운트
        await AdDailyLimit.markRewardedShown();
      },
      onClosed: () async {
        // ✅ UX 보장: 닫히면 이유 보여줌
        await _showMoreReasons();
      },
      onFailed: () async {
        // ✅ 실패해도 이유는 보여줌
        await _showMoreReasons();
      },
    );
  }



  // --------------------------
  // UI 이벤트: 판단하기(기존 로직을 core로 분리)
  // --------------------------
  Future<void> _judgeCore() async {
    // ✅ 연타 방지 (맨 위)
    if (_judgeBusy) return;
    _judgeBusy = true;

    try {
      _questionNonce++;
      final def = findDefByName(widget.actions, selected);
      final kind = def?.kind ?? ActionKind.neutral;

      final pool = buildQuestionPool(action: selected, kind: kind, logs: widget.logs);
      final asked = pickQuestions(
        pool,
        action: selected,
        nonce: _questionNonce,
        recentQIdsByAction: _recentQIdsByAction,
        recentKeep: _recentQKeep,
      );

      final res = await _showQuestionFlow(context, asked: asked);

      if (res == null) {
        if (!mounted) return;
        setState(() {
          result = null;
          reason1 = '최근 패턴을 보면 무난해요.';
          reason2 = '다만 연속성이 있으면 강도를 낮춰도 좋아요.';
        });
        return;
      }


      final answers = res;

      final out = _computeJudge(
        action: selected,
        kind: kind,
        asked: asked,
        answers: answers,
      );

      String? limitSuggestion;
      if (out.result == 'MAYBE') {
        limitSuggestion = await _askLimitIfNeeded(context: context, action: selected);
      }

      final reasons = _buildReasons(
        result: out.result,
        action: selected,
        kind: kind,
        score: out.score,
        asked: asked,
        answers: answers,
        limitSuggestion: limitSuggestion,
      );

      if (!mounted) return;
      setState(() {
        _asked = asked;
        _answers
          ..clear()
          ..addAll(answers);

        _limitSuggestion = limitSuggestion;

        result = out.result;
        reason1 = reasons[0];
        reason2 = reasons[1];
      });
    } finally {
      _judgeBusy = false;
    }
  }

  // --------------------------
  // 기록 저장(기존 유지)
  // --------------------------
  Future<void> _saveToLog() async {
    if (result == null) return;

    if (selected == '자기관리') {
      final res = await showSelfCareDialog(context);
      if (res == null) return;
      widget.onSaveFromJudge(
        action: '자기관리',
        subtype: res.subtype,
        minutes: res.minutes,
        isCustomMinutes: res.isCustom,
      );
      return;
    }

    if (selected == '구매') {
      final purchaseType = await showPurchaseDialog(context);
      if (purchaseType == null) return;
      widget.onSaveFromJudge(
        action: '구매',
        purchaseType: purchaseType,
        isCustomMinutes: false,
      );
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, _sheetBottomPad(ctx)),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('정말 “했다”고 기록할까요?'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('했다'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (ok == true) {
      widget.onSaveFromJudge(action: selected, isCustomMinutes: false);
    }
  }

  // --------------------------
  // 이유 더 보기(무료)
  // --------------------------
  Future<void> _showMoreReasons() async {
    if (result == null) return;

    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final maxH = (mq.size.height * 0.62).clamp(240.0, mq.size.height - 160);

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, _sheetBottomPad(ctx)),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이유 더 보기',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                 
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _moreReasons
                            .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(s),
                        ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('닫기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------
  // build (UI는 기존 그대로, AI 버튼만 제거)
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (widget.actions.isNotEmpty && findDefByName(widget.actions, selected) == null) {
      selected = widget.actions.first.name;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('해도될까?')),
      body: SafeArea(
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mq = MediaQuery.of(context);
            final bottomSafe = mq.padding.bottom;
            const extra = 12.0;
            final padBottom = 16 + bottomSafe + kBottomNavigationBarHeight + extra;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, padBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 12),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Text('지금 하려는 행동',
                          style: t.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selected,
                        items: widget.actions
                            .map((d) => DropdownMenuItem(value: d.name, child: Text(d.name)))
                            .toList(),
                        onChanged: (v) => setState(() => selected = v ?? selected),
                        decoration: const InputDecoration(labelText: '행동 선택'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _judgeCore,   // 광고 없이 바로 질문
                                child: const Text('판단하기'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: FilledButton.tonal(
                              onPressed: result == null ? null : _saveToLog,
                              child: const Text('했다(기록)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _ResultCard(
                          result: result,
                          reason1: reason1,
                          reason2: reason2,
                          onMorePressed: result == null ? null : _onReasonMorePressed,
                        ),
                      ),
                      const SizedBox(height: 12),

                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --------------------------
  // 질문 플로우(3문항)
  // --------------------------
  Future<Map<String, int>?> _showQuestionFlow(
      BuildContext context, {
        required List<JudgeQuestion> asked,
      }) async {
    final answers = <String, int>{};

    return showModalBottomSheet<Map<String, int>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        int step = 0;

        return StatefulBuilder(
          builder: (ctx, setState) {
            final q = asked[step];
            final selectedIdx = answers[q.id];

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, _sheetBottomPad(ctx)),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '질문 ${step + 1} / ${asked.length}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(q.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      ...List.generate(q.choices.length, (i) {
                        final c = q.choices[i];
                        final isOn = selectedIdx == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => answers[q.id] = i),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: isOn ? cs.primary.withOpacity(0.10) : cs.surfaceContainerLowest,
                                border: Border.all(
                                  color: isOn
                                      ? cs.primary.withOpacity(0.45)
                                      : cs.outlineVariant.withOpacity(0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(c.text,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  if (isOn) const Icon(Icons.check, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: step == 0
                                  ? () => Navigator.pop(ctx, null)
                                  : () => setState(() => step--),
                              child: Text(step == 0 ? '취소' : '이전'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedIdx == null
                                  ? null
                                  : () {
                                if (step < asked.length - 1) {
                                  setState(() => step++);
                                } else {
                                  Navigator.pop(ctx, answers);
                                }
                              },
                              child: Text(step < asked.length - 1 ? '다음' : '완료'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------
  // ✅ ⚠️(주의)일 때만: 선 질문 1개(선택/스킵)
  // --------------------------
  Future<int?> _showLimitQuestion(BuildContext context, {required JudgeQuestion q}) async {
    return showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        int? picked;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, _sheetBottomPad(ctx)),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '추가 질문 (선택)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(q.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      ...List.generate(q.choices.length, (i) {
                        final c = q.choices[i];
                        final isOn = picked == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => picked = i),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: isOn ? cs.primary.withOpacity(0.10) : cs.surfaceContainerLowest,
                                border: Border.all(
                                  color: isOn
                                      ? cs.primary.withOpacity(0.45)
                                      : cs.outlineVariant.withOpacity(0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(c.text,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  if (isOn) const Icon(Icons.check, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: const Text('건너뛰기'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: picked == null ? null : () => Navigator.pop(ctx, picked),
                              child: const Text('적용'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String? result;
  final String reason1;
  final String reason2;

  // ✅ 카드 안 "이유 더 보기" 버튼용
  final VoidCallback? onMorePressed;

  const _ResultCard({
    required this.result,
    required this.reason1,
    required this.reason2,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    String title;
    String emoji;
    Color border;

    switch (result) {
      case 'STRONG_OK':
        title = '지금 하면 딱 좋아';
        emoji = '🔥';
        border = Colors.green.withOpacity(0.45);
        break;
      case 'OK':
        title = '해도 됨';
        emoji = '⭕';
        border = Colors.green.withOpacity(0.30);
        break;
      case 'MAYBE':
        title = '주의(⚠️) · 선을 정하면 가능';
        emoji = '⚠️';
        border = cs.primary.withOpacity(0.30);
        break;
      case 'NO':
        title = '지금은 비추';
        emoji = '🟡';
        border = Colors.orange.withOpacity(0.35);
        break;
      case 'STRONG_NO':
        title = '오늘은 쉬자';
        emoji = '❌';
        border = Colors.red.withOpacity(0.35);
        break;
      default:
        title = '판단 결과';
        emoji = '🧭';
        border = cs.outlineVariant.withOpacity(0.6);
        break;
    }

    final hasResult = result != null;
    final canPressMore = hasResult && onMorePressed != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 라벨
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ✅ 결과 한 줄(너가 원한 “문구 패키지”)
          Text(
            hasResult ? reason1 : '아직 판단 전이야. “판단하기”를 눌러봐.',
            style: t.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),

          // (너 코드에선 reason2가 freq/gap 같은 요약이 들어감)
          if (hasResult && reason2.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reason2,
              style: t.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 14),

          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: canPressMore ? onMorePressed : null,
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
                color: cs.surfaceContainerHighest.withOpacity(0.55),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withOpacity(0.14),
                      border: Border.all(color: cs.primary.withOpacity(0.25)),
                    ),
                    child: Icon(Icons.lock_open_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이유 더 보기',
                          style: t.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '상세 이유 · 대안 확인하기',
                          style: t.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
// ✅ 🔽🔽🔽 여기 추가 (이유 더 보기 버튼 바로 아래)
          const SizedBox(height: 8),
          FutureBuilder<int>(
            future: AdDailyLimit.remainRewarded(),
            builder: (context, snap) {
              final remain = snap.data ?? 0;
              final msg = '오늘 남은 광고: $remain회\n광고 소진 후 오늘은 무료로 계속 볼 수 있어요';

              return Text(
                msg,
                textAlign: TextAlign.center,
                style: t.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
