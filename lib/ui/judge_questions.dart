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
  // 게임(플레이)
  if (RegExp(r'(게임|롤|리그오브레전드|배그|배틀그라운드|오버워치|발로란트|메이플|로아|로스트아크|피파|서든|스팀)').hasMatch(a)) return 'game';

  // 운동(신체)
  if (RegExp(r'(운동|헬스|러닝|조깅|걷기|런닝|요가|필라테스|스트레칭|웨이트|스쿼트|푸쉬업|자전거)').hasMatch(a)) return 'workout';

  // 청소/정리
  if (RegExp(r'(청소|정리|정돈|설거지|빨래|정리정돈|방치우기)').hasMatch(a)) return 'clean';

  // ✅ 휴식/회복 (⭐ 추가)
  if (RegExp(r'(휴식|쉬기|쉼|멍때|멍때리|눕기|잠깐쉬|브레이크|break|recharge)').hasMatch(a)) {
    return 'rest';
  }
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


  // 성장(명시적) — clean/study/workout처럼 이미 분리된 건 제외하고,
  // “프로젝트/연습/창작/글쓰기”처럼 성장 의도가 분명한 행동만.
  if (RegExp(r'(성장|프로젝트|사이드|연습|훈련|글쓰기|작업|개발|코딩프로젝트|포트폴리오|창작)').hasMatch(a)) {
    return 'growth';
  }

  // fallback: 애매하면 균형 질문으로 (돈/지출로 떨어지지 않게)
  switch (kind) {
    case ActionKind.good:
      return 'growth';
    case ActionKind.bad:
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
      title: '“시간/강도”의 상한을 정할 수 있어?',
      choices: const [
        Choice('가능', 6),
        Choice('애매', 0),
        Choice('정하기 어려워', -8),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_stop',
      group: '${idp}_core',
      title: '중간에 멈추거나 줄일 수 있을까?',
      choices: const [
        Choice('멈출 수 있어', 6),
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
        Choice('진짜 배고픔', 2),
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
        Choice('가능해', 6),
        Choice('애매', 0),
        Choice('대체 어려워(그게 땡겨)', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_food_time',
      group: '${idp}_food_night',
      title: '시간대가 늦을수록 내일 영향이 커져. 지금 시간은?',
      choices: [
        Choice('이른 편', 4),
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
        Choice('정해놨어', 6),
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
        Choice('있어', 4),
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
      title: '지금은 목적 있는 시청이야?',
      choices: const [
        Choice('목적 있음', 4),
        Choice('애매', 0),
        Choice('목적 없음', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_screen_timer',
      group: '${idp}_screen_core',
      title: '타이머/알람으로 “끝내는 시간”을 걸어둘래?',
      choices: const [
        Choice('걸 수 있어', 6),
        Choice('애매', 0),
        Choice('안 걸 것 같아', -6),
      ],
      tags: semiTags,
    ),
    JudgeQuestion(
      id: '${idp}_screen_sleep',
      group: '${idp}_screen_night',
      title: '수면에 영향이 있다면 강도/시간을 줄이는 게 좋아. 지금 시간은?',
      choices: [
        Choice('자려면 멀었어', 4),
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
        Choice('필요', 6),
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
        Choice('있어', 6),
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
      title: '지금 마시는 이유가 “즐거움”이야, “스트레스 풀기”야?',
      choices: const [
        Choice('즐거움', 4),
        Choice('반반', 0),
        Choice('스트레스 풀기', -6),
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
      title: '시간을 정해놓고 그 시간 동안 정리할 수 있어?',
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
      title: '우선순위 1곳만 고른다면 어디야?\n(예: 책상/침대/바닥/설거지)',
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
      title: '책/노트/강의 등 필요한 것들을 바로 준비 할 수 있어?',
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
      title: '지금 게임은 “휴식/재미”야, “미루기/도피”야?',
      choices: const [
        Choice('휴식/재미', 2),
        Choice('반반', 0),
        Choice('미루기/도피', -6),
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
      title: '이 휴식은 “회복”이야, “미루기/도피”에 가까워?',
      choices: const [
        Choice('회복', 6
        ),
        Choice('반반', 0),
        Choice('미루기/도피', -6),
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
    'game': game,
    'growth': growth,
    'rest': rest, // ✅ 추가 (⭐ 핵심)
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
      id: 'base2_health',
      group: 'base2_body',
      title: '지금 몸 컨디션(두통/피곤/배고픔)은 이 행동에 영향을 줄까?',
      choices: const [
        Choice('괜찮아', 4),
        Choice('좀 애매해', 0),
        Choice('컨디션이 안 좋아서 위험', -6),
      ],
    ),


    // ===== base3_time (리라이팅 버전) =====

    JudgeQuestion(
      id: 'base3_time_01',
      group: 'base3_time',
      title: '오늘 일정에 이걸 넣으면 다른 중요한 일이 밀릴 가능성이 커?',
      choices: const [
        Choice('밀릴 가능성 큼', -6),
        Choice('애매', 0),
        Choice('거의 안 밀림', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_02',
      group: 'base3_time',
      title: '지금 시작하면 끝나는 시간(예상)이 현실적인 편이야?',
      choices: const [
        Choice('비현실적이야', -6),
        Choice('애매', 0),
        Choice('현실적이야', 6),
      ],
    ),


    JudgeQuestion(
      id: 'base3_time_04',
      group: 'base3_time',
      title: '이걸 하면 오늘 “피로/에너지 예산”을 초과할 것 같아?',
      choices: const [
        Choice('초과할 듯', -6),
        Choice('애매', 0),
        Choice('초과 안 할 듯', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_05',
      group: 'base3_time',
      title: '이걸 하면 내일 아침이 더 힘들어질 가능성이 커?',
      choices: const [
        Choice('커', -6),
        Choice('애매', 0),
        Choice('크지 않아', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_06',
      group: 'base3_time',
      title: '정한 시간동안 집중해서 할 수 있어??',
      choices: const [
        Choice('하기 힘들 듯', -6),
        Choice('애매', 0),
        Choice('할 수 있어', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_07',
      group: 'base3_time',
      title: '지금 안 하면 손해가 생기는 행동이야?',
      choices: const [
        Choice('손해가 커짐', -6),
        Choice('애매', 0),
        Choice('지금 안 해도 문제 없음', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_08',
      group: 'base3_time',
      title: '오늘 남은 시간 중 “휴식”을 최소한은 남겨둘 수 있어?',
      choices: const [
        Choice('남기기 어려워', -6),
        Choice('애매', 0),
        Choice('남길 수 있어', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_09',
      group: 'base3_time',
      title: '이 행동은 “10분만 해도” 의미 있는 효과가 나?',
      choices: const [
        Choice('효과 거의 없음', -6),
        Choice('애매', 0),
        Choice('효과 있음', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_10',
      group: 'base3_time',
      title: '지금 시작했다가 중간에 끊기면 손해가 큰 편이야?',
      choices: const [
        Choice('손해가 큼', -6),
        Choice('애매', 0),
        Choice('손해 거의 없음', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_11',
      group: 'base3_time',
      title: '이걸 하면 잠드는 시간이 늦어질 가능성이 커?',
      choices: const [
        Choice('늦어질 듯', -6),
        Choice('애매', 0),
        Choice('크지 않아', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_12',
      group: 'base3_time',
      title: '30분 뒤에도 이걸 “여전히 하고 싶을” 것 같아?',
      choices: const [
        Choice('아니(식을 듯)', -6),
        Choice('애매', 0),
        Choice('응(계속 하고 싶음)', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_13',
      group: 'base3_time',
      title: '지금이 “최적 타이밍”이라는 이유가 분명해?',
      choices: const [
        Choice('분명하지 않아', -6),
        Choice('애매', 0),
        Choice('분명해', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_14',
      group: 'base3_time',
      title: '이 행동은 준비/정리(세팅/치우기) 시간이 많이 드는 편이야?',
      choices: const [
        Choice('많이 듦', -6),
        Choice('애매', 0),
        Choice('거의 안 듦', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_15',
      group: 'base3_time',
      title: '이걸 하면 오늘 “총량(시간/횟수)”이 과해질 가능성이 있어?',
      choices: const [
        Choice('과해질 듯', -6),
        Choice('애매', 0),
        Choice('괜찮을 듯', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_16',
      group: 'base3_time',
      title: '지금 시작하면 약속/식사/운동 같은 고정 일정을 건드릴 수 있어?',
      choices: const [
        Choice('건드릴 수 있어', -6),
        Choice('애매', 0),
        Choice('안 건드려', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_17',
      group: 'base3_time',
      title: '이 행동을 “짧게(압축 버전)”로 끝낼 수도 있어?',
      choices: const [
        Choice('어려워(길어질 듯)', -6),
        Choice('애매', 0),
        Choice('가능해(짧게 가능)', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_time_18',
      group: 'base3_time',
      title: '지금은 먼저 리셋(물/샤워/산책)이 필요한 상태일 수도 있어. 그래도 할래?',
      choices: const [
        Choice('리셋이 먼저 같아', -6),
        Choice('애매', 0),
        Choice('그래도 해도 돼', 6),
      ],
    ),


    // ===== base3_money (최종 리라이팅 반영본) =====

    JudgeQuestion(
      id: 'base3_money_01',
      group: 'base3_money',
      title: '이 지출, 내가 정해둔 예산 안에서 감당 가능한 수준이야?',
      choices: const [
        Choice('감당 어렵다', -7),
        Choice('애매', 0),
        Choice('감당 가능하다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_02',
      group: 'base3_money',
      title: '하루 지나서 다시 봐도 “잘 샀다”라고 느낄 것 같아?',
      choices: const [
        Choice('후회할 것 같다', -7),
        Choice('애매', 0),
        Choice('그럴 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_03',
      group: 'base3_money',
      title: '이건 정말 필요한 지출이야, 아니면 그냥 기분 지출이야?',
      choices: const [
        Choice('기분 지출에 가깝다', -7),
        Choice('애매', 0),
        Choice('필요한 지출이다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_04',
      group: 'base3_money',
      title: '더 싸거나 합리적인 대안이 있는데도, 이걸 고를 분명한 이유가 있어?',
      choices: const [
        Choice('이유가 약하다', -7),
        Choice('애매', 0),
        Choice('분명한 이유가 있다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_05',
      group: 'base3_money',
      title: '이거 사고 나면 다음 주 생활비가 빠듯해질 것 같아?',
      choices: const [
        Choice('빠듯해질 것 같다', -7),
        Choice('애매', 0),
        Choice('괜찮을 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_06',
      group: 'base3_money',
      title: '이 돈을 더 중요한 데 써야 한다는 생각은 안 들어?',
      choices: const [
        Choice('그 생각이 든다', -7),
        Choice('애매', 0),
        Choice('지금 써도 괜찮다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_07',
      group: 'base3_money',
      title: '이걸 실제 현금 나간다고 생각하고도 같은 선택을 할까?',
      choices: const [
        Choice('아니었을 것 같다', -7),
        Choice('애매', 0),
        Choice('같은 선택 할 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_08',
      group: 'base3_money',
      title: '“지금 아니면 안 돼”라는 말에 휩쓸린 건 아닐까?',
      choices: const [
        Choice('그런 것 같다', -7),
        Choice('애매', 0),
        Choice('아니다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_09',
      group: 'base3_money',
      title: '이게 습관처럼 반복되면, 한 달 지출로 봐도 괜찮을까?',
      choices: const [
        Choice('부담될 것 같다', -7),
        Choice('애매', 0),
        Choice('괜찮을 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_10',
      group: 'base3_money',
      title: '이거 한 번으로 끝날까, 아니면 계속 돈이 들어갈까?',
      choices: const [
        Choice('계속 돈이 들 것 같다', -7),
        Choice('애매', 0),
        Choice('한 번으로 끝날 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_11',
      group: 'base3_money',
      title: '비슷한 만족을 더 적은 돈으로 얻을 방법이 떠올라?',
      choices: const [
        Choice('떠오른다', -7),
        Choice('애매', 0),
        Choice('안 떠오른다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_12',
      group: 'base3_money',
      title: '이 지출, 지금의 내 목표나 가치관이랑 어긋나진 않아?',
      choices: const [
        Choice('어긋난다', -7),
        Choice('애매', 0),
        Choice('잘 맞는다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_13',
      group: 'base3_money',
      title: '사놓고 안 쓰거나 쌓아두면서 후회할 것 같아?',
      choices: const [
        Choice('그럴 것 같다', -7),
        Choice('애매', 0),
        Choice('아닐 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_14',
      group: 'base3_money',
      title: '마음 바뀌면 쉽게 취소하거나 환불할 수 있어?',
      choices: const [
        Choice('어렵다', -7),
        Choice('애매', 0),
        Choice('쉽다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_15',
      group: 'base3_money',
      title: '굳이 지금 아니어도 나중에 사도 되는 거야?',
      choices: const [
        Choice('지금 아니면 안 된다', -7),
        Choice('애매', 0),
        Choice('나중에도 된다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_16',
      group: 'base3_money',
      title: '이걸 산다면, 다른 지출 하나는 포기할 각오가 돼 있어?',
      choices: const [
        Choice('포기 어렵다', -7),
        Choice('애매', 0),
        Choice('포기할 수 있다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_17',
      group: 'base3_money',
      title: '이거, 나 자신보다 남 시선이 더 신경 쓰여서 사고 싶은 건 아닐까?',
      choices: const [
        Choice('그런 것 같다', -7),
        Choice('애매', 0),
        Choice('아니다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_money_18',
      group: 'base3_money',
      title: '이건 기분만 잠깐 좋아지고 금방 시들 선택일까?',
      choices: const [
        Choice('그럴 것 같다', -7),
        Choice('애매', 0),
        Choice('아닐 것 같다', 7),
      ],
    ),


    // ===== base3_emotion (최종 리라이팅 반영본) =====

    JudgeQuestion(
      id: 'base3_emotion_01',
      group: 'base3_emotion',
      title: '지금 이 선택, 감정보다 이성으로 결정하고 있다고 느껴?',
      choices: const [
        Choice('아니다 (감정이 앞선다)', -6),
        Choice('애매', 0),
        Choice('그렇다 (이성적이다)', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_02',
      group: 'base3_emotion',
      title: '힘들어서 “이 정도는 보상 받아도 되지”라는 마음이 커진 건 아닐까?',
      choices: const [
        Choice('그런 마음이 크다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_03',
      group: 'base3_emotion',
      title: '이 행동이 끝난 뒤의 내 기분이 지금보다 나아질 것 같아?',
      choices: const [
        Choice('오히려 나빠질 것 같다', -6),
        Choice('애매', 0),
        Choice('나아질 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_04',
      group: 'base3_emotion',
      title: '지금 마음이 급한 상태에서 내려도 괜찮은 결정일까?',
      choices: const [
        Choice('괜찮지 않을 것 같다', -6),
        Choice('애매', 0),
        Choice('괜찮을 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_05',
      group: 'base3_emotion',
      title: '이 선택, 하기 싫은 걸 미루기 위한 도피에 가까운 것 같아?',
      choices: const [
        Choice('도피에 가깝다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_06',
      group: 'base3_emotion',
      title: '외로움이나 심심함을 달래려는 선택은 아닐까?',
      choices: const [
        Choice('그런 것 같다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_07',
      group: 'base3_emotion',
      title: '딱 5분만 쉬고 나서도, 여전히 이걸 하고 싶을까?',
      choices: const [
        Choice('아닐 것 같다', -6),
        Choice('애매', 0),
        Choice('그럴 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_08',
      group: 'base3_emotion',
      title: '이 행동이 나를 진정시켜 줄까, 아니면 잠깐 더 자극할 뿐일까?',
      choices: const [
        Choice('자극에 가깝다', -6),
        Choice('애매', 0),
        Choice('진정에 가깝다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_09',
      group: 'base3_emotion',
      title: '이미 마음 한편에 찜찜함이 있는데도 밀어붙이려는 건 아닐까?',
      choices: const [
        Choice('그렇다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_10',
      group: 'base3_emotion',
      title: '이걸 하고 나서 스스로에게 실망할 가능성은 없을까?',
      choices: const [
        Choice('그럴 것 같다', -6),
        Choice('애매', 0),
        Choice('아닐 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_11',
      group: 'base3_emotion',
      title: '이 선택은 나를 돌보는 쪽에 더 가까운 행동일까?',
      choices: const [
        Choice('아니다', -6),
        Choice('애매', 0),
        Choice('그렇다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_12',
      group: 'base3_emotion',
      title: '지금은 행동보다, 누군가의 위로나 연결이 더 필요한 상태일까?',
      choices: const [
        Choice('그렇다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_13',
      group: 'base3_emotion',
      title: '이 행동이 감정을 더 키워서 과몰입으로 이어질 가능성은 없을까?',
      choices: const [
        Choice('그럴 가능성 있다', -6),
        Choice('애매', 0),
        Choice('그렇지 않다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_14',
      group: 'base3_emotion',
      title: '지금은 밀어붙이기보다 잠깐 멈추는 게 더 나은 선택일까?',
      choices: const [
        Choice('멈추는 게 나을 것 같다', -6),
        Choice('애매', 0),
        Choice('계속해도 괜찮다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_15',
      group: 'base3_emotion',
      title: '내일의 내가 이 선택을 이해해 줄 수 있을까?',
      choices: const [
        Choice('이해 못 할 것 같다', -6),
        Choice('애매', 0),
        Choice('이해해 줄 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_17',
      group: 'base3_emotion',
      title: '지금 내 기분을 0~10으로 표현한다면, 꽤 낮은 편이야?',
      choices: const [
        Choice('많이 낮다 (0~4)', -6),
        Choice('애매 (5~7)', 0),
        Choice('괜찮은 편이다 (8~10)', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_emotion_18',
      group: 'base3_emotion',
      title: '이 행동 말고도, 지금 기분을 돌볼 다른 방법이 떠오를까?',
      choices: const [
        Choice('떠오른다', -6),
        Choice('애매', 0),
        Choice('안 떠오른다', 6),
      ],
    ),


    // ===== base3_risk (최종 리라이팅 반영본) =====

    JudgeQuestion(
      id: 'base3_risk_01',
      group: 'base3_risk',
      title: '최악의 경우를 한 문장으로 또렷하게 말할 수 있어?',
      choices: const [
        Choice('명확하다(리스크 큼)', -8),
        Choice('애매', 0),
        Choice('관리 가능하다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_02',
      group: 'base3_risk',
      title: '이 행동, 규칙이나 약속을 어길 소지가 있어?',
      choices: const [
        Choice('그렇다', -8),
        Choice('애매', 0),
        Choice('아니다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_03',
      group: 'base3_risk',
      title: '내 건강·수면·몸에 직접적인 데미지가 올 수 있어?',
      choices: const [
        Choice('그럴 수 있다', -8),
        Choice('애매', 0),
        Choice('그렇지 않다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_04',
      group: 'base3_risk',
      title: '이 행동, 되돌리기 어렵거나 복구 비용이 큰 편이야?',
      choices: const [
        Choice('그렇다(되돌리기 어려움)', -8),
        Choice('애매', 0),
        Choice('아니다(복구 쉬움)', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_05',
      group: 'base3_risk',
      title: '지금 결정이 계획이 아니라 충동에 더 가깝다고 느껴?',
      choices: const [
        Choice('충동에 가깝다', -8),
        Choice('애매', 0),
        Choice('계획에 가깝다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_06',
      group: 'base3_risk',
      title: '하다가 중간에 멈추면 문제가 커질 가능성이 있어?',
      choices: const [
        Choice('커질 수 있다', -8),
        Choice('애매', 0),
        Choice('그렇지 않다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_07',
      group: 'base3_risk',
      title: '이 행동이 사람이나 관계에 상처를 줄 위험이 있어?',
      choices: const [
        Choice('위험이 있다', -8),
        Choice('애매', 0),
        Choice('위험 없다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_08',
      group: 'base3_risk',
      title: '안전장치(제한/타이머/예산)를 걸기 어렵거나, 걸어도 안 지킬 것 같아?',
      choices: const [
        Choice('그럴 것 같다', -8),
        Choice('애매', 0),
        Choice('아니다(지킬 수 있다)', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_09',
      group: 'base3_risk',
      title: '리스크 대비 보상이 확실히 크다고 말할 수 있어?',
      choices: const [
        Choice('아니다(리스크가 더 큼)', -8),
        Choice('애매', 0),
        Choice('그렇다(보상 큼)', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_10',
      group: 'base3_risk',
      title: '내가 지금 리스크를 작게 보고 있을 가능성이 있어?',
      choices: const [
        Choice('그럴 가능성 있다', -8),
        Choice('애매', 0),
        Choice('그렇지 않다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_11',
      group: 'base3_risk',
      title: '이 행동이 다음 일정에 사고(지각·실수)를 부를 수 있어?',
      choices: const [
        Choice('그럴 수 있다', -8),
        Choice('애매', 0),
        Choice('그렇지 않다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_13',
      group: 'base3_risk',
      title: '이 행동, “한 번만” 하고 끝내기 어렵고 반복되기 쉬워?',
      choices: const [
        Choice('반복되기 쉽다', -8),
        Choice('애매', 0),
        Choice('한 번으로 끝낼 수 있다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_14',
      group: 'base3_risk',
      title: '내 기준선(원칙/선)을 넘는 선택일 수 있어?',
      choices: const [
        Choice('넘는 것 같다', -8),
        Choice('애매', 0),
        Choice('넘지 않는다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_15',
      group: 'base3_risk',
      title: '주변 사람이 보면 “그건 말려야 한다”라고 할 가능성이 높아?',
      choices: const [
        Choice('높다', -8),
        Choice('애매', 0),
        Choice('낮다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_16',
      group: 'base3_risk',
      title: '이 선택으로 손해가 생겨도 감당 가능하다고 확신해?',
      choices: const [
        Choice('확신 없다', -8),
        Choice('애매', 0),
        Choice('확신 있다', 8),
      ],
    ),

    JudgeQuestion(
      id: 'base3_risk_17',
      group: 'base3_risk',
      title: '작게 테스트(소규모로 안전하게)도 하기 어려운 선택이야?',
      choices: const [
        Choice('어렵다', -8),
        Choice('애매', 0),
        Choice('가능하다', 8),
      ],
    ),

    // ===== base3_routine (최종 리라이팅 반영본) =====

    JudgeQuestion(
      id: 'base3_routine_01',
      group: 'base3_routine',
      title: '이 선택이 내 루틴(수면/운동/공부/정리)을 지키는 쪽일까, 깨는 쪽일까?',
      choices: const [
        Choice('깨는 쪽에 가깝다', -6),
        Choice('애매', 0),
        Choice('지키는 쪽에 가깝다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_02',
      group: 'base3_routine',
      title: '오늘 최소한의 기본 루틴 한 가지는 이미 지켜졌을까?',
      choices: const [
        Choice('아직 못 지켰다', -6),
        Choice('애매', 0),
        Choice('이미 지켰다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_03',
      group: 'base3_routine',
      title: '이 행동 전에 1분 정도의 준비 루틴(정리/계획)을 붙일 수 있을까?',
      choices: const [
        Choice('붙이기 어렵다', -6),
        Choice('애매', 0),
        Choice('붙일 수 있다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_04',
      group: 'base3_routine',
      title: '이 행동 후에도 마무리 루틴(정리/기록)을 이어갈 여지가 있을까?',
      choices: const [
        Choice('여지 없다', -6),
        Choice('애매', 0),
        Choice('여지 있다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_05',
      group: 'base3_routine',
      title: '이 행동이 반복되면, 전반적인 생활 루틴이 더 좋아질까?',
      choices: const [
        Choice('오히려 흐트러질 것 같다', -6),
        Choice('애매', 0),
        Choice('더 좋아질 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_06',
      group: 'base3_routine',
      title: '지금처럼 루틴이 흔들릴 때, 이 선택이 질서를 되찾는 데 도움이 될까?',
      choices: const [
        Choice('도움 안 될 것 같다', -6),
        Choice('애매', 0),
        Choice('도움 될 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_07',
      group: 'base3_routine',
      title: '오늘 내가 지키고 싶은 “하나”에, 이 선택은 도움이 될까?',
      choices: const [
        Choice('도움 안 된다', -6),
        Choice('애매', 0),
        Choice('도움 된다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_08',
      group: 'base3_routine',
      title: '이 행동이 자기관리 루틴(식사/수면)과 충돌할 가능성이 있어?',
      choices: const [
        Choice('충돌할 것 같다', -6),
        Choice('애매', 0),
        Choice('충돌 안 할 것 같다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_09',
      group: 'base3_routine',
      title: '이 선택을 의식적으로 하고 있는 걸까, 습관처럼 자동으로 하고 있는 걸까?',
      choices: const [
        Choice('자동에 가깝다', -6),
        Choice('애매', 0),
        Choice('의식적인 선택이다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_10',
      group: 'base3_routine',
      title: '지금 이 선택 때문에 미루고 있는 핵심 루틴이 있을까?',
      choices: const [
        Choice('있다', -6),
        Choice('애매', 0),
        Choice('없다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_11',
      group: 'base3_routine',
      title: '이 행동은 루틴을 지지하는 보상일까, 루틴을 무너뜨리는 보상일까?',
      choices: const [
        Choice('무너뜨리는 보상', -6),
        Choice('애매', 0),
        Choice('지지하는 보상', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_12',
      group: 'base3_routine',
      title: '이 행동보다 먼저, 일정을 리셋하는 작은 행동이 필요하지 않을까?',
      choices: const [
        Choice('그럴 것 같다', -6),
        Choice('애매', 0),
        Choice('아니다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_13',
      group: 'base3_routine',
      title: '이 행동 뒤에 바로 이어질 작은 루틴을 붙일 수 있을까?',
      choices: const [
        Choice('붙이기 어렵다', -6),
        Choice('애매', 0),
        Choice('붙일 수 있다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_14',
      group: 'base3_routine',
      title: '오늘 루틴 점수(0~10)로 보면, 이 선택은 플러스일까 마이너스일까?',
      choices: const [
        Choice('마이너스에 가깝다', -6),
        Choice('애매', 0),
        Choice('플러스에 가깝다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_15',
      group: 'base3_routine',
      title: '이 반복은 나를 조금씩 성장시키는 쪽일까, 소모시키는 쪽일까?',
      choices: const [
        Choice('소모에 가깝다', -6),
        Choice('애매', 0),
        Choice('성장에 가깝다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_16',
      group: 'base3_routine',
      title: '이 선택이 내가 나에게 한 약속을 흔들 가능성은 없을까?',
      choices: const [
        Choice('그럴 가능성 있다', -6),
        Choice('애매', 0),
        Choice('그렇지 않다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_17',
      group: 'base3_routine',
      title: '이 행동을 미니 버전으로 바꿔도 루틴을 유지할 수 있을까?',
      choices: const [
        Choice('유지 어렵다', -6),
        Choice('애매', 0),
        Choice('유지 가능하다', 6),
      ],
    ),

    JudgeQuestion(
      id: 'base3_routine_18',
      group: 'base3_routine',
      title: '이 행동을 기록까지 이어가면, 루틴으로 남길 수 있을까?',
      choices: const [
        Choice('어렵다', -6),
        Choice('애매', 0),
        Choice('가능하다', 6),
      ],
    ),


    // ===== base3_goal (최종 리라이팅 반영본) =====

    JudgeQuestion(
      id: 'base3_goal_01',
      group: 'base3_goal',
      title: '이 선택이 장기 목표(커리어/건강/재정)에 실제로 도움이 될까?',
      choices: const [
        Choice('목표와 어긋난다', -7),
        Choice('애매', 0),
        Choice('목표에 도움이 된다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_02',
      group: 'base3_goal',
      title: '‘미래의 나’가 돌아봤을 때 고마워할 선택일까?',
      choices: const [
        Choice('아닐 것 같다', -7),
        Choice('애매', 0),
        Choice('그럴 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_03',
      group: 'base3_goal',
      title: '일주일 뒤에 다시 봐도 의미 있다고 느낄 선택일까?',
      choices: const [
        Choice('의미 없을 것 같다', -7),
        Choice('애매', 0),
        Choice('의미 있을 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_04',
      group: 'base3_goal',
      title: '이 선택이 지금 내가 가려는 방향과 잘 맞을까?',
      choices: const [
        Choice('맞지 않는다', -7),
        Choice('애매', 0),
        Choice('잘 맞는다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_05',
      group: 'base3_goal',
      title: '이걸 하면 목표에 가까워지는 행동을 하나 포기하게 될까?',
      choices: const [
        Choice(';포기하게 될 것 같다', -7),
        Choice('애매', 0),
        Choice('그렇지 않을 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_06',
      group: 'base3_goal',
      title: '이 선택이 내가 되고 싶은 사람(정체성)과 어울릴까?',
      choices: const [
        Choice('어울리지 않는다', -7),
        Choice('애매', 0),
        Choice('잘 어울린다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_07',
      group: 'base3_goal',
      title: '이건 단기 쾌감에 더 가깝나, 장기 성과에 더 가깝나?',
      choices: const [
        Choice('단기 쾌감에 가깝다', -7),
        Choice('애매', 0),
        Choice('장기 성과에 가깝다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_08',
      group: 'base3_goal',
      title: '장기적으로 시간/돈/건강 비용이 커질 가능성이 있을까?',
      choices: const [
        Choice('그럴 가능성 크다', -7),
        Choice('애매', 0),
        Choice('그렇지 않다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_09',
      group: 'base3_goal',
      title: '이 행동이 ‘좋은 방향의 작은 습관’으로 이어질 가능성이 있을까?',
      choices: const [
        Choice('가능성 낮다', -7),
        Choice('애매', 0),
        Choice('가능성 있다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_11',
      group: 'base3_goal',
      title: '이 행동 뒤에 목표로 이어지는 ‘다음 한 걸음’을 연결할 수 있을까?',
      choices: const [
        Choice('연결하기 어렵다', -7),
        Choice('애매', 0),
        Choice('연결할 수 있다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_12',
      group: 'base3_goal',
      title: '이 선택이 내 가치(가족/성장/자유 등)와 충돌하지 않을까?',
      choices: const [
        Choice('충돌할 것 같다', -7),
        Choice('애매', 0),
        Choice('충돌하지 않는다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_13',
      group: 'base3_goal',
      title: '이 선택이 평판/신뢰를 쌓는 쪽에 더 가까울까?',
      choices: const [
        Choice('아니다', -7),
        Choice('애매', 0),
        Choice('그렇다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_14',
      group: 'base3_goal',
      title: '이 행동이 나를 분산시키나, 목표에 더 집중하게 하나?',
      choices: const [
        Choice('분산시키는 편이다', -7),
        Choice('애매', 0),
        Choice('집중하게 하는 편이다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_15',
      group: 'base3_goal',
      title: '오늘의 선택이 1년 누적되면, 나는 목표에 더 가까워질까?',
      choices: const [
        Choice('아닐 것 같다', -7),
        Choice('애매', 0),
        Choice('그럴 것 같다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_17',
      group: 'base3_goal',
      title: '이 행동을 목표에 맞게 ‘작게/깊게’ 조정해서 도움이 되게 만들 수 있을까?',
      choices: const [
        Choice('조정하기 어렵다', -7),
        Choice('애매', 0),
        Choice('조정할 수 있다', 7),
      ],
    ),

    JudgeQuestion(
      id: 'base3_goal_18',
      group: 'base3_goal',
      title: '이 행동을 하더라도 목표를 지키는 안전장치를 넣을 수 있을까?',
      choices: const [
        Choice('넣기 어렵다', -7),
        Choice('애매', 0),
        Choice('넣을 수 있다', 7),
      ],
    ),
  ];


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
        id: 'buy_tomorrow',
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
          Choice('스트레스/도피', -10),
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
          Choice('현실 도피 느낌', -8),
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

  // ✅ 카페인 전용 (2개는 '고정 슬롯' + 각 슬롯 랜덤 / 밤엔 수면 강제 / 조합수 125+)
  if (action == '카페인') {
    final hour = DateTime
        .now()
        .hour;
    final isNight = hour >= 22 || hour < 5;

    // ✅ 하루 동안 조합이 너무 들쑥날쑥 바뀌지 않게(하루 seed)
    final now = DateTime.now();
    final seed = (now.year * 10000 + now.month * 100 + now.day) ^ action
        .hashCode;
    final rnd = Random(seed);

    // 카페인은 카페인 질문만(엉뚱함 방지)
    actionSpecific.clear();

    // ===== 슬롯 A: 상태/이유 (5개) =====
    final slotA = <JudgeQuestion>[
      JudgeQuestion(
        id: 'caffeine_need_work',
        group: 'caffeine_need_work',
        title: '카페인을 마시는 이유는 뭐에 더 가까워?',
        choices: const [
          Choice('집중/업무', 2),
          Choice('기분전환', 0),
          Choice('습관/무의식', -2),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_energy',
        group: 'caffeine_energy',
        title: '지금 피곤함은 “잠”이 필요한 수준이야?',
        choices: const [
          Choice('아니야, 각성만 필요', 2),
          Choice('애매', 0),
          Choice('맞아, 잠이 필요', -4),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_stress',
        group: 'caffeine_stress',
        title: '지금은 스트레스/불안 때문에 찾는 거야?',
        choices: const [
          Choice('아니', 2),
          Choice('반반', 0),
          Choice('그런 편', -3),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_habit_trigger',
        group: 'caffeine_habit_trigger',
        title: '지금 상황이 “습관적으로 커피를 찾게 되는 타이밍”이야?',
        choices: const [
          Choice('아니', 2),
          Choice('조금', 0),
          Choice('맞아', -3),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_focus_window',
        group: 'caffeine_focus_window',
        title: '지금 진짜로 “집중이 필요한 1~2시간”이 남아있어?',
        choices: const [
          Choice('응, 필요해', 2),
          Choice('애매', 0),
          Choice('아니, 그냥 버티기', -3),
        ],
        tags: [action],
      ),
    ];

    // ===== 슬롯 B: 양/조절 (5개) =====
    final slotB = <JudgeQuestion>[
      JudgeQuestion(
        id: 'caffeine_amount',
        group: 'caffeine_amount',
        title: '양은 어느 정도로 생각해?',
        choices: const [
          Choice('적당히(1잔)', 2),
          Choice('조금 많음(2잔)', -4),
          Choice('많이(3잔 이상)', -10),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_cut',
        group: 'caffeine_cut',
        title: '양을 줄이거나 디카페인으로 바꾸는 건 가능해?',
        choices: const [
          Choice('가능', 4),
          Choice('애매', 0),
          Choice('어려워', -3),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_limit',
        group: 'caffeine_limit',
        title: '오늘 “여기까지만”이라는 상한을 지킬 수 있어?',
        choices: const [
          Choice('지킬 수 있어', 4),
          Choice('애매', 0),
          Choice('못 지킬 듯', -5),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_small_size',
        group: 'caffeine_small_size',
        title: '사이즈를 “작은 걸로” 낮추면 만족할 수 있어?',
        choices: const [
          Choice('가능', 3),
          Choice('애매', 0),
          Choice('어려워', -2),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_one_rule',
        group: 'caffeine_one_rule',
        title: '오늘은 “이번 한 번만” 규칙으로 끝낼 자신 있어?',
        choices: const [
          Choice('있어', 3),
          Choice('애매', 0),
          Choice('없어', -4),
        ],
        tags: [action],
      ),
    ];

    // ===== 슬롯 C: 상황/대안 (5개) =====
    final slotC = <JudgeQuestion>[
      JudgeQuestion(
        id: 'caffeine_time',
        group: 'caffeine_time',
        title: '지금 시간대에 카페인 선택이 괜찮을까?',
        choices: const [
          Choice('이른 편(오전/점심)', 3),
          Choice('보통(오후)', 0),
          Choice('늦은 편(저녁)', -4),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_alt',
        group: 'caffeine_alt',
        title: '카페인 말고 대체가 가능해?',
        choices: const [
          Choice('물/간식/바람 쐬기', 2),
          Choice('잠깐 눈 붙이기', 4),
          Choice('대체 없음', 0),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_water',
        group: 'caffeine_water',
        title: '카페인 전에 물 한 컵부터 해볼 수 있어?',
        choices: const [
          Choice('가능', 3),
          Choice('애매', 0),
          Choice('어려워', -2),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_walk',
        group: 'caffeine_walk',
        title: '5분만 걷거나 바람 쐬면 지금 상태가 나아질까?',
        choices: const [
          Choice('그럴 것 같아', 3),
          Choice('애매', 0),
          Choice('아니', -1),
        ],
        tags: [action],
      ),
      JudgeQuestion(
        id: 'caffeine_food',
        group: 'caffeine_food',
        title: '배고픔/탈수 때문에 피곤한 걸 수도 있어. 간단히 먹거나 마실 수 있어?',
        choices: const [
          Choice('가능', 3),
          Choice('애매', 0),
          Choice('어려워', -1),
        ],
        tags: [action],
      ),
    ];

    // 🌙 밤엔 무조건 수면 질문(3번째)
    final sleepQ = JudgeQuestion(
      id: 'caffeine_sleep',
      group: 'caffeine_sleep',
      title: '오늘 잠드는 시간이 얼마나 남았어?',
      choices: const [
        Choice('8시간 이상', 2),
        Choice('4~8시간', -2),
        Choice('4시간 이내', -8),
      ],
      tags: [action],
    );

    JudgeQuestion pickFrom(List<JudgeQuestion> list) =>
        list[rnd.nextInt(list.length)];

    final q1 = pickFrom(slotA);
    final q2 = pickFrom(slotB);
    final q3 = isNight ? sleepQ : pickFrom(slotC);

    actionSpecific.addAll([q1, q2, q3]);
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
  // (위에서 계산한 tag 재사용)

  // ✅ 태그 판정 (필터/난이도 조절용)
  //  - semiQuestions()도 내부에서 inferSemiTag를 쓰지만,
  //    여기서는 "기본/추가 질문 풀"을 줄이기 위해 한번 더 계산.
  final tag = inferSemiTag(action, kind);

  // ✅ '가벼운 행동'은 무거운 질문을 최대한 빼서 톤을 가볍게 유지
  // - 휴식/청소는 기본적으로 라이트
  // - 유튜브/스크린도 neutral이면 라이트로 취급 (짧은 휴식 느낌)
  final isLight = (tag == 'rest' || tag == 'clean' ||
      (tag == 'screen' && kind == ActionKind.neutral));

  // ✅ 무거운 질문(감정/리스크)은 "진짜 위험도가 있는 상황"에만
  const heavyTags = <String>{
    'spend',
    'purchase',
    'alcohol',
    'smoke',
    'binge',
    'game'
  };
  final allowHeavy = (kind == ActionKind.bad) || heavyTags.contains(tag);

  // ✅ 돈 질문은 구매/지출에서만
  final allowMoney = (tag == 'spend' || tag == 'purchase');

  // --------------------------
  // 1) base(공통 기본) 질문 수 줄이기: "심문" 느낌 방지
  // --------------------------
  // - 항상 나오는 코어 3~4개 + 상태 1~2개 + 맥락 1개
  final rng = Random(now.millisecondsSinceEpoch ^ action.hashCode);

  List<JudgeQuestion> _pickUniqueByGroup(List<JudgeQuestion> src,
      int maxCount, {
        Set<String>? usedGroups,
        Set<String>? blockGroups,
      }) {
    final out = <JudgeQuestion>[];
    final used = usedGroups ?? <String>{};
    final block = blockGroups ?? <String>{};

    final shuffled = [...src]..shuffle(rng);
    for (final q in shuffled) {
      if (out.length >= maxCount) break;
      if (block.contains(q.group)) continue;
      if (q.group.isNotEmpty && used.contains(q.group)) continue;
      out.add(q);
      if (q.group.isNotEmpty) used.add(q.group);
    }
    return out;
  }

  final baseAlwaysIds = isLight
      ? <String>{'timebox', 'after', 'control'}
      : <String>{'goal', 'timebox', 'after', 'control'};
  final baseAlways = base.where((q) => baseAlwaysIds.contains(q.id)).toList();

  final baseStatePool = base.where((q) =>
  q.group == 'base_state' && !baseAlwaysIds.contains(q.id)).toList();

  // base_state 외에서 "한 개만" 더 뽑기 (내일/수면/집중/루틴/우선순위 등)
  final baseContextPool = base
      .where((q) => q.group != 'base_state' && !baseAlwaysIds.contains(q.id))
      .toList();

  final statePickCount = allowHeavy ? 2 : 1;
  final pickedState = _pickUniqueByGroup(baseStatePool, statePickCount);
  final pickedContext = _pickUniqueByGroup(
      baseContextPool, 1, usedGroups: {for (final q in pickedState) q.group});

  final basePicked = [...baseAlways, ...pickedState, ...pickedContext];

  // --------------------------
  // 2) extraBase(확장 질문) 필터링 + 개수 제한
  // --------------------------
  var extraBaseFiltered = extraBase;

  // (a) 돈 관련은 구매/지출만 허용
  if (!allowMoney) {
    extraBaseFiltered =
        extraBaseFiltered.where((q) => q.group != 'base3_money').toList();
  }

  // (b) 감정/리스크 질문은 위험도가 있는 상황에만
  if (!allowHeavy) {
    const heavyBlockGroups = <String>{'base3_emotion', 'base3_risk'};
    extraBaseFiltered =
        extraBaseFiltered
            .where((q) => !heavyBlockGroups.contains(q.group))
            .toList();
  }

  // (c) 휴식/청소(라이트)는 목표/리스크/돈/감정까지 최대한 제외
  if (isLight) {
    const lightBlockGroups = <String>{
      'base3_goal',
      'base3_risk',
      'base3_money',
      'base3_emotion',
    };
    extraBaseFiltered =
        extraBaseFiltered
            .where((q) => !lightBlockGroups.contains(q.group))
            .toList();
  }

  // (d) 라이트는 1개, 일반은 2개, 위험 상황은 3개 정도만 랜덤 선택
  final extraPickCount = isLight ? 1 : (allowHeavy ? 3 : 2);
  final pickedExtra = _pickUniqueByGroup(extraBaseFiltered, extraPickCount);

  // ✅ 최종 풀 반환 (기본 줄이고, 추가도 랜덤으로 제한)
  return [...basePicked, ...kindSet, ...pickedExtra, ...actionSpecific];
}
