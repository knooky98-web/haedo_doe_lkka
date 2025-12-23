import 'dart:math';
import '../core.dart';
import 'judge_models.dart';

/// =======================
/// Judge question pools
/// =======================

PatternStat patternOf(List<LogItem> logs, String action) {
  final now = DateTime.now();
  DateTime dayFloor(DateTime d) => DateTime(d.year, d.month, d.day);

  final aLogs = logs.where((l) => l.action == action).toList()
    ..sort((a, b) => a.at.compareTo(b.at));

  final since3 = now.subtract(const Duration(days: 3));
  final since5 = now.subtract(const Duration(days: 5));

  final cnt3 = aLogs.where((l) => l.at.isAfter(since3)).length;
  final cnt5 = aLogs.where((l) => l.at.isAfter(since5)).length;

  final lastAt = aLogs.isEmpty ? null : aLogs.last.at;
  final hoursSinceLast = lastAt == null ? 9999 : now.difference(lastAt).inHours;

  // 연속일(streak): 오늘부터 거꾸로, 하루라도 빠지면 종료
  final daysWithLog = <DateTime>{};
  for (final l in aLogs) {
    daysWithLog.add(dayFloor(l.at));
  }
  int streak = 0;
  var cursor = dayFloor(now);
  while (daysWithLog.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return PatternStat(
    cnt3: cnt3,
    cnt5: cnt5,
    hoursSinceLast: hoursSinceLast,
    streak: streak,
    lastAt: lastAt,
  );
}

String _kindTag(ActionKind kind) {
  switch (kind) {
    case ActionKind.good:
      return 'kind_good';
    case ActionKind.neutral:
      return 'kind_neutral';
    case ActionKind.bad:
      return 'kind_bad';
  }
}

String inferSemiTag(String action, ActionKind kind) {
  final a = action.replaceAll(' ', '').toLowerCase();

  // ✅ 행동 전용(우선순위 높음)
  // 야식/늦은 간식
  if (RegExp(r'(야식|밤간식|심야|새벽)(먹|식|간식)?').hasMatch(a)) return 'latenight';

  // 술/음주
  if (RegExp(r'(술|음주|회식|맥주|소주|와인|칵테일|하이볼)').hasMatch(a)) return 'alcohol';
  // 자기관리(루틴)
  if (RegExp(r'(자기관리|샤워|세안|스킨케어|양치|면도|목욕|마사지|스트레칭|영양제|약)').hasMatch(a)) {
    return 'selfcare';
  }

  // 폭식/과식
  if (RegExp(r'(폭식|과식|먹폭|미친듯이먹|멈출수없|빙의먹방)').hasMatch(a)) {
    return 'binge';
  }


  // 흡연/니코틴
  if (RegExp(r'(흡연|담배|연초|전자담배|베이프|니코틴)').hasMatch(a)) return 'smoke';

  // 카페인
  if (RegExp(r'(카페인|커피|라떼|아메리카노|에너지드링크|몬스터|레드불|콜드브루)').hasMatch(a)) return 'caffeine';

  // 게임(플레이)
  if (RegExp(r'(게임|롤|리그오브레전드|배그|배틀그라운드|오버워치|발로란트|메이플|로아|로스트아크|피파|서든|스팀)').hasMatch(a)) return 'game';

  // 운동(신체)
  if (RegExp(r'(운동|헬스|러닝|조깅|걷기|런닝|요가|필라테스|스트레칭|웨이트|스쿼트|푸쉬업|자전거)').hasMatch(a)) return 'workout';

  // 청소/정리
  if (RegExp(r'(청소|정리|정돈|설거지|빨래|정리정돈|방치우기)').hasMatch(a)) return 'clean';

  // 공부/학습
  if (RegExp(r'(공부|학습|독서|필사|영어|자격증|코딩|과제|복습|시험)').hasMatch(a)) return 'study';

  // 구매(구체 구매/쇼핑)  ※ 예산/지출 같은 일반 돈은 spend로 유지
  if (RegExp(r'(쇼핑|구매|지름|장바구니|쿠팡|새벽배송|결제하기|구독|프리미엄|유료|충전|후원|현질|과금)').hasMatch(a)) return 'purchase';

  // ✅ 분류(일반)
  // 음식/간식/배달
  if (RegExp(r'(간식|식사|먹방|배달|라면|치킨|피자|햄버거|떡볶|과자|디저트)').hasMatch(a)) {
    return 'food';
  }
  // 스크린/영상/SNS  (유튜브/유투브 둘 다)
  if (RegExp(r'(유튜브|유투브|쇼츠|틱톡|인스타|sns|넷플|영상|릴스|커뮤|커뮤니티|웹툰|게임방송)').hasMatch(a)) {
    return 'screen';
  }

  // ✅ 소비/지출/돈(강화)  → 기존 SPEND 세트 유지
  if (RegExp(r'(지출|돈|예산|소비|결제|카드)').hasMatch(a)) {
    return 'spend';
  }

  // 휴식/회복 계열
  if (RegExp(r'(낮잠|휴식|멍때|산책|명상|힐링|회복)').hasMatch(a)) {
    return 'rest';
  }

  // 성장/루틴(기본)
  if (RegExp(r'(루틴|습관|정리|학습|공부|독서|운동)').hasMatch(a)) {
    return 'growth';
  }

  // fallback: kind 기반
  switch (kind) {
    case ActionKind.good:
      return 'growth';
    case ActionKind.bad:
      return 'control';
    case ActionKind.neutral:
      return 'balance';
  }
}


List<JudgeQuestion> semiQuestions({
  required String action,
  required ActionKind kind,
  required bool isNight,
}) {
  final tag = inferSemiTag(action, kind);



  final semiTags = <String>[action, tag, _kindTag(kind), 'semi'];
  final aKey = action.replaceAll(' ', '_');
  final idp = 'semi_${aKey}_$tag';

  // 공통 준-기본 질문(“이 행동”에 더 맞춘 버전)
  final common = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_limit',
      group: '${idp}_core',
      title: '오늘은 “선(시간/강도)”을 정할 수 있어?',
      choices: const [
        Choice('가능(선 정하고 지킬게)', 6
        ),
        Choice('애매', 0),
        Choice('지키기 어려워', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_stop',
      group: '${idp}_core',
      title: '중간에 멈추거나 줄일 수 있을까?',
      choices: const [
        Choice('멈출 수 있어', 6
        ),
        Choice('상황 봐서(유동적)', 0),
        Choice('시작하면 길어져', -8),
      ],
      tags: semiTags,
    ),
  ];

  // 태그별 전용 질문(야식 같은 경우 다양화 핵심)
  final food = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_food_hunger',
      group: '${idp}_food_food',
      title: '지금은 “배고픔”이야, “습관/입 심심”이야?',
      choices: const [
        Choice('진짜 배고픔', 2
        ),
        Choice('반반', -2),
        Choice('습관/입 심심', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_food_alt',
      group: '${idp}_food_food',
      title: '대체 선택(물/과일/단백질/가벼운 것)이 가능해?',
      choices: const [
        Choice('가능해', 6
        ),
        Choice('애매', 0),
        Choice('대체 어려워(그게 땡겨)', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_food_time',
      group: '${idp}_food_night',
      title: '시간대가 늦을수록 내일 영향이 커져. 지금은?',
      choices: [
        Choice('이른 편', 4
        ),
        Choice('보통', 0),
        Choice('늦은 편(22시 이후)', isNight ? -8 : -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_food_amount',
      group: '${idp}_food_food',
      title: '“적당히”의 기준(양/메뉴)을 정해놨어?',
      choices: const [
        Choice('정해놨어', 6
        ),
        Choice('대충', 0),
        Choice('정해둔 건 없어', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_food_after',
      group: '${idp}_food_food',
      title: '먹고 나서 바로 할 “정리 액션”(양치/물/가벼운 정리)이 있어?',
      choices: const [
        Choice('있어', 4
        ),
        Choice('애매', 0),
        Choice('없어', -4),
      ],
      tags: semiTags,
    ),
  ];

  final screen = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_screen_purpose',
      group: '${idp}_screen_core',
      title: '지금은 목적 있는 시청이야, 자동재생 흐름이야?',
      choices: const [
        Choice('목적 있음', 4
        ),
        Choice('반반', 0),
        Choice('자동재생에 끌려', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_screen_timer',
      group: '${idp}_screen_core',
      title: '타이머/알람으로 “끝내는 시간”을 걸어둘래?',
      choices: const [
        Choice('걸 수 있어', 6
        ),
        Choice('애매', 0),
        Choice('안 걸 것 같아', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_screen_sleep',
      group: '${idp}_screen_night',
      title: '수면에 영향이 있어 보이면 강도를 낮추는 게 좋아. 지금은?',
      choices: [
        Choice('수면과 멀어', 4
        ),
        Choice('보통', 0),
        Choice('수면 직전', isNight ? -8 : -4),
      ],
      tags: semiTags,
    ),
  ];

  final spend = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_spend_need',
      group: '${idp}_spend_core',
      title: '이건 “필요”에 가까워, “욕구”에 가까워?',
      choices: const [
        Choice('필요', 6
        ),
        Choice('반반', 0),
        Choice('욕구', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_spend_rule',
      group: '${idp}_spend_core',
      title: '예산/한도를 지키는 규칙이 있어?',
      choices: const [
        Choice('있어', 6
        ),
        Choice('애매', 0),
        Choice('없어', -8),
      ],
      tags: semiTags,
    ),
  ];



  // --------------------------
  // ✅ 행동별 전용 질문 세트 (5~7개)
  // --------------------------

  final purchase = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_purchase_budget',
      group: '${idp}_purchase_core',
      title: '이거 사면 “이번 주 예산”에서 무리가 안 돼?',
      choices: const [
        Choice('무리 없어', 6),
        Choice('애매', 0),
        Choice('무리 될 듯', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_purchase_need',
      group: '${idp}_purchase_core',
      title: '지금 사는 이유가 “필요”야, “기분(욕구)”야?',
      choices: const [
        Choice('필요', 6),
        Choice('반반', 0),
        Choice('기분/욕구', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_purchase_cooldown',
      group: '${idp}_purchase_core',
      title: '10분만 보류(장바구니/위시)하고 다시 볼 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('지금 바로', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_purchase_alt',
      group: '${idp}_purchase_core',
      title: '이미 비슷한 게 있어? (대체 가능/중복 구매)',
      choices: const [
        Choice('대체 가능', -4),
        Choice('애매', 0),
        Choice('없어, 필요해', 4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_purchase_return',
      group: '${idp}_purchase_core',
      title: '환불/반품이 쉬운 선택이야?',
      choices: const [
        Choice('쉬움', 2),
        Choice('애매', 0),
        Choice('어려움', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_purchase_sub',
      group: '${idp}_purchase_core',
      title: '이게 “구독/반복 결제”면 한 달 뒤에도 만족할까?',
      choices: const [
        Choice('그럴 듯', 4),
        Choice('애매', 0),
        Choice('후회할 듯', -6),
      ],
      tags: semiTags,
    ),
  ];

  final alcohol = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_alcohol_tomorrow',
      group: '${idp}_alcohol_core',
      title: '내일 일정/컨디션 생각하면 오늘 마셔도 괜찮아?',
      choices: const [
        Choice('괜찮아', 4),
        Choice('애매', 0),
        Choice('무리야', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_alcohol_limit',
      group: '${idp}_alcohol_core',
      title: '오늘 “잔수/병수” 상한을 정할 수 있어?',
      choices: const [
        Choice('정할 수 있어', 6),
        Choice('애매', 0),
        Choice('못 지킬 듯', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_alcohol_food',
      group: '${idp}_alcohol_core',
      title: '물/안주(단백질) 챙기면서 마실 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('어려워', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_alcohol_emotion',
      group: '${idp}_alcohol_core',
      title: '지금 마시는 이유가 “즐거움”이야, “스트레스 회피”야?',
      choices: const [
        Choice('즐거움', 4),
        Choice('반반', 0),
        Choice('회피', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_alcohol_stop',
      group: '${idp}_alcohol_core',
      title: '멈출 신호(시간/장소/한 잔 더 금지)를 정해둘래?',
      choices: const [
        Choice('정할래', 6),
        Choice('애매', 0),
        Choice('안 될 듯', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_alcohol_safe',
      group: '${idp}_alcohol_core',
      title: '귀가/안전(대리/택시/동행) 플랜은 확실해?',
      choices: const [
        Choice('확실해', 6),
        Choice('애매', 0),
        Choice('불안해', -8),
      ],
      tags: semiTags,
    ),
  ];

  final workout = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_workout_goal',
      group: '${idp}_workout_core',
      title: '오늘 운동 목표가 딱 한 줄로 정리돼? (예: 30분 걷기)',
      choices: const [
        Choice('정리돼', 4),
        Choice('애매', 0),
        Choice('아직 안 됨', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_workout_time',
      group: '${idp}_workout_core',
      title: '지금 가능한 시간은? (짧게라도 10~20분)',
      choices: const [
        Choice('충분해', 4),
        Choice('짧게 가능', 2),
        Choice('시간 없어', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_workout_intensity',
      group: '${idp}_workout_core',
      title: '오늘 컨디션에 맞는 강도로 할 수 있어?',
      choices: const [
        Choice('맞출 수 있어', 6),
        Choice('애매', 0),
        Choice('무리할 듯', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_workout_injury',
      group: '${idp}_workout_core',
      title: '통증/부상 위험은 없나? (있으면 강도/종목 조절)',
      choices: const [
        Choice('문제 없어', 4),
        Choice('애매', 0),
        Choice('위험해', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_workout_finish',
      group: '${idp}_workout_core',
      title: '끝나고 스트레칭/샤워까지 마무리할 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('대충 끝낼 듯', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_workout_next',
      group: '${idp}_workout_core',
      title: '내일 회복(수면/식사)까지 생각하면 오늘은 적당해?',
      choices: const [
        Choice('적당해', 4),
        Choice('애매', 0),
        Choice('과할 듯', -4),
      ],
      tags: semiTags,
    ),
  ];

  final clean = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_clean_timer',
      group: '${idp}_clean_core',
      title: '30분 타이머 걸고 정리할 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('못 할 듯', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_clean_target',
      group: '${idp}_clean_core',
      title: '우선순위 1곳만 고른다면 어디야? (바닥/책상/싱크대)',
      choices: const [
        Choice('정했어', 4),
        Choice('애매', 0),
        Choice('못 고르겠어', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_clean_tools',
      group: '${idp}_clean_core',
      title: '도구/봉투/세제 등 “바로 시작” 세팅이 돼 있어?',
      choices: const [
        Choice('돼 있어', 4),
        Choice('애매', 0),
        Choice('아니', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_clean_reward',
      group: '${idp}_clean_core',
      title: '끝나고 작은 보상(샤워/차/휴식)까지 계획할래?',
      choices: const [
        Choice('할래', 2),
        Choice('애매', 0),
        Choice('안 할래', -2),
      ],
      tags: semiTags,
    ),
  ];
  final study = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_study_goal',
      group: '${idp}_study_core',
      title: '오늘 공부 목표를 “한 문장”으로 말할 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('아니', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_study_setup',
      group: '${idp}_study_core',
      title: '책/노트/강의 등 필요한 것들이 바로 열려 있어?',
      choices: const [
        Choice('돼 있어', 4),
        Choice('애매', 0),
        Choice('아직', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_study_pomodoro',
      group: '${idp}_study_core',
      title: '무리가 가지 않는선에서 할 수 있어?',
      choices: const [
        Choice('응', 6),
        Choice('애매', 0),
        Choice('안 될 듯', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_study_block',
      group: '${idp}_study_core',
      title: '방해요소(폰/알림)를 끄고 시작할 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('어려워', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_study_deadline',
      group: '${idp}_study_core',
      title: '마감/시험이 가까우면 지금 하는 게 이득이 커?',
      choices: const [
        Choice('커', 4),
        Choice('애매', 0),
        Choice('아니', -2),
      ],
      tags: semiTags,
    ),
  ];

  final latenight = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_latenight_hunger',
      group: '${idp}_latenight_core',
      title: '지금은 “진짜 배고픔”이야, “입/습관”이야?',
      choices: const [
        Choice('진짜 배고픔', 2),
        Choice('반반', -2),
        Choice('입/습관', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_latenight_sleep',
      group: '${idp}_latenight_core',
      title: '지금 먹으면 수면/내일 컨디션에 영향이 클까?',
      choices: const [
        Choice('영향 적음', 2),
        Choice('애매', 0),
        Choice('영향 큼', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_latenight_amount',
      group: '${idp}_latenight_core',
      title: '먹더라도 “양/칼로리” 선을 정할 수 있어?',
      choices: const [
        Choice('정할 수 있어', 6),
        Choice('애매', 0),
        Choice('못 지킬 듯', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_latenight_alt',
      group: '${idp}_latenight_core',
      title: '대체(물/차/단백질/과일/요거트)로 바꿀 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('아니', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_latenight_stop',
      group: '${idp}_latenight_core',
      title: '먹고 나서 “바로 끝” (추가 주문/추가 과자 금지) 가능?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('계속 먹게 돼', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_latenight_reason',
      group: '${idp}_latenight_core',
      title: '야식이 “스트레스 해소”면 다른 해소(샤워/산책/잠)도 있어?',
      choices: const [
        Choice('있어', 4),
        Choice('애매', 0),
        Choice('없어', -4),
      ],
      tags: semiTags,
    ),
  ];

  final smoke = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_smoke_now',
      group: '${idp}_smoke_core',
      title: '지금은 “갈망”이야, “습관/심심함”이야?',
      choices: const [
        Choice('갈망', -2),
        Choice('반반', -4),
        Choice('습관/심심함', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_smoke_delay',
      group: '${idp}_smoke_core',
      title: '10분만 미루고 다른 걸 해볼 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('어려워', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_smoke_sub',
      group: '${idp}_smoke_core',
      title: '대체(물/껌/산책/호흡)로 갈 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('아니', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_smoke_trigger',
      group: '${idp}_smoke_core',
      title: '트리거(커피/술/스트레스) 때문에 더 당기는 거야?',
      choices: const [
        Choice('맞아', -4),
        Choice('애매', 0),
        Choice('아니', 2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_smoke_limit',
      group: '${idp}_smoke_core',
      title: '오늘은 “몇 개비까지만” 선을 정할 수 있어?',
      choices: const [
        Choice('정할 수 있어', 6),
        Choice('애매', 0),
        Choice('못 지킬 듯', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_smoke_health',
      group: '${idp}_smoke_core',
      title: '지금 피우면 내일의 나에게 미안함이 생길까?',
      choices: const [
        Choice('아니', 2),
        Choice('애매', 0),
        Choice('그럴 듯', -4),
      ],
      tags: semiTags,
    ),
  ];

  final caffeine = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_caffeine_time',
      group: '${idp}_caffeine_core',
      title: '지금 카페인 마시면 오늘 잠(수면)에 영향이 있을까?',
      choices: const [
        Choice('거의 없음', 2),
        Choice('애매', 0),
        Choice('영향 큼', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_caffeine_amount',
      group: '${idp}_caffeine_core',
      title: '양을 줄이거나 디카페인으로 바꿀 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('아니', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_caffeine_reason',
      group: '${idp}_caffeine_core',
      title: '마시는 이유가 “각성”이야, “습관/맛”이야?',
      choices: const [
        Choice('각성', 2),
        Choice('반반', 0),
        Choice('습관/맛', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_caffeine_water',
      group: '${idp}_caffeine_core',
      title: '카페인 전에 물 한 컵부터 가능?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('아니', -2),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_caffeine_alt',
      group: '${idp}_caffeine_core',
      title: '대체(가벼운 스트레칭/햇빛/세수)로도 버틸 수 있어?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('어려워', -4),
      ],
      tags: semiTags,
    ),
  ];

  final game = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_game_limit',
      group: '${idp}_game_core',
      title: '플레이 “끝나는 기준(시간/판수)”을 정할 수 있어?',
      choices: const [
        Choice('정할 수 있어', 6),
        Choice('애매', 0),
        Choice('못 지킬 듯', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_game_purpose',
      group: '${idp}_game_core',
      title: '지금 게임은 “휴식/재미”야, “회피/도피”야?',
      choices: const [
        Choice('휴식/재미', 2),
        Choice('반반', 0),
        Choice('회피/도피', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_game_tilt',
      group: '${idp}_game_core',
      title: '지금 멘탈이 흔들리면(틸트) 더 길어질 가능성 있어?',
      choices: const [
        Choice('없어', 2),
        Choice('애매', 0),
        Choice('있어', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_game_commit',
      group: '${idp}_game_core',
      title: '오늘 해야 할 일(수면/공부/운동)을 먼저 처리했어?',
      choices: const [
        Choice('처리했어', 6),
        Choice('애매', 0),
        Choice('아니', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_game_spend',
      group: '${idp}_game_core',
      title: '과금/가챠는 오늘 “0원”으로 잠글 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('어려워', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_game_stop',
      group: '${idp}_game_core',
      title: '마지막에 “이기고 끝” 같은 조건 대신 그냥 종료 가능?',
      choices: const [
        Choice('가능', 4),
        Choice('애매', 0),
        Choice('어려워', -4),
      ],
      tags: semiTags,
    ),
  ];
  final growth = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_growth_small',
      group: '${idp}_growth_core',
      title: '오늘은 “작게라도(10~15분)” 할 수 있어?',
      choices: const [
        Choice('가능', 6
        ),
        Choice('애매', 0),
        Choice('오늘은 어려워', -4),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_growth_focus',
      group: '${idp}_growth_core',
      title: '방해요소(폰/소음)를 잠깐 치울 수 있어?',
      choices: const [
        Choice('치울 수 있어', 4
        ),
        Choice('애매', 0),
        Choice('치우기 어려워', -4),
      ],
      tags: semiTags,
    ),
  ];

  final rest = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_rest_type',
      group: '${idp}_rest_core',
      title: '이 휴식은 “회복”이야, “회피”에 가까워?',
      choices: const [
        Choice('회복', 6
        ),
        Choice('반반', 0),
        Choice('회피', -6),
      ],
      tags: semiTags,
    ),
  ];

  final control = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_control_trigger',
      group: '${idp}_control_core',
      title: '지금 이 행동을 부르는 “트리거”가 뭐야?',
      choices: const [
        Choice('피곤/공복', 0
        ),
        Choice('스트레스/감정', -6),
        Choice('습관/심심함', -4),
      ],
      tags: semiTags,
    ),
  ];

  final balance = <JudgeQuestion>[
    JudgeQuestion(
      id: '${idp}_balance_today',
      group: '${idp}_balance_core',
      title: '오늘 하루 전체 밸런스에서 이 행동은 어떤 위치야?',
      choices: const [
        Choice('딱 적당', 4
        ),
        Choice('좀 과할 수 있음', -2),
        Choice('이미 과했어', -6),
      ],
      tags: semiTags,
    ),
  ];

  final byTag = <String, List<JudgeQuestion>>{
    'food': food,
    'screen': screen,
    'spend': spend,
    'purchase': purchase,
    'alcohol': alcohol,
    'workout': workout,
    'clean': clean,
    'study': study,
    'latenight': latenight,
    'smoke': smoke,
    'caffeine': caffeine,
    'game': game,
    'growth': growth,
    'rest': rest,
    'control': control,
    'balance': balance,
  };

  return [...common, ...(byTag[tag] ?? balance)];
}

List<JudgeQuestion> buildQuestionPool({required String action, required ActionKind kind, required List<LogItem> logs}) {
  final now = DateTime.now();
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  final hour = now.hour;

  final stat = patternOf(logs, action);
  String freqText;
  if (stat.cnt5 == 0) {
    freqText = '최근 5일간 0회';
  } else {
    freqText = '최근 5일간 ${stat.cnt5}회';
  }
  final gapText = stat.lastAt == null
      ? '최근 기록 없음'
      : '마지막이 ${stat.hoursSinceLast}시간 전';
  final isNight = hour >= 22 || hour <= 3;

  // 사용자 유형 가정(간단 버전)
  final userType = isNight ? UserType.nightOwl : UserType.worker;

  // ✅ 공통(기본) 질문들: "어떤 행동에도 어색하지 않게" 톤 정리
  // - 과한 단정/비난 뉘앙스는 제거
  // - “선(시간/강도)” / “내일 영향” / “후회 가능성” 같은 보편 축으로 구성
  final base = <JudgeQuestion>[
    JudgeQuestion(
      id: 'goal',
      group: 'base_purpose',
      title: '지금 이 행동의 목적은 뭐야?',
      choices: const [
        Choice('회복/정리/리셋', 10),
        Choice('필요해서(의무/업무)', 6),
        Choice('즐거움/리프레시', 2),
        Choice('그냥 시간 때우기', -6),
      ],
    ),
    JudgeQuestion(
      id: 'energy',
      group: 'base_state',
      title: '지금 에너지는 어느 정도야?',
      choices: const [
        Choice('여유 있음', 6),
        Choice('보통', 2),
        Choice('지침', -4),
        Choice('완전 방전', -10),
      ],
    ),
    JudgeQuestion(
      id: 'tomorrow',
      group: 'base_schedule',
      title: '내일 일정은 어때?',
      choices: const [
        Choice('중요 일정 있음', -6),
        Choice('보통', 0),
        Choice('여유 있음', 4),
      ],
    ),
    JudgeQuestion(
      id: 'streak',
      group: 'base_history',
      title: '최근에 이 행동을 연속으로 했어?',
      choices: const [
        Choice('아니', 4),
        Choice('2~3번 연속', -4),
        Choice('4번 이상 연속', -10),
      ],
    ),
    JudgeQuestion(
      id: 'timebox',
      group: 'base_limit',
      title: '오늘 이 행동에 쓸 시간/강도는?',
      choices: const [
        Choice('짧게(10~20분)', 6),
        Choice('적당히(30~60분)', 2),
        Choice('길게(1시간 이상)', -4),
        Choice('아직 정해둔 게 없음', -10),
      ],
    ),
    JudgeQuestion(
      id: 'after',
      group: 'base_regret',
      title: '끝나고 후회할 가능성은?',
      choices: const [
        Choice('거의 없음', 6),
        Choice('조금 있음', 0),
        Choice('높음', -8),
      ],
    ),
    JudgeQuestion(
      id: 'alt',
      group: 'base_alternative',
      title: '지금 더 나은 대안(짧은 대체 행동)이 있어?',
      choices: const [
        Choice('없음', 2),
        Choice('있는데 하기 싫음', -4),
        Choice('있고 할 수 있음', 6),
      ],
    ),
    JudgeQuestion(
      id: 'rule',
      group: 'base_routine',
      title: '오늘 내 기본 루틴(수면/식사/운동)이 얼마나 지켜졌어?',
      choices: const [
        Choice('잘 지켜짐', 6),
        Choice('조금 흔들림', -2),
        Choice('많이 흔들림', -8),
      ],
    ),
    JudgeQuestion(
      id: 'tomorrow_me',
      group: 'base_future',
      title: '이 선택이 내일의 나에게 어떤 느낌일까?',
      choices: const [
        Choice('고마울 듯', 6),
        Choice('무난', 0),
        Choice('아쉬울 듯', -6),
      ],
    ),
    JudgeQuestion(
      id: 'control',
      group: 'base_limit',
      title: '오늘은 “선(시간/강도/예산)”을 지킬 자신 있어?',
      choices: const [
        Choice('지킬 수 있음', 6),
        Choice('애매', -4),
        Choice('지키기 어려워', -10),
      ],
    ),
    JudgeQuestion(
      id: 'stress',
      group: 'base_state',
      title: '지금 스트레스는 어느 정도야?',
      choices: const [
        Choice('낮음', 4),
        Choice('중간', 0),
        Choice('높음', -4),
        Choice('폭발 직전', -10),
      ],
    ),
    JudgeQuestion(
      id: 'body',
      group: 'base_state',
      title: '몸 컨디션은 어때?',
      choices: const [
        Choice('괜찮아', 4),
        Choice('약간 경고', -2),
        Choice('확실히 쉬어야', -8),
      ],
    ),
    JudgeQuestion(
      id: 'mind',
      group: 'base_state',
      title: '마음 상태는 어때?',
      choices: const [
        Choice('하면 도움이 될 것 같아', 2),
        Choice('감정이 좀 복잡해', -4),
        Choice('그냥 애매해', 0),
      ],
    ),
    JudgeQuestion(
      id: 'priority',
      group: 'base_priority',
      title: '오늘 가장 중요한 1순위는 뭐야?',
      choices: const [
        Choice('루틴/건강', 6),
        Choice('성과/일', 2),
        Choice('즐거움/리프레시', 2),
        Choice('그냥 버티기', -2),
      ],
    ),
    JudgeQuestion(
      id: 'risk',
      group: 'base_risk',
      title: '이 행동이 오늘 전체 흐름에 주는 리스크는?',
      choices: const [
        Choice('거의 없음', 6),
        Choice('조금 있음', 0),
        Choice('꽤 있음', -6),
      ],
    ),
    JudgeQuestion(
      id: 'postpone',
      group: 'base_timing',
      title: '이걸 30분만 미뤄도 괜찮을까?',
      choices: const [
        Choice('미뤄도 됨', 4),
        Choice('미루면 손해', -2),
        Choice('지금 아니면 안 됨', 2),
      ],
    ),
    JudgeQuestion(
      id: 'focus',
      group: 'base_focus',
      title: '지금 집중이 필요한 일이 남아 있어?',
      choices: const [
        Choice('있음', -4),
        Choice('조금', -2),
        Choice('없음', 2),
      ],
    ),
    JudgeQuestion(
      id: 'sleep_risk',
      group: 'base_sleep',
      title: '수면에 영향 줄 확률은?',
      choices: const [
        Choice('낮음', 4),
        Choice('중간', -4),
        Choice('높음', -10),
      ],
    ),
  ];
  // ✅ 관계/약속(social) 질문은 특정 행동에서만
  final tag = inferSemiTag(action, kind);

  final allowSocial =
      tag == 'selfcare' ||  // 자기관리
          tag == 'alcohol' ||   // 술
          tag == 'binge' ||     // 폭식
          tag == 'purchase' ||  // 구매
          tag == 'spend' ||     // 지출
          tag == 'caffeine';    // 카페인

  if (allowSocial) {
    base.add(
      JudgeQuestion(
        id: 'social',
        group: 'base_social',
        title: '이 선택이 관계/약속과 연결돼 있어?',
        choices: const [
          Choice('관련 있음', 2),
          Choice('약간', 0),
          Choice('전혀 아님', 0),
        ],
      ),
    );
  }

  // ✅ kind 전용 질문(두 번째 질문에 들어가게 되는 '톤/위험도' 체크)
  final kindSet = <JudgeQuestion>[
    JudgeQuestion(
      id: 'kind_anchor_1',
      group: 'kind_anchor',
      title: kind == ActionKind.good
          ? '이 행동을 하면 “뿌듯/정리” 느낌이 남을까?'
          : kind == ActionKind.bad
          ? '이 행동을 하면 “후회/자책”으로 이어질 확률이 높아?'
          : '이 행동이 오늘 균형에 도움이 될까, 흐트릴까?',
      choices: const [
        Choice('도움 될 듯', 6),
        Choice('애매', 0),
        Choice('흐트릴 듯', -6),
      ],
      tags: const ['kind_good', 'kind_neutral', 'kind_bad'],
    ),
    JudgeQuestion(
      id: 'kind_anchor_2',
      group: 'kind_anchor',
      title: kind == ActionKind.bad
          ? '지금은 “통제”가 필요한 순간 같아?'
          : kind == ActionKind.good
          ? '지금은 “작게라도” 해두면 좋은 순간 같아?'
          : '지금은 “무리 안 하고” 적당히가 더 중요한 순간 같아?',
      choices: const [
        Choice('맞아', 6),
        Choice('애매', 0),
        Choice('아니', -4),
      ],
      tags: const ['kind_good', 'kind_neutral', 'kind_bad'],
    ),
  ];



  // 사용자 유형별(야행성/직장인)
  if (userType == UserType.nightOwl) {
    base.add(
      JudgeQuestion(
        id: 'nightowl_sleep2',
        title: '오늘은 최소 수면시간(예: 6시간)을 지킬 수 있어?',
        choices: const [
          Choice('지킬 수 있음', 4),
          Choice('애매', -4),
          Choice('지키기 어려워', -10),
        ],
      ),
    );
  } else {
    base.add(
      JudgeQuestion(
        id: 'worker_focus2',
        title: '내일 오전 컨디션이 특히 중요해?',
        choices: const [
          Choice('매우 중요', -8),
          Choice('보통', 0),
          Choice('상관없음', 2),
        ],
      ),
    );
  }

  // 이벤트성(주말) — 연말/연초 질문은 "완전 삭제"
  if (isWeekend) {
    base.add(
      JudgeQuestion(
        id: 'weekend',
        title: '주말이면 기준을 조금 완화할까?',
        choices: const [
          Choice('조금 완화', 4),
          Choice('평소처럼', 0),
          Choice('오히려 더 관리', -2),
        ],
      ),
    );
  }

  // ✅ 추가 기본 질문(체감 다양성 확장용)
  final extraBase = <JudgeQuestion>[
  JudgeQuestion(
  id: 'base2_priority',
  group: 'base2_context',
  title: '지금 이 행동은 “지금 당장” 해야 하는 일이야, “해도 되는” 일이야?',
  choices: const [
  Choice('지금 당장 해야 함', 8),
  Choice('해도 되는데 미뤄도 됨', 0),
  Choice('사실 피하고 있는 것 같음', -6),
  ],
  ),
  JudgeQuestion(
  id: 'base2_exit',
  group: 'base2_limit',
  title: '멈출 “종료 신호”(알람/타이머/체크리스트)를 정해둘 수 있어?',
  choices: const [
  Choice('가능', 6),
  Choice('애매', 0),
  Choice('못 정하겠어', -6),
  ],
  ),
  JudgeQuestion(
  id: 'base2_regret',
  group: 'base2_emotion',
  title: '이걸 하고 나서 “후회”보다 “만족”이 남을 확률은?',
  choices: const [
  Choice('만족이 더 클 듯', 8),
  Choice('반반', 0),
  Choice('후회가 더 클 듯', -8),
  ],
  ),
  JudgeQuestion(
  id: 'base2_cost',
  group: 'base2_tradeoff',
  title: '이 행동 때문에 포기해야 하는 게 있어? (수면/운동/업무/약속)',
  choices: const [
  Choice('거의 없음', 6),
  Choice('조금 있음', -2),
  Choice('꽤 큼', -8),
  ],
  ),
  JudgeQuestion(
  id: 'base2_mood',
  group: 'base2_state',
  title: '지금 감정 상태는 어때?',
  choices: const [
  Choice('안정적', 4),
  Choice('살짝 예민/불안', -2),
  Choice('폭발 직전/우울', -6),
  ],
  ),
  JudgeQuestion(
  id: 'base2_next',
  group: 'base2_plan',
  title: '끝나고 바로 할 “다음 한 걸음”(샤워/정리/업무 10분 등)을 정해둘 수 있어?',
  choices: const [
  Choice('정할 수 있어', 6),
  Choice('애매', 0),
  Choice('못 정하겠어', -6),
  ],
  ),
  JudgeQuestion(
  id: 'base2_health',
  group: 'base2_body',
  title: '지금 몸 컨디션(두통/피곤/배고픔)은 이 행동에 영향을 줄까?',
  choices: const [
  Choice('괜찮아', 4),
  Choice('좀 애매해', 0),
  Choice('컨디션이 안 좋아서 위험', -6),
  ],
  ),


  // ✅ 확장 기본 질문(시간/돈/감정/리스크/관계/회복/루틴/장기목표/상황)
  JudgeQuestion(
  id: 'base3_time_01',
  group: 'base3_time',
  title: '오늘 일정에서 이 행동을 넣으면 다른 중요한 일이 밀릴까?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_02',
  group: 'base3_time',
  title: '지금 시작하면 끝나는 예상 시간은 현실적이야?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_03',
  group: 'base3_time',
  title: '타이머(예: 10/20/30분)로 \'딱 여기까지\'를 정할 수 있어?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_04',
  group: 'base3_time',
  title: '이걸 지금 하면 오늘의 \'피로 예산\'을 초과할까?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_05',
  group: 'base3_time',
  title: '내일 아침이 더 힘들어질 가능성이 있어?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_06',
  group: 'base3_time',
  title: '지금이 \'최고 집중 시간\'인데 그걸 써도 괜찮아?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_07',
  group: 'base3_time',
  title: '이 행동을 미루면 더 커지는 문제야, 아니면 그냥 욕구야?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_08',
  group: 'base3_time',
  title: '오늘 남은 시간 중 최소 1/3은 휴식으로 남겨둘 수 있어?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_09',
  group: 'base3_time',
  title: '이 행동은 지금 5분만 해도 효과가 나?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_10',
  group: 'base3_time',
  title: '지금 한다면 \'중간에 끊겼을 때\' 손해가 큰 편이야?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_11',
  group: 'base3_time',
  title: '이 행동을 하면 잠드는 시간이 늦어질 것 같아?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_12',
  group: 'base3_time',
  title: '30분 뒤에도 이걸 하고 싶을 것 같아?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_13',
  group: 'base3_time',
  title: '지금 하는 게 \'최적 타이밍\'인 이유가 확실해?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_14',
  group: 'base3_time',
  title: '이 행동 전후로 준비/정리 시간이 많이 드나?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_15',
  group: 'base3_time',
  title: '이 행동을 한 번 더 하면 오늘 총 몇 시간째야?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_16',
  group: 'base3_time',
  title: '지금 시작하면 \'약속/식사/운동\'을 건드릴 수 있어?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_17',
  group: 'base3_time',
  title: '이 행동을 \'짧게\'도 할 수 있어? (압축 버전)',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_time_18',
  group: 'base3_time',
  title: '지금은 \'리셋(샤워/산책/물)\'이 먼저일 수도 있어. 그래도 할래?',
  choices: const [
  Choice('위험해', -6),
  Choice('애매', 0),
  Choice('괜찮아', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_01',
  group: 'base3_money',
  title: '이 행동에 드는 비용(또는 기회비용)이 내가 정한 예산 안이야?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_02',
  group: 'base3_money',
  title: '지금 결제하면 24시간 뒤에도 후회 없을까?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_03',
  group: 'base3_money',
  title: '이건 \'필요\'야, \'편의\'야, \'기분\'이야?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_04',
  group: 'base3_money',
  title: '가장 싼/합리적 대안이 있는데도 굳이 이걸 고르는 이유가 있어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_05',
  group: 'base3_money',
  title: '이 지출이 다음 주 생활에 부담을 줄 가능성이 있어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_06',
  group: 'base3_money',
  title: '이 돈으로 더 우선순위 높은 걸 해결할 수 있어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_07',
  group: 'base3_money',
  title: '카드/후불이 아니라 지금 현금처럼 느끼고 결정했어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_08',
  group: 'base3_money',
  title: '지금은 할인/한정이라 급한데, 진짜 지금만 가능한 거야?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_09',
  group: 'base3_money',
  title: '이 지출이 \'습관화\'되면 한 달에 얼마나 될까?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_10',
  group: 'base3_money',
  title: '이건 \'한 번\'으로 끝나, 아니면 추가 지출이 따라와?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_11',
  group: 'base3_money',
  title: '같은 만족을 더 적은 돈으로 얻을 방법이 떠올라?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_12',
  group: 'base3_money',
  title: '이 지출이 내 가치관/목표(저축/투자/경험)에 맞아?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_13',
  group: 'base3_money',
  title: '지금 사면 집/방/책상에 쌓여서 죄책감 생길 것 같아?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_14',
  group: 'base3_money',
  title: '환불/취소가 쉬운 편이야?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_15',
  group: 'base3_money',
  title: '지금 사지 않아도 내일/다음 주에 충분히 살 수 있어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_16',
  group: 'base3_money',
  title: '이 지출을 한다면 다른 한 가지 지출을 포기할 수 있어?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_17',
  group: 'base3_money',
  title: '이건 \'남에게 보여주기\' 비중이 큰 편이야?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_money_18',
  group: 'base3_money',
  title: '이 구매가 오늘 기분을 잠깐 올리고 끝날 것 같아?',
  choices: const [
  Choice('예산 초과/후회각', -7),
  Choice('애매', 0),
  Choice('예산 OK/가치 있음', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_01',
  group: 'base3_emotion',
  title: '지금 감정(스트레스/분노/허무)이 판단을 밀어붙이고 있어?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_02',
  group: 'base3_emotion',
  title: '지금은 \'보상 심리\'로 하고 싶은 거야?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_03',
  group: 'base3_emotion',
  title: '이 행동이 끝나면 기분이 더 나빠질 가능성이 있어?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_04',
  group: 'base3_emotion',
  title: '지금 마음이 급하면 결정 품질이 떨어질 수 있어. 그래도 할래?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_05',
  group: 'base3_emotion',
  title: '이건 회피(하기 싫은 일 피하기) 성격이 강해?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_06',
  group: 'base3_emotion',
  title: '지금 외로움/심심함을 채우려는 행동일 수 있어?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_07',
  group: 'base3_emotion',
  title: '지금 상태에서 \'딱 5분만\' 쉬고도 똑같이 하고 싶을까?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_08',
  group: 'base3_emotion',
  title: '이 행동이 나를 진짜 진정시키는 편이야, 아니면 자극만 주는 편이야?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_09',
  group: 'base3_emotion',
  title: '지금 죄책감이 이미 있는데도 또 하려고 해?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_10',
  group: 'base3_emotion',
  title: '이 행동을 하면 \'자기혐오\'가 따라올 것 같아?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_11',
  group: 'base3_emotion',
  title: '이건 내 기분을 위한 \'건강한 선택\'에 가까워?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_12',
  group: 'base3_emotion',
  title: '지금은 누군가에게 확인/위로가 필요한 상태일 수 있어. 그게 먼저야?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_13',
  group: 'base3_emotion',
  title: '이 행동이 내 감정을 더 키울(과몰입) 수 있어?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_14',
  group: 'base3_emotion',
  title: '지금은 \'멈춤\'이 더 용기일 수도 있어. 멈출래?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_15',
  group: 'base3_emotion',
  title: '내가 내일의 나에게 이 선택을 설명할 수 있어?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_17',
  group: 'base3_emotion',
  title: '지금 기분을 0~10으로 치면? (0 최악) — 낮을수록 위험',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_emotion_18',
  group: 'base3_emotion',
  title: '이 행동 말고, 기분을 올릴 다른 안전한 방법이 떠올라?',
  choices: const [
  Choice('감정에 휘말림', -6),
  Choice('애매', 0),
  Choice('감정 안정/괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_01',
  group: 'base3_risk',
  title: '최악의 경우(손해/문제)가 뭔지 한 문장으로 말할 수 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_02',
  group: 'base3_risk',
  title: '이 행동이 규칙/약속을 어기는 요소가 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_03',
  group: 'base3_risk',
  title: '내 건강/수면/몸에 직접적인 악영향 가능성이 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_04',
  group: 'base3_risk',
  title: '이 행동은 되돌리기(복구)가 쉬운 편이야?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_05',
  group: 'base3_risk',
  title: '지금 결정이 \'충동\'에 가까워?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_06',
  group: 'base3_risk',
  title: '이 행동을 하다가 중단되면 큰 문제가 생겨?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_07',
  group: 'base3_risk',
  title: '이 행동이 사람/관계를 망칠 수 있는 리스크가 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_08',
  group: 'base3_risk',
  title: '안전장치(제한, 타이머, 알람, 예산)를 걸어둘 수 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_09',
  group: 'base3_risk',
  title: '이 행동의 리스크 대비 얻는 보상이 큰 편이야?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_10',
  group: 'base3_risk',
  title: '내가 지금 리스크를 과소평가하고 있지 않아?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_11',
  group: 'base3_risk',
  title: '이 행동이 다음 일정에 사고(지각/실수)를 부를 수 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),


  JudgeQuestion(
  id: 'base3_risk_13',
  group: 'base3_risk',
  title: '이 행동은 \'한 번\'이 아니라 반복되기 쉬워?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_14',
  group: 'base3_risk',
  title: '내 기준선(원칙)을 넘는 선택이야?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_15',
  group: 'base3_risk',
  title: '주변 사람이 보면 말릴 가능성이 높아?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_16',
  group: 'base3_risk',
  title: '이 행동으로 잃는 게 생기면 감당 가능해?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),

  JudgeQuestion(
  id: 'base3_risk_17',
  group: 'base3_risk',
  title: '리스크가 있다면 \'작게 테스트\'부터 할 수 있어?',
  choices: const [
  Choice('리스크 큼', -8),
  Choice('애매', 0),
  Choice('리스크 관리됨', 8),
  ],
  ),


  JudgeQuestion(
  id: 'base3_relation_01',
  group: 'base3_relation',
  title: '이 선택이 누군가에게 피해/실망을 줄 가능성이 있어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_02',
  group: 'base3_relation',
  title: '상대가 같은 상황이면 내가 권할 선택이야?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_03',
  group: 'base3_relation',
  title: '이 행동을 하면 약속(가족/연인/동료)을 깨게 돼?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),


  JudgeQuestion(
  id: 'base3_relation_05',
  group: 'base3_relation',
  title: '내가 지금 감정적으로 상대를 이용하려는 건 아니야?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_06',
  group: 'base3_relation',
  title: '이 선택을 미리 말하면 상대가 이해할 수 있을까?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_07',
  group: 'base3_relation',
  title: '지금은 혼자 결정하지 말고 의견을 듣는 게 더 안전해?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_08',
  group: 'base3_relation',
  title: '이 행동이 관계의 신뢰를 쌓는 쪽이야, 깎는 쪽이야?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_09',
  group: 'base3_relation',
  title: '상대의 입장/일정/감정을 충분히 고려했어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_10',
  group: 'base3_relation',
  title: '내가 바라는 기대치를 상대에게 분명히 전달했어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_11',
  group: 'base3_relation',
  title: '이 행동이 갈등을 키울 가능성이 있어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_12',
  group: 'base3_relation',
  title: '지금은 사과/정리가 먼저일 수도 있어. 그래도 할래?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_13',
  group: 'base3_relation',
  title: '내가 지금 \'인정받고 싶어서\' 무리하는 건 아니야?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_14',
  group: 'base3_relation',
  title: '이 선택이 장기적으로 관계에 좋은 습관을 만들까?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_15',
  group: 'base3_relation',
  title: '관계 때문에 내가 내 원칙을 너무 포기하고 있어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_16',
  group: 'base3_relation',
  title: '이 행동을 하면서도 \'경계선\'을 지킬 수 있어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_17',
  group: 'base3_relation',
  title: '상대에게 부탁/요청을 할 때 예의/타이밍이 맞아?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_relation_18',
  group: 'base3_relation',
  title: '이 행동 후에 꼭 해야 하는 관계 정리가 있어?',
  choices: const [
  Choice('관계에 무리', -7),
  Choice('애매', 0),
  Choice('관계에 OK', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_01',
  group: 'base3_recovery',
  title: '지금 몸 상태(피곤/통증/두통)가 좋지 않은 편이야?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_02',
  group: 'base3_recovery',
  title: '최근 3일 수면이 부족했다면, 이 행동은 위험해질 수 있어. 그래도 할래?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_03',
  group: 'base3_recovery',
  title: '배고픔/갈증 때문에 판단이 흐려진 상태일 수 있어. 먼저 해결할래?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_04',
  group: 'base3_recovery',
  title: '지금은 \'휴식/회복\'이 더 우선인 날이야?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_05',
  group: 'base3_recovery',
  title: '이 행동이 회복을 돕는 편이야, 방해하는 편이야?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_06',
  group: 'base3_recovery',
  title: '지금 카페인/자극을 더 넣으면 몸이 망가질 것 같아?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_07',
  group: 'base3_recovery',
  title: '오늘 운동/산책 같은 회복 행동을 10분이라도 했어?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_08',
  group: 'base3_recovery',
  title: '이 행동 후에 반드시 쉬는 시간을 확보할 수 있어?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_09',
  group: 'base3_recovery',
  title: '지금 자세/환경(침대/소파) 때문에 더 늘어질 것 같아?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_10',
  group: 'base3_recovery',
  title: '이 행동을 하면 식사/샤워/정리를 미루게 될 것 같아?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_11',
  group: 'base3_recovery',
  title: '지금 정신적으로 과부하(멍함) 상태야?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_12',
  group: 'base3_recovery',
  title: '‘지금은 쉬어도 된다’고 스스로 허락할 수 있어?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_13',
  group: 'base3_recovery',
  title: '회복을 위해 오늘은 \'작게\' 가는 게 낫지 않아?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_14',
  group: 'base3_recovery',
  title: '이 행동이 내일의 컨디션까지 갉아먹을 것 같아?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_15',
  group: 'base3_recovery',
  title: '지금은 5분 호흡/스트레칭이 먼저일 수 있어. 해볼래?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_16',
  group: 'base3_recovery',
  title: '몸이 보내는 경고(눈, 어깨, 허리)를 무시하고 있어?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_17',
  group: 'base3_recovery',
  title: '오늘 회복 목표(수면, 물, 산책) 중 하나라도 지켰어?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_recovery_18',
  group: 'base3_recovery',
  title: '이 행동을 할 거면 회복 플랜(물/휴식/종료)을 같이 세울래?',
  choices: const [
  Choice('컨디션 나쁨', -6),
  Choice('애매', 0),
  Choice('컨디션 괜찮음', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_01',
  group: 'base3_routine',
  title: '이 행동이 내 루틴(수면/운동/공부/정리)을 깨는 쪽이야?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_02',
  group: 'base3_routine',
  title: '오늘 해야 할 최소 루틴 1가지는 이미 했어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_03',
  group: 'base3_routine',
  title: '이 행동을 하기 전에 \'준비 루틴\'(정리/계획)을 1분만 할 수 있어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_04',
  group: 'base3_routine',
  title: '이 행동을 하고 나서도 \'마무리 루틴\'(정리/기록)을 할 수 있어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_05',
  group: 'base3_routine',
  title: '이 행동이 습관화되면 내 삶이 좋아질까?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_06',
  group: 'base3_routine',
  title: '지금은 루틴이 무너지는 구간이라 작은 규칙이 필요해. 규칙을 정할래?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_07',
  group: 'base3_routine',
  title: '오늘 내가 지키고 싶은 \'하나\'는 뭐야? 이 행동이 그걸 돕나?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_08',
  group: 'base3_routine',
  title: '이 행동이 자기관리(식사/수면)와 충돌해?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_09',
  group: 'base3_routine',
  title: '이 행동을 \'의식적으로\' 선택하고 있어, 그냥 자동으로 하고 있어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_10',
  group: 'base3_routine',
  title: '지금 내가 피하는 핵심 루틴이 있어? (예: 샤워/정리/공부)',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_11',
  group: 'base3_routine',
  title: '이 행동은 보상으로 적절해, 아니면 루틴을 무너뜨리는 보상이야?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_12',
  group: 'base3_routine',
  title: '일정을 다시 잡기 위한 \'리셋\' 행동을 먼저 할 수 있어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_13',
  group: 'base3_routine',
  title: '이 행동을 한다면 종료 후 바로 할 작은 루틴을 정할래?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_14',
  group: 'base3_routine',
  title: '오늘 루틴 점수(0~10) 기준으로 지금 선택은 플러스야 마이너스야?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_15',
  group: 'base3_routine',
  title: '이 행동이 나를 성장시키는 반복이야, 소모시키는 반복이야?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_16',
  group: 'base3_routine',
  title: '내가 나에게 한 약속(예: 이번 주 목표)을 깨게 될까?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_17',
  group: 'base3_routine',
  title: '이 행동을 \'미니 버전\'으로 바꿔 루틴을 지킬 수 있어?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_routine_18',
  group: 'base3_routine',
  title: '이 행동 후 ‘기록’까지 하면 루틴이 된다. 기록할래?',
  choices: const [
  Choice('루틴 깨짐', -6),
  Choice('애매', 0),
  Choice('루틴에 도움', 6),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_01',
  group: 'base3_goal',
  title: '이 행동이 장기 목표(커리어/건강/재정)에 도움이 돼?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_02',
  group: 'base3_goal',
  title: '이건 \'미래의 나\'가 고마워할 선택일까?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_03',
  group: 'base3_goal',
  title: '1주일 뒤에 봐도 의미 있는 선택이야?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_04',
  group: 'base3_goal',
  title: '이 행동이 지금 내 방향성과 일치해?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_05',
  group: 'base3_goal',
  title: '이걸 하면 목표에 가까워지는 행동을 하나 덜 하게 되나?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_06',
  group: 'base3_goal',
  title: '이 행동이 내 정체성(나는 이런 사람)과 맞아?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_07',
  group: 'base3_goal',
  title: '이건 \'단기 쾌감\'이야, \'장기 성과\'야?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_08',
  group: 'base3_goal',
  title: '장기적으로 비용(시간/돈/건강)이 커질 가능성이 있어?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_09',
  group: 'base3_goal',
  title: '이 행동이 내 인생을 바꾸는 작은 습관이 될 수 있어?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),


  JudgeQuestion(
  id: 'base3_goal_11',
  group: 'base3_goal',
  title: '이 행동을 하고 나서 다음 행동(연결)을 계획할 수 있어?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_12',
  group: 'base3_goal',
  title: '이 선택이 내 가치(가족/성장/자유)에 맞아?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_13',
  group: 'base3_goal',
  title: '이 행동이 내 평판/신뢰를 쌓는 쪽이야?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_14',
  group: 'base3_goal',
  title: '이 행동이 나를 분산시키는 쪽이야, 집중시키는 쪽이야?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_15',
  group: 'base3_goal',
  title: '오늘의 선택이 1년 뒤 누적되면 어떤 사람이 될까?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),


  JudgeQuestion(
  id: 'base3_goal_17',
  group: 'base3_goal',
  title: '이 행동을 목표에 맞게 조정(작게/깊게)할 수 있어?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_goal_18',
  group: 'base3_goal',
  title: '이 행동을 하되, 목표를 지키는 안전장치를 넣을 수 있어?',
  choices: const [
  Choice('목표와 어긋남', -7),
  Choice('애매', 0),
  Choice('목표에 도움', 7),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_01',
  group: 'base3_context',
  title: '지금 장소/상황에서 이 행동을 하는 게 적절해?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),


  JudgeQuestion(
  id: 'base3_context_03',
  group: 'base3_context',
  title: '핸드폰/앱/환경이 나를 유혹하게 세팅돼 있어? 차단할 수 있어?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_04',
  group: 'base3_context',
  title: '지금은 \'집중 환경\'을 만들지 않으면 실패할 확률이 높아. 환경을 바꿀래?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_05',
  group: 'base3_context',
  title: '이 행동을 하기에 필요한 준비가 갖춰져 있어?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),



  JudgeQuestion(
  id: 'base3_context_08',
  group: 'base3_context',
  title: '지금은 사람 시선 때문에 무리하는 선택을 하고 있어?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),


  JudgeQuestion(
  id: 'base3_context_10',
  group: 'base3_context',
  title: '지금 인터넷/알림 때문에 흐름이 깨질 것 같아. 알림 끌 수 있어?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_11',
  group: 'base3_context',
  title: '이 행동은 지금 \'앉아서\' 하기보다 \'서서/걷기\'로 바꾸면 좋아질까?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_12',
  group: 'base3_context',
  title: '지금은 기기 배터리/데이터 등 제약이 있어? 그럼 스트레스 될까?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),


  JudgeQuestion(
  id: 'base3_context_14',
  group: 'base3_context',
  title: '지금은 술자리/회식 같은 분위기 영향이 커? 그럼 결정 위험해져.',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_15',
  group: 'base3_context',
  title: '지금은 너무 늦어서(야간) 평소 기준이 흔들릴 수 있어. 인정할래?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),

  JudgeQuestion(
  id: 'base3_context_16',
  group: 'base3_context',
  title: '이 행동을 할 거면 주변에 한마디(양해/공지)할 필요가 있어?',
  choices: const [
  Choice('환경 안 좋음', -5),
  Choice('애매', 0),
  Choice('환경 OK', 5),
  ],
  ),



  // ✅ 행동 전용 질문
  final actionSpecific = <JudgeQuestion>[];

  if (action == '구매') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'buy_reason',
  group: 'action_buy_core',
  title: '이번 구매는 어떤 타입이야?',
  choices: const [
  Choice('꼭 필요', 8
  ),
  Choice('계획된 소비', 6),
  Choice('선물/이벤트', 2),
  Choice('충동/스트레스', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'buy_budget',
  group: 'action_buy_core',
  title: '예산 대비 어느 정도야?',
  choices: const [
  Choice('예산 안', 4
  ),
  Choice('살짝 초과', -2),
  Choice('크게 초과', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'buy_return',
  group: 'action_buy_core',
  title: '이 소비를 내일 다시 보면?',
  choices: const [
  Choice('잘 샀다 싶을 듯', 4
  ),
  Choice('애매할 듯', -2),
  Choice('후회할 듯', -8),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'buy_need_level',
  group: 'action_buy_need',
  title: '이건 “지금 당장” 필요해?',
  choices: const [
  Choice('지금 필요', 4
  ),
  Choice('조금 급함', 0),
  Choice('급하지 않음', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'buy_compare',
  group: 'action_buy_risk',
  title: '비교/대체를 해봤어?',
  choices: const [
  Choice('충분히 비교', 2
  ),
  Choice('대충 봄', 0),
  Choice('안 봄(바로 결제)', -4),
  ],
  tags: [action],
  ),


  JudgeQuestion(
  id: 'buy_need_delay',
  group: 'action_buy_core2',
  title: '이건 “오늘 안 사면 손해”야, 아니면 “내일 사도 되는 것”이야?',
  choices: const [
  Choice('내일 사도 돼', 6
  ),
  Choice('상황에 따라', 0),
  Choice('오늘 아니면 후회/손해', -2),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'buy_return',
  group: 'action_buy_risk',
  title: '반품/환불/중고처분 루트가 확실해?',
  choices: const [
  Choice('확실해', 4
  ),
  Choice('애매', 0),
  Choice('거의 불가', -6),
  ],
  tags: [action],
  ),
  ]);
  }

  if (action == '술') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'alcohol_amount',
  group: 'action_alcohol_core',
  title: '오늘 술은 어느 정도?',
  choices: const [
  Choice('한두 잔', 2
  ),
  Choice('적당히', -4),
  Choice('많이', -12),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'alcohol_context',
  group: 'action_alcohol_core',
  title: '왜 마시는 거야?',
  choices: const [
  Choice('약속/관계', 2
  ),
  Choice('축하/이벤트', 0),
  Choice('스트레스/회피', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'alcohol_food',
  group: 'action_alcohol_core',
  title: '안주/물/수면까지 챙길 수 있어?',
  choices: const [
  Choice('챙길 수 있음', 2
  ),
  Choice('애매', -4),
  Choice('못 챙김', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'alcohol_tomorrow',
  group: 'action_alcohol_next',
  title: '내일 컨디션이 얼마나 중요해?',
  choices: const [
  Choice('매우 중요', -8
  ),
  Choice('보통', -2),
  Choice('상관없음', 0),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'alcohol_transport',
  group: 'action_alcohol_safety',
  title: '귀가/안전 계획은 확실해?',
  choices: const [
  Choice('확실함', 2
  ),
  Choice('애매', -2),
  Choice('불확실', -6),
  ],
  tags: [action],
  ),

  ]);
  }

  if (action == '자기전 폰') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'phone_time',
  group: 'action_phone_core',
  title: '자기 전 폰은 몇 분만 할 거야?',
  choices: const [
  Choice('10분만', 4
  ),
  Choice('30분 정도', -4),
  Choice('1시간 이상', -12),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'phone_content',
  group: 'action_phone_core',
  title: '보는 건 어떤 종류야?',
  choices: const [
  Choice('가벼운 것', 2
  ),
  Choice('자극적인 것', -6),
  Choice('일/업무', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'phone_trigger',
  group: 'action_phone_trigger',
  title: '자기 전 폰을 하는 “트리거”가 뭐야?',
  choices: const [
  Choice('습관', -2
  ),
  Choice('정보 확인', -2),
  Choice('불안/심심함', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'phone_block',
  group: 'action_phone_limit',
  title: '알림/앱을 잠깐 막을 수 있어?',
  choices: const [
  Choice('가능(방해금지/타이머)', 4
  ),
  Choice('부분 가능', 0),
  Choice('어려움', -4),
  ],
  tags: [action],
  ),

  ]);
  }

  if (action == '폭식') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'binge_trigger',
  group: 'action_binge_core',
  title: '지금 먹는 이유는 뭐에 가까워?',
  choices: const [
  Choice('배고픔/식사 누락', 2
  ),
  Choice('스트레스', -8),
  Choice('습관', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'binge_plan',
  group: 'action_binge_core',
  title: '폭식 대신 “대체 플랜”이 있어?',
  choices: const [
  Choice('있고 할 수 있음', 4
  ),
  Choice('있지만 하기 싫음', -2),
  Choice('없음', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'binge_first',
  group: 'action_binge_first',
  title: '먹기 전에 “첫 단계”를 할 수 있어?',
  choices: const [
  Choice('물 한 컵 + 3분', 4
  ),
  Choice('샐러드/단백질 먼저', 4),
  Choice('바로 먹을래', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'binge_stop',
  group: 'action_binge_stop',
  title: '멈추는 기준을 정할 수 있어?',
  choices: const [
  Choice('정할 수 있음', 2
  ),
  Choice('애매', -2),
  Choice('못 정함', -6),
  ],
  tags: [action],
  ),

  ]);
  }

  // ✅ 청소 전용(자연스러운 질문 3개)
  if (action == '청소') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'clean_scope',
  group: 'action_clean_core',
  title: '오늘 청소는 어느 정도만 할 거야?',
  choices: const [
  Choice('딱 10~15분만', 6
  ),
  Choice('한 공간만', 4),
  Choice('집 전체/대청소', -2),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'clean_impact',
  group: 'action_clean_core',
  title: '지금 청소하면 오늘이 더 좋아질까?',
  choices: const [
  Choice('확실히 좋아짐', 6
  ),
  Choice('조금 도움', 2),
  Choice('오히려 지침', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'clean_delay',
  group: 'action_clean_core',
  title: '이걸 미루면 내일 더 귀찮아질까?',
  choices: const [
  Choice('더 귀찮아짐', 4
  ),
  Choice('비슷함', 0),
  Choice('내일 해도 됨', 2),
  ],
  tags: [action],
  ),

  JudgeQuestion(
  id: 'clean_reward',
  group: 'action_clean_reward',
  title: '끝나고 “작은 보상”을 줄 수 있어?',
  choices: const [
  Choice('가능', 2
  ),
  Choice('굳이 필요 없음', 0),
  Choice('보상 없이도 함', 0),
  ],
  tags: [action],
  ),

  ]);
  }

  // ✅ 휴식 전용 (GOOD로 분류돼도 어색하지 않게)
  if (action == '휴식') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'rest_need',
  group: 'action_rest_core',
  title: '지금 휴식이 “필요”에 더 가까워?',
  choices: const [
  Choice('필요(회복)', 8
  ),
  Choice('반반(회복+기분전환)', 2),
  Choice('그냥 미루는 느낌', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'rest_after',
  group: 'action_rest_core',
  title: '휴식 후에 “가벼운 할 일 1개”가 가능해?',
  choices: const [
  Choice('가능', 4
  ),
  Choice('애매', 0),
  Choice('불가능', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'rest_type',
  group: 'action_rest_type',
  title: '휴식의 형태는 뭐가 더 맞아?',
  choices: const [
  Choice('눈/뇌 쉬기(가만히)', 4
  ),
  Choice('가벼운 산책/스트레칭', 4),
  Choice('스크린(영상/폰)', -2),
  ],
  tags: [action],
  ),

  ]);
  }

  // ✅ 게임 전용
  if (action == '게임') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'game_time',
  group: 'action_game_core',
  title: '게임은 어느 정도만 할 거야?',
  choices: const [
  Choice('30분 이하', 6
  ),
  Choice('1시간 정도', 0),
  Choice('2시간 이상', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'game_reason',
  group: 'action_game_core',
  title: '게임을 하는 이유는 뭐야?',
  choices: const [
  Choice('가벼운 리프레시', 2
  ),
  Choice('사람들과 약속', 2),
  Choice('현실 회피 느낌', -8),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'game_after',
  group: 'action_game_core',
  title: '게임 후에 수면/할 일에 영향이 있을까?',
  choices: const [
  Choice('거의 없음', 4
  ),
  Choice('조금 있음', -2),
  Choice('크게 있음', -8),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'game_mode',
  group: 'action_game_mode',
  title: '게임 모드는 어떤 쪽이야?',
  choices: const [
  Choice('가볍게 1~2판', 4
  ),
  Choice('랭크/몰입', -4),
  Choice('친구랑 약속', 2),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'game_stop',
  group: 'action_game_stop',
  title: '끝나는 조건을 정했어?',
  choices: const [
  Choice('정함(판 수/시간)', 4
  ),
  Choice('대충 느낌대로', -2),
  Choice('정하기 어려움', -6),
  ],
  tags: [action],
  ),

  ]);
  }

  // ✅ 카페인 전용
  if (action == '카페인') {
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'caffeine_time',
  group: 'action_caffeine_core',
  title: '지금 카페인은 “시간대”가 어때?',
  choices: const [
  Choice('오전/점심', 4
  ),
  Choice('오후', 0),
  Choice('저녁/밤', -8),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'caffeine_need',
  group: 'action_caffeine_core',
  title: '카페인을 마시는 이유는?',
  choices: const [
  Choice('집중/업무', 2
  ),
  Choice('습관', -2),
  Choice('피곤해서 버티기', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'caffeine_amount',
  group: 'action_caffeine_core',
  title: '양은 어느 정도로 생각해?',
  choices: const [
  Choice('적당히(1잔)', 2
  ),
  Choice('조금 많음(2잔)', -4),
  Choice('많이(3잔 이상)', -10),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'caffeine_alt',
  group: 'action_caffeine_alt',
  title: '카페인 말고 대체가 가능해?',
  choices: const [
  Choice('물/간식/바람 쐬기', 2
  ),
  Choice('잠깐 눈 붙이기', 4),
  Choice('대체 없음', 0),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'caffeine_sleep',
  group: 'action_caffeine_sleep',
  title: '오늘 잠드는 시간이 얼마나 남았어?',
  choices: const [
  Choice('8시간 이상', 2
  ),
  Choice('4~8시간', -2),
  Choice('4시간 이내', -8),
  ],
  tags: [action],
  ),

  ]);
  }

  // kind 기반 보정 질문(과한 중복은 제거하고 “부드럽게”)
  if (kind == ActionKind.good) {
  actionSpecific.add(
  JudgeQuestion(
  id: 'good_scale',
  group: 'action_kind_good',
  title: '이 행동, 과하게 하면 오히려 지치진 않을까?',
  choices: const [
  Choice('적당히 할 수 있음', 4),
  Choice('가끔 과함', -2),
  Choice('자주 과함', -6),
  ],
  tags: [action],
  ),
  );
  }
  if (kind == ActionKind.bad) {
  // 기존 bad_control은 control과 중복되지만,
  // BAD일 때는 “선” 질문을 한 번 더 떠올리게 하는 용도로 유지(톤만 완화)
  actionSpecific.add(
  JudgeQuestion(
  id: 'bad_control',
  group: 'action_kind_bad',
  title: '특히 이 행동은 “선”을 지킬 수 있을까?',
  choices: const [
  Choice('지킬 수 있음', 2),
  Choice('애매', -4),
  Choice('지키기 어려워', -10),
  ],
  tags: [action],
  ),
  );
  }


// ✅ 어떤 행동에도 적용되는 “행동 전용(라이트) 질문” 2~3개 (체감 다양성 ↑)
  actionSpecific.addAll([
  JudgeQuestion(
  id: 'act_size',
  group: 'action_generic_size',
  title: '이 행동은 “작게” 할 수 있어?',
  choices: const [
  Choice('작게 가능', 4),
  Choice('보통', 0),
  Choice('작게 하기 어려움', -4),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'act_switch',
  group: 'action_generic_switch',
  title: '이 행동을 하고 나서 바로 멈출 수 있어?',
  choices: const [
  Choice('멈출 수 있음', 4),
  Choice('애매', -2),
  Choice('멈추기 어렵다', -6),
  ],
  tags: [action],
  ),
  JudgeQuestion(
  id: 'act_value',
  group: 'action_generic_value',
  title: '이 행동이 오늘의 “가치”에 맞아?',
  choices: const [
  Choice('맞아', 4),
  Choice('반반', 0),
  Choice('좀 어긋나', -4),
  ],
  tags: [action],
  ),
  ]);


  // ✅ 태그 판정(구매/지출일 때만 money 질문 허용)
  final tag = inferSemiTag(action, kind);

// extraBase 안의 base3_money는 (spend/purchase)일 때만 유지
  final allowMoney = (tag == 'spend' || tag == 'purchase');
  final extraBaseFiltered = allowMoney
  ? extraBase
      : extraBase.where((q) => q.group != 'base3_money').toList();

// ✅ 최종 풀 반환
  return [...base, ...kindSet, ...extraBaseFiltered, ...actionSpecific];
