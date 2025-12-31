import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core.dart';

/// =======================
/// 1) 기록 탭
/// =======================
class LogTab extends StatefulWidget {
  final List<ActionDef> actions;
  final List<LogItem> timeline;
  final int todayExp;
  final int dailyMax;

  // ✅ 누적 EXP(레벨/퍼센트용)
  final int totalExp;

  final void Function({
  required String action,
  String? subtype,
  int? minutes,
  bool isCustomMinutes,
  String? purchaseType,
  }) onAddLog;

  final void Function(int index) onDeleteAt;

  // ✅ (추가) 수정
  final void Function(int index) onEditAt;

  final void Function(ActionDef def) onAddAction;
  final void Function(String name) onRemoveActionByName;
  final bool Function(String name) isBaseName;

  const LogTab({
    super.key,
    required this.actions,
    required this.timeline,
    required this.todayExp,
    required this.dailyMax,
    required this.totalExp,
    required this.onAddLog,
    required this.onDeleteAt,
    required this.onEditAt, // ✅ 추가
    required this.onAddAction,
    required this.onRemoveActionByName,
    required this.isBaseName,
  });

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  int _lastLevel = 1;

  @override
  void initState() {
    super.initState();
    _lastLevel = calcLevelProgress(widget.totalExp).level;
  }

  @override
  void didUpdateWidget(covariant LogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted) return; // 🔧 이 줄 추가

    // totalExp가 바뀌었을 때만 체크
    if (oldWidget.totalExp == widget.totalExp) return;

    final oldLevel = calcLevelProgress(oldWidget.totalExp).level;
    final newLp = calcLevelProgress(widget.totalExp);

    // 🔥 레벨업 감지
    if (newLp.level > oldLevel && newLp.level != _lastLevel) {
      _lastLevel = newLp.level;

      // build 중 dialog 호출 방지
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLevelUpDialog(level: newLp.level, name: newLp.name);
      });
    }
  }

  Future<bool> _confirmDidItSheet({
    required String title,
  }) async {
    HapticFeedback.mediumImpact();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final bottomSafe = MediaQuery.of(ctx).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomSafe),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
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
                          child: const Text('저장'),
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

    return ok == true;
  }

  Future<void> _confirmDeleteAction(String name) async {
    HapticFeedback.mediumImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('행동 삭제'),
        content: Text('“$name” 행동을 정말 삭제하시겠습니까?\n(해당 행동의 기록도 함께 제거됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );

    if (ok == true) widget.onRemoveActionByName(name);
  }

  Future<bool> _confirmDeleteLog() async {
    HapticFeedback.mediumImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );

    return ok == true;
  }
  Future<void> _showLevelUpDialog({
    required int level,
    required String name,
  }) async {
    HapticFeedback.heavyImpact();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('레벨 업! 🎉'),
          content: Text('축하해요!\nLv $level · $name 달성!'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('좋아!'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final todayIdx = <int>[];
    final yestIdx = <int>[];
    for (int i = 0; i < widget.timeline.length; i++) {
      final at = widget.timeline[i].at;
      if (isToday(at)) todayIdx.add(i);
      if (isYesterday(at)) yestIdx.add(i);
    }

    ActionKind kindOf(LogItem l) {
      final def = findDefByName(widget.actions, l.action);
      return def?.kind ?? ActionKind.neutral;
    }

    final todayTotal = todayIdx.length;
    final todayGood = todayIdx.where((i) => kindOf(widget.timeline[i]) == ActionKind.good).length;
    final todayBad = todayIdx.where((i) => kindOf(widget.timeline[i]) == ActionKind.bad).length;
    final todayNeutral =
        todayIdx.where((i) => kindOf(widget.timeline[i]) == ActionKind.neutral).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: cs.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('오늘 하루를 기록하세요'),
          ],
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(
                      todayExp: widget.todayExp,
                      dailyMax: widget.dailyMax,
                      totalExp: widget.totalExp,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '빠른 기록',
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (todayTotal > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '오늘 $todayTotal회 기록 · GOOD $todayGood / BAD $todayBad / NEUTRAL $todayNeutral',
                        style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    if (i == widget.actions.length) {
                      return _AddActionCard(
                        onPressed: () async {
                          final def = await showAddActionDialog(context);
                          if (def == null) return;
                          widget.onAddAction(def);
                        },
                      );
                    }

                    final def = widget.actions[i];
                    final name = def.name;
                    final isBase = widget.isBaseName(name);

                    return _ActionCard(
                      title: name,
                      icon: def.icon,
                      badge: badgeForKind(def.kind),
                      onLongPress: isBase ? null : () => _confirmDeleteAction(name),
                      showHint: !isBase,
                      onPressCheck: () async {
                        if (name == '자기관리') {
                          final res = await showSelfCareDialog(context);
                          if (res == null) return;
                          widget.onAddLog(
                            action: '자기관리',
                            subtype: res.subtype,
                            minutes: res.minutes,
                            isCustomMinutes: res.isCustom,
                          );
                          return;
                        }

                        if (name == '구매') {
                          final purchaseType = await showPurchaseDialog(context);
                          if (purchaseType == null) return;
                          widget.onAddLog(
                            action: '구매',
                            purchaseType: purchaseType,
                            isCustomMinutes: false,
                          );
                          return;
                        }

                        final ok = await _confirmDidItSheet(title: name);
                        if (!ok) return;
                        widget.onAddLog(action: name, isCustomMinutes: false);
                      },
                    );
                  },
                  childCount: widget.actions.length + 1,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 128,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Text(
                  '최근 기록',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: (todayIdx.isEmpty && yestIdx.isEmpty)
                  ? SliverToBoxAdapter(
                child: _EmptyTimelineCard(
                  text: (() {
                    final h = TimeOfDay.now().hour;
                    if (h >= 5 && h < 11) {
                      return '좋아. 오늘 하루를 시작해볼까?\n첫 기록만 남기면 흐름이 생겨요';
                    } else if (h >= 11 && h < 17) {
                      return '지금 페이스 괜찮아.\n작은 행동 하나만 기록해도 충분해요';
                    } else if (h >= 17 && h < 22) {
                      return '오늘 하루 정리하기 좋은 시간!\n오늘 한 행동을 남겨볼까?';
                    } else {
                      return '오늘도 수고했어.\n마지막 기록 하나로 마무리해볼까?';
                    }
                  })(),
                ),
              )
                  : SliverList(
                delegate: SliverChildListDelegate(
                  [
                    if (todayIdx.isNotEmpty) ...[
                      const _TimelineHeader(text: '오늘'),
                      const SizedBox(height: 10),
                      ...todayIdx.map((i) {
                        final item = widget.timeline[i];
                        final def = findDefByName(widget.actions, item.action);
                        final icon = def?.icon ?? Icons.circle;
                        final badge = def != null ? badgeForKind(def.kind) : 'NEUTRAL';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TimelineFancyCard(
                            item: item,
                            icon: icon,
                            badge: badge,
                            onDelete: () async {
                              final ok = await _confirmDeleteLog();
                              if (!ok) return;
                              widget.onDeleteAt(i);
                            },
                            // ✅ (추가) UI 변경 없이 “롱프레스=수정”
                            onLongPress: () => widget.onEditAt(i),
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                    ],
                    if (yestIdx.isNotEmpty) ...[
                      const _TimelineHeader(text: '어제'),
                      const SizedBox(height: 10),
                      ...yestIdx.map((i) {
                        final item = widget.timeline[i];
                        final def = findDefByName(widget.actions, item.action);
                        final icon = def?.icon ?? Icons.circle;
                        final badge = def != null ? badgeForKind(def.kind) : 'NEUTRAL';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TimelineFancyCard(
                            item: item,
                            icon: icon,
                            badge: badge,
                            onDelete: () async {
                              final ok = await _confirmDeleteLog();
                              if (!ok) return;
                              widget.onDeleteAt(i);
                            },
                            onLongPress: () => widget.onEditAt(i), // ✅
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  final String text;
  const _TimelineHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Row(
      children: [
        Text(
          text,
          style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(color: cs.outlineVariant.withOpacity(0.55), height: 1),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int todayExp;
  final int dailyMax;
  final int totalExp;

  const _SummaryCard({
    required this.todayExp,
    required this.dailyMax,
    required this.totalExp,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final clamped = todayExp.clamp(0, dailyMax);
    final todayProg = dailyMax == 0 ? 0.0 : (clamped / dailyMax);

    final lp = calcLevelProgress(totalExp);
    final pct = (lp.percent * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surfaceContainerLowest,
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: cs.surface,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Icon(Icons.auto_awesome, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                      children: [
                        TextSpan(text: 'Lv ${lp.level} · ${lp.name} '),
                        TextSpan(
                          text: '(진행도 $pct%)',
                          style: t.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lp.remainToNext == 0 ? '최고 레벨에 도달했어요 🎉' : '다음 레벨까지 ${lp.remainToNext} EXP',
                    style: t.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '오늘 EXP ',
                        style: t.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Text(
                        '$clamped/$dailyMax',
                        style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      if (clamped >= dailyMax)
                        Text('MAX', style: t.textTheme.labelMedium?.copyWith(color: cs.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 9,
                      value: todayProg,
                      backgroundColor: cs.outlineVariant.withOpacity(0.25),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 아래 위젯들은 “원본 그대로” 유지 =====

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String badge;
  final Future<void> Function() onPressCheck;
  final VoidCallback? onLongPress;
  final bool showHint;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.badge,
    required this.onPressCheck,
    this.onLongPress,
    this.showHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    const double bottomLift = 24;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.surface,
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: cs.surfaceContainerLowest,
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                          ),
                          child: Icon(icon, color: cs.onSurface),
                        ),
                        const Spacer(),
                        _Badge(text: badge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showHint) ...[
                      const SizedBox(height: 3),
                      Text(
                        '1초 꾹 눌러 삭제',
                        style: t.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: bottomLift,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => onPressCheck(),
                      child: const Icon(Icons.check_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddActionCard extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddActionCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.surface,
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.surfaceContainerLowest,
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                      ),
                      child: Icon(Icons.add_rounded, color: cs.onSurface),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.primary.withOpacity(0.10),
                        border: Border.all(color: cs.primary.withOpacity(0.35)),
                      ),
                      child: Icon(Icons.arrow_forward_rounded, color: cs.primary),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '행동 추가',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '내 루틴을 직접 추가',
                  style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    Color bg;
    Color fg;

    switch (text) {
      case 'GOOD':
        bg = Colors.green.withOpacity(0.10);
        fg = Colors.green.shade800;
        break;
      case 'BAD':
        bg = Colors.red.withOpacity(0.10);
        fg = Colors.red.shade800;
        break;
      default:
        bg = cs.surfaceContainerLowest;
        fg = cs.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: fg.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: t.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyTimelineCard extends StatelessWidget {
  final String text;
  const _EmptyTimelineCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surfaceContainerLowest,
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: t.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// 타임라인 카드 (UI 그대로 + onLongPress만 추가)
/// =======================
class _TimelineFancyCard extends StatelessWidget {
  final LogItem item;
  final IconData icon;
  final String badge;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress; // ✅ 추가

  const _TimelineFancyCard({
    required this.item,
    required this.icon,
    required this.badge,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final chips = item.chips();

    // ✅ 자기관리/구매만 “롱프레스 수정” 안내
    final bool showEditHint = (item.action == '자기관리' || item.action == '구매');

    final Color leftBar = switch (badge) {
      'GOOD' => Colors.green.withOpacity(0.35),
      'BAD' => Colors.red.withOpacity(0.35),
      _ => cs.outlineVariant.withOpacity(0.6),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: onLongPress, // ✅ UI 변화 없이 롱프레스만
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.surface,
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 96,
                decoration: BoxDecoration(
                  color: leftBar,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: cs.surfaceContainerLowest,
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                        ),
                        child: Icon(icon, color: cs.onSurface),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.action,
                                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 8),
                                _Badge(text: badge),
                                const Spacer(),
                                Text(
                                  item.time,
                                  style: t.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: 18,
                                    onPressed: onDelete,
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(
                                      backgroundColor: cs.surfaceContainerLowest,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ✅ 안내 문구 (자기관리/구매 카드에서만)
                            if (showEditHint) ...[
                              const SizedBox(height: 6),
                              Text(
                                '꾹 눌러 수정',
                                style: t.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],

                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: chips
                                    .map(
                                      (c) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: cs.surfaceContainerLowest,
                                      border: Border.all(
                                        color: cs.outlineVariant.withOpacity(0.45),
                                      ),
                                    ),
                                    child: Text(
                                      c,
                                      style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
