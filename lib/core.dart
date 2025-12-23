import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// =======================
/// 공용 모델/유틸
/// =======================
enum ActionKind { good, bad, neutral }

class ActionDef {
  final String name;
  final ActionKind kind;
  final IconData icon;

  const ActionDef({
    required this.name,
    required this.kind,
    required this.icon,
  });
}

String nowHHmm() {
  final now = TimeOfDay.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

String hhmmFrom(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime dt) => isSameDay(dt, DateTime.now());

bool isYesterday(DateTime dt) {
  final y = DateTime.now().subtract(const Duration(days: 1));
  return isSameDay(dt, y);
}

String badgeForKind(ActionKind kind) {
  switch (kind) {
    case ActionKind.good:
      return 'GOOD';
    case ActionKind.bad:
      return 'BAD';
    case ActionKind.neutral:
      return 'NEUTRAL';
  }
}

ActionDef? findDefByName(List<ActionDef> defs, String name) {
  for (final d in defs) {
    if (d.name == name) return d;
  }
  return null;
}

/// ✅ EXP 계산 (최종 설계 반영)
/// - 기본: BAD 2 / NEUTRAL 4 / GOOD 6
/// - 자기관리: 기본(6) + 시간보너스(15=2,30=3,60=5,90=7,120=10)
///   - 직접입력: 가장 가까운 프리셋 보너스
///   - 직접입력 120분 이상: 시간보너스 +12
int expForLog({
  required String action,
  required ActionKind kind,
  int? minutes,
  bool isCustomMinutes = false, // ✅ 직접입력 여부
  String? purchaseType,
}) {
  // ✅ 기본 EXP
  int base;
  switch (kind) {
    case ActionKind.good:
      base = 6;
      break;
    case ActionKind.bad:
      base = 2;
      break;
    case ActionKind.neutral:
      base = 4;
      break;
  }

  // ✅ 자기관리: 기본 + 시간보너스(합산)
  if (action == '자기관리') {
    final m = (minutes ?? 30);

    int timeBonus;

    // 직접입력 + 120분 이상이면 시간보너스 12로 고정(맥시멈)
    if (isCustomMinutes && m >= 120) {
      timeBonus = 12;
    } else {
      // ✅ 근사치는 "가장 가까운 프리셋"으로
      const presets = [15, 30, 60, 90, 120];
      int nearest = presets.first;
      int bestDiff = (m - nearest).abs();

      for (final p in presets) {
        final d = (m - p).abs();
        if (d < bestDiff) {
          bestDiff = d;
          nearest = p;
        }
      }

      switch (nearest) {
        case 15:
          timeBonus = 2;
          break;
        case 30:
          timeBonus = 3;
          break;
        case 60:
          timeBonus = 5;
          break;
        case 90:
          timeBonus = 7;
          break;
        case 120:
          timeBonus = 10;
          break;
        default:
          timeBonus = 3;
      }
    }

    return base + timeBonus;
  }

  // 구매: 상황에 따라 (원하면 여기 더 세분화 가능)
  if (action == '구매') {
    switch (purchaseType) {
      case '꼭 필요한 구매':
      case '계획된 소비':
        return 6;
      case '선물':
        return 5;
      case '이벤트/여행':
        return 4;
      case '스트레스':
        return 3;
      case '스트레스':
        return 2;
      default:
        return base;
    }
  }

  return base;
}

String detailTextForSnack({
  required String action,
  String? subtype,
  int? minutes,
  String? purchaseType,
}) {
  if (action == '자기관리') {
    final s = subtype ?? '기타';
    final m = minutes ?? 30;
    return '$action ($s ${m}분)';
  }
  if (action == '구매') {
    final p = purchaseType ?? '';
    return p.isEmpty ? action : '$action ($p)';
  }
  return action;
}

/// =======================
/// 다이얼로그들 (overflow 종결 버전)
/// =======================
class SelfCareResult {
  final String subtype;
  final int minutes;
  final bool isCustom;

  SelfCareResult({
    required this.subtype,
    required this.minutes,
    required this.isCustom,
  });
}

Future<SelfCareResult?> showSelfCareDialog(BuildContext context) async {
  const subtypes = ['운동', '공부', '독서', '정리', '스트레칭', '기타'];
  const presetMinutes = [15, 30, 60, 90, 120];

  final customCtrl = TextEditingController();

  return showDialog<SelfCareResult>(
    context: context,
    builder: (ctx) {
      String subtype = subtypes.first;
      int minutes = 30;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final mq = MediaQuery.of(ctx);
          final cs = Theme.of(ctx).colorScheme;

          final availableH = mq.size.height - mq.viewInsets.bottom - 48;
          final maxH = availableH.clamp(240.0, mq.size.height * 0.85);

          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom) +
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mq.size.width - 32, maxHeight: maxH),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '자기관리 기록',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx, null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: subtype,
                                  items: subtypes
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) => setState(() => subtype = v ?? subtype),
                                  decoration: const InputDecoration(labelText: '세부유형'),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: minutes,
                                  items: presetMinutes
                                      .map((m) => DropdownMenuItem(value: m, child: Text('${m}분')))
                                      .toList(),
                                  onChanged: (v) => setState(() => minutes = v ?? minutes),
                                  decoration: const InputDecoration(labelText: '시간(프리셋)'),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: customCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '직접 입력(분) — 비우면 프리셋 사용',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text('※ 직접입력 120분 이상이면 시간보너스는 +12 (보너스 맥시멈)'),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    final txt = customCtrl.text.trim();
                                    final custom = int.tryParse(txt);
                                    final bool isCustom = (custom != null && custom > 0);
                                    final int finalMinutes = isCustom ? custom! : minutes;

                                    Navigator.pop(
                                      ctx,
                                      SelfCareResult(
                                        subtype: subtype,
                                        minutes: finalMinutes,
                                        isCustom: isCustom,
                                      ),
                                    );
                                  },
                                  child: const Text('저장'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showPurchaseDialog(BuildContext context) async {
  const items = ['충동구매', '꼭 필요한 구매', '선물', '이벤트/여행', '스트레스', '계획된 소비'];

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String selected = items.first;

      return StatefulBuilder(
        builder: (ctx, setState) {
          final mq = MediaQuery.of(ctx);
          final cs = Theme.of(ctx).colorScheme;

          final availableH = mq.size.height - mq.viewInsets.bottom - 48;
          final maxH = availableH.clamp(220.0, mq.size.height * 0.75);

          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom) +
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mq.size.width - 32, maxHeight: maxH),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '구매 기록',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx, null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: DropdownButtonFormField<String>(
                              value: selected,
                              items: items
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => selected = v ?? selected),
                              decoration: const InputDecoration(labelText: '구매 상황'),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => Navigator.pop(ctx, selected),
                                  child: const Text('저장'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<ActionDef?> showAddActionDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  ActionKind kind = ActionKind.neutral;

  final icons = <IconData>[
    // 기본
    Icons.check_circle_outline,

    // 🧠 자기관리 / 성장
    Icons.self_improvement,
    Icons.school_outlined,
    Icons.book_outlined,
    Icons.menu_book,
    Icons.cleaning_services_outlined,
    Icons.directions_run,
    Icons.spa,

    // 🎮 여가 / 휴식
    Icons.music_note_outlined,
    Icons.movie_outlined,
    Icons.sports_esports_outlined,
    Icons.videogame_asset_outlined,
    Icons.tv_outlined,
    Icons.nightlight_outlined,

    // 💸 소비 / 일상
    Icons.restaurant_outlined,
    Icons.shopping_cart_outlined,
    Icons.receipt_long,
    Icons.card_giftcard,
    Icons.attach_money,

    // ⚠️ 유혹 / 컨트롤
    Icons.phone_android,
    Icons.coffee,
    Icons.fastfood,
    Icons.local_bar,
    Icons.bolt,
  ];


  IconData selectedIcon = icons.first;

  return showDialog<ActionDef>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final mq = MediaQuery.of(ctx);
          final cs = Theme.of(ctx).colorScheme;

          final availableH = mq.size.height - mq.viewInsets.bottom - 48;
          final maxH = availableH.clamp(260.0, mq.size.height * 0.90);

          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom) +
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: mq.size.width - 32,
                    maxHeight: maxH,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '행동 추가',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx, null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                              children: [
                                TextField(
                                  controller: nameCtrl,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 5,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: '행동 이름 (예: 독서, 산책, 명상)',
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ActionKind>(
                                  value: kind,
                                  items: const [
                                    DropdownMenuItem(
                                        value: ActionKind.good, child: Text('GOOD (좋은 행동)')),
                                    DropdownMenuItem(
                                        value: ActionKind.bad, child: Text('BAD (줄이면 좋은 행동)')),
                                    DropdownMenuItem(
                                        value: ActionKind.neutral, child: Text('NEUTRAL (중립)')),
                                  ],
                                  onChanged: (v) => setState(() => kind = v ?? kind),
                                  decoration: const InputDecoration(labelText: '성격'),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('아이콘', style: Theme.of(ctx).textTheme.labelLarge),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: icons.map((ic) {
                                      final isOn = ic == selectedIcon;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => setState(() => selectedIcon = ic),
                                        child: Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            color: isOn ? cs.primary.withOpacity(0.12) : cs.surface,
                                            border: Border.all(
                                              color: isOn
                                                  ? cs.primary.withOpacity(0.45)
                                                  : cs.outlineVariant.withOpacity(0.55),
                                            ),
                                          ),
                                          child: Icon(ic),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '추가할 행동의 이름, 성격, 아이콘을 설정하고 추가를 누르세요',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                                ),

                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    final name = nameCtrl.text.trim();
                                    if (name.isEmpty) return;
                                    Navigator.pop(
                                      ctx,
                                      ActionDef(name: name, kind: kind, icon: selectedIcon),
                                    );
                                  },
                                  child: const Text('추가'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// =======================
/// 로그 아이템 (공용 모델)
/// =======================
class LogItem {
  final int? id; // ✅ DB row id (삭제/동기화용)

  final String action;
  final String time;
  final DateTime at;
  final String? subtype;
  final int? minutes;
  final String? purchaseType;

  // ✅ 이 기록으로 실제로 적용된 EXP(하루 40 캡 반영 후)
  final int expGained;

  LogItem({
    this.id, // ✅ 추가
    required this.action,
    required this.time,
    required this.at,
    this.subtype,
    this.minutes,
    this.purchaseType,
    required this.expGained,
  });

  List<String> chips() {
    final c = <String>[];
    if (subtype != null) c.add(subtype!);
    if (minutes != null) c.add('${minutes}분');
    if (purchaseType != null) c.add(purchaseType!);
    return c;
  }
}

// ===============================
// 🎮 Level / EXP System (9 Levels)
// ===============================

class LevelDef {
  final int level;
  final String name;
  final int needExp; // 이전 레벨에서 다음 레벨까지 필요한 EXP

  const LevelDef({
    required this.level,
    required this.name,
    required this.needExp,
  });
}

/// 레벨 정의 (Lv1 ~ Lv9)
const List<LevelDef> kLevels = [
  LevelDef(level: 1, name: '방황 중', needExp: 80),
  LevelDef(level: 2, name: '관리 시작', needExp: 200),
  LevelDef(level: 3, name: '루틴 형성', needExp: 400),
  LevelDef(level: 4, name: '루틴 실천자', needExp: 700),
  LevelDef(level: 5, name: '루틴 마스터', needExp: 1100),
  LevelDef(level: 6, name: '갓생 예비', needExp: 1600),
  LevelDef(level: 7, name: '갓생 실천자', needExp: 2300),
  LevelDef(level: 8, name: '갓생 루틴화', needExp: 3100),
  // Lv9는 최종 단계 (다음 레벨 없음)
  LevelDef(level: 9, name: '갓생 마스터', needExp: 0),
];

/// 계산 결과 모델
class LevelProgress {
  final int level;
  final String name;
  final double percent;      // 0.0 ~ 1.0
  final int remainToNext;    // 다음 레벨까지 남은 EXP

  const LevelProgress({
    required this.level,
    required this.name,
    required this.percent,
    required this.remainToNext,
  });
}

/// 누적 EXP → 현재 레벨 / 퍼센트 / 남은 EXP 계산
LevelProgress calcLevelProgress(int totalExp) {
  int acc = 0;

  for (int i = 0; i < kLevels.length; i++) {
    final cur = kLevels[i];

    // 마지막 레벨
    if (cur.needExp == 0) {
      return LevelProgress(
        level: cur.level,
        name: cur.name,
        percent: 1.0,
        remainToNext: 0,
      );
    }

    final nextAcc = acc + cur.needExp;

    if (totalExp < nextAcc) {
      final gainedInLevel = totalExp - acc;
      final percent = gainedInLevel / cur.needExp;
      final remain = cur.needExp - gainedInLevel;

      return LevelProgress(
        level: cur.level,
        name: cur.name,
        percent: percent.clamp(0.0, 1.0),
        remainToNext: remain,
      );
    }

    acc = nextAcc;
  }

  // 안전장치 (이론상 도달 안 함)
  final last = kLevels.last;
  return LevelProgress(
    level: last.level,
    name: last.name,
    percent: 1.0,
    remainToNext: 0,
  );
}
// =====================================================
// Rewarded Ad Gate (광고 → 보상 → AI 허용)
// =====================================================
/*class RewardedGate {
  RewardedAd? _ad;
  bool _loading = false;

  bool get isLoaded => _ad != null;

  // ✅ 테스트용 리워드 광고 ID (Android)
  // 배포 전에 반드시 본인 AdMob 리워드 광고 단위 ID로 교체!
  static const String _testUnitAndroid = 'ca-app-pub-3940256099942544/5224354917';

  String get _unitId {
    if (Platform.isAndroid) return _testUnitAndroid;
    // iOS 테스트 ID도 필요하면 추가
    return _testUnitAndroid;
  }

  Future<void> load() async {
    if (_loading || _ad != null) return;
    _loading = true;

    await RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (err) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  Future<void> showAndEarn({required VoidCallback onEarned}) async {
    final ad = _ad;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        load(); // 다음을 위해 다시 로드
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _ad = null;
        load();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      onEarned();
    });
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

// =====================================================
// AI 사용 횟수 제한 (로컬, 하루 3회)
// =====================================================
class AiQuota {
  static const _kDate = 'ai_quota_date';
  static const _kUsed = 'ai_quota_used';
  static const int dailyMax = 3;

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Future<int> _getUsedToday(SharedPreferences sp) async {
    final today = _todayKey();
    final savedDate = sp.getString(_kDate);

    if (savedDate != today) {
      await sp.setString(_kDate, today);
      await sp.setInt(_kUsed, 0);
      return 0;
    }
    return sp.getInt(_kUsed) ?? 0;
  }

  static Future<bool> canUse() async {
    final sp = await SharedPreferences.getInstance();
    final used = await _getUsedToday(sp);
    return used < dailyMax;
  }

  static Future<void> consumeOnce() async {
    final sp = await SharedPreferences.getInstance();
    final used = await _getUsedToday(sp);
    await sp.setInt(_kUsed, (used + 1).clamp(0, dailyMax));
  }

  static Future<int> remaining() async {
    final sp = await SharedPreferences.getInstance();
    final used = await _getUsedToday(sp);
    return (dailyMax - used).clamp(0, dailyMax);
  }
}

// =====================================================
// (임시) AI 설명 텍스트 생성
// - 지금은 “진짜 AI 호출” 없이도 동작하도록 템플릿만 반환
// - 나중에 OpenAI 붙일 때 여기만 교체하면 됨
// =====================================================
Future<String> buildAiExplainText({
  required String actionName,
  required Set<String> tags,
  required String baseReason1,
  required String baseReason2,
}) async {
  final tagText = tags.isEmpty ? '' : ' (${tags.join(', ')})';

  // 2~4문장 “짧은 설명” 정책
  return [
    '지금 “$actionName”은$tagText 애매한 케이스라서, 금지보단 “강도 조절”이 핵심이에요.',
    baseReason1,
    baseReason2,
    '딱 하나만 정하면 좋아요: “얼마나/어디까지 할지”를 짧게 제한하기.',
  ].join('\n');
}
*/