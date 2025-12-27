import 'package:flutter/material.dart';
import '../core.dart';

enum StatsPeriod { today, last7, last30, custom }

/// =======================
/// 3) 통계 탭 (기간 토글 + GOOD/NEUTRAL/BAD 클릭 리스트 + 성장 제외 필터)
/// =======================
class StatsTab extends StatefulWidget {
  final List<LogItem> logs;
  final int totalExp;
  final List<ActionDef> actions;

  const StatsTab({
    super.key,
    required this.logs,
    required this.totalExp,
    required this.actions,
  });

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  StatsPeriod _period = StatsPeriod.last7;
  DateTimeRange? _customRange;

  // ✅ 요일 선택 (0=월 ... 6=일)
  int _weekdayPick = 0;

  DateTime _floorDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _ceilDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  int _todayWeekdayPick() => DateTime.now().weekday - 1; // 0=월..6=일

  /// ✅ start 기준으로 "최대 1달"만 허용 (예: 8/22 ~ 9/21)
  DateTime _addMonthsClamped(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = ((d.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(y, m, day, d.hour, d.minute, d.second, d.millisecond, d.microsecond);
  }

  DateTimeRange _clampRangeMaxOneMonth(DateTimeRange r) {
    final start = _floorDay(r.start);
    final maxEnd = _addMonthsClamped(start, 1).subtract(const Duration(days: 1));
    final endRaw = _ceilDay(r.end);
    final end = endRaw.isAfter(maxEnd) ? maxEnd : endRaw;
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _rangeFromPeriod() {
    final now = DateTime.now();
    final end = _ceilDay(now);

    switch (_period) {
      case StatsPeriod.today:
        return DateTimeRange(
          start: _floorDay(now),
          end: end,
        );

      case StatsPeriod.last7:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 6)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0),
          end: end,
        );
      case StatsPeriod.last30:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 29)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0),
          end: end,
        );
      case StatsPeriod.custom:
        final r = _customRange;
        if (r == null) {
          return DateTimeRange(
            start: end.subtract(const Duration(days: 6)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0),
            end: end,
          );
        }
        return DateTimeRange(start: _floorDay(r.start), end: _ceilDay(r.end));
    }
  }

  String _periodLabel(DateTimeRange r) {
    String f(DateTime d) => '${d.month}/${d.day}';
    switch (_period) {
      case StatsPeriod.today:
        return '오늘 (${f(r.start)})';

      case StatsPeriod.last7:
        return '최근 7일 (${f(r.start)}~${f(r.end)})';
      case StatsPeriod.last30:
        return '최근 1달 (${f(r.start)}~${f(r.end)})';
      case StatsPeriod.custom:
        return '기간 (${f(r.start)}~${f(r.end)})';
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final init = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        );

    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: init,
      helpText: '기간 설정 (최대 1달)',
      saveText: '적용',
    );

    if (r == null) return;

    final clamped = _clampRangeMaxOneMonth(r);

    setState(() {
      _customRange = clamped;
      _period = StatsPeriod.custom;
      _weekdayPick = _weekdayPick.clamp(0, 6);
    });
  }

  List<LogItem> _filterLogsByRange(List<LogItem> logs, DateTimeRange r) {
    return logs.where((l) {
      final t = l.at;
      return !t.isBefore(r.start) && !t.isAfter(r.end);
    }).toList();
  }

  Future<void> _showKindLogs(ActionKind kind, List<LogItem> filtered, DateTimeRange r) async {
    final list = filtered.where((l) {
      final def = findDefByName(widget.actions, l.action);
      final k = def?.kind ?? ActionKind.neutral;
      return k == kind;
    }).toList();

    String title;
    IconData icon;
    switch (kind) {
      case ActionKind.good:
        title = 'GOOD';
        icon = Icons.thumb_up_alt_rounded;
        break;
      case ActionKind.neutral:
        title = 'NEUTRAL';
        icon = Icons.remove_circle_outline_rounded;
        break;
      case ActionKind.bad:
        title = 'BAD';
        icon = Icons.block_rounded;
        break;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final h = MediaQuery.of(ctx).size.height;

        // ✅ 항상 "가운데 + 화면 절반 높이"
        return Center(
          child: SizedBox(
            height: h * 0.50,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                      child: Row(
                        children: [
                          Icon(icon, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text(
                            _periodLabel(r),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            tooltip: '닫기',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                        child: Text(
                          '이 기간엔 기록이 없어요',
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                        ),
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final l = list[i];
                          final def = findDefByName(widget.actions, l.action);
                          final aIcon = def?.icon ?? Icons.bolt_rounded;

                          final detail = detailTextForSnack(
                            action: l.action,
                            subtype: l.subtype,
                            minutes: l.minutes,
                            purchaseType: l.purchaseType,
                          );

                          final expText = l.expGained > 0 ? '+${l.expGained} EXP' : '0 EXP';

                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(aIcon, color: cs.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(detail, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 6),
                                      Text(
                                        l.time,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: cs.primary.withOpacity(0.25)),
                                  ),
                                  child: Text(
                                    expText,
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    // ✅ 성장(누적/최근7일)은 "전체 logs" 기준 (기간 토글 영향 X)
    final lp = calcLevelProgress(widget.totalExp);
    final pct = (lp.percent * 100).round();

    final now = DateTime.now();
    int last7Exp = 0;
    for (final l in widget.logs) {
      final days = now.difference(l.at).inDays;
      if (days >= 0 && days < 7) last7Exp += l.expGained;
    }

    // ✅ 기간 토글 적용 범위: 성장 제외 나머지 전부
    final range = _rangeFromPeriod();
    final filteredLogs = _filterLogsByRange(widget.logs, range);

    // ====== GOOD / NEUTRAL / BAD 분포 (기간 적용) ======
    int good = 0, bad = 0, neutral = 0;
    for (final l in filteredLogs) {
      final def = findDefByName(widget.actions, l.action);
      final kind = def?.kind ?? ActionKind.neutral;
      switch (kind) {
        case ActionKind.good:
          good++;
          break;
        case ActionKind.bad:
          bad++;
          break;
        case ActionKind.neutral:
          neutral++;
          break;
      }
    }
    final totalCount = good + bad + neutral;

    // ====== 행동 TOP (기간 적용) ======
    final Map<String, int> freq = {};
    for (final l in filteredLogs) {
      freq[l.action] = (freq[l.action] ?? 0) + 1;
    }
    final topActions = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final String topInsight = topActions.isEmpty
        ? '아직 기록이 없어요'
        : buildTopActionInsight(
      action: topActions.first.key,
      kind: (findDefByName(widget.actions, topActions.first.key)?.kind ?? ActionKind.neutral),
      logs: filteredLogs,
    );

    // ====== 자기관리 카드 데이터 (기간 적용) ======
    final selfCareLogs = filteredLogs.where((l) => l.action == '자기관리').toList();
    int selfCareTotalMin = 0;
    final Map<String, int> subtypeCount = {};
    for (final l in selfCareLogs) {
      selfCareTotalMin += (l.minutes ?? 0);
      final sub = l.subtype ?? '기타';
      subtypeCount[sub] = (subtypeCount[sub] ?? 0) + 1;
    }
    final selfCareHours = selfCareTotalMin ~/ 60;
    final selfCareRemainMin = selfCareTotalMin % 60;
    final selfCareAvg = selfCareLogs.isEmpty ? 0 : (selfCareTotalMin / selfCareLogs.length).round();

    String topSubtype = '';
    int topSubtypeCount = 0;
    subtypeCount.forEach((k, v) {
      if (v > topSubtypeCount) {
        topSubtype = k;
        topSubtypeCount = v;
      }
    });

    // ====== 구매 성향 카드 데이터 (기간 적용) ======
    final purchaseLogs = filteredLogs.where((l) => l.action == '구매').toList();
    final Map<String, int> purchaseTypeCount = {};
    for (final l in purchaseLogs) {
      final type = l.purchaseType ?? '기타';
      purchaseTypeCount[type] = (purchaseTypeCount[type] ?? 0) + 1;
    }

    String topPurchaseType = '';
    int topPurchaseCount = 0;
    purchaseTypeCount.forEach((k, v) {
      if (v > topPurchaseCount) {
        topPurchaseType = k;
        topPurchaseCount = v;
      }
    });

    final int totalPurchaseCount = purchaseLogs.length;

    // ✅ AnimatedSwitcher 키: 기간이 바뀔 때마다 "아래 통계 묶음"을 새로 렌더링해서 애니메이션
    final switchKey = ValueKey<String>(
      '${_period.name}-${range.start.millisecondsSinceEpoch}-${range.end.millisecondsSinceEpoch}',
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('통계'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _StatCard(
              title: '조회 기간',
              subtitle: _periodLabel(range),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<StatsPeriod>(
                    // ✅ 체크(✓) 아이콘 제거 → 색만 변함
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: StatsPeriod.today,
                        label: Text('오늘', textAlign: TextAlign.center),
                      ),
                      ButtonSegment(
                        value: StatsPeriod.last7,
                        label: Text('최근\n7일', textAlign: TextAlign.center),
                      ),
                      ButtonSegment(
                        value: StatsPeriod.last30,
                        label: Text('최근\n1달', textAlign: TextAlign.center),
                      ),
                      ButtonSegment(
                        value: StatsPeriod.custom,
                        label: Text('기간\n설정', textAlign: TextAlign.center),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) async {
                      final v = s.first;

                      if (v == StatsPeriod.custom) {
                        await _pickCustomRange();
                        return;
                      }

                      if (v == StatsPeriod.today) {
                        // ✅ 오늘 선택 시 요일도 자동으로 "오늘 요일"로 이동
                        setState(() {
                          _period = v;
                          _weekdayPick = _todayWeekdayPick().clamp(0, 6);
                        });
                        return;
                      }

                      setState(() => _period = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※ 성장 카드(레벨/누적/최근7일)는 전체 기간 기준',
                    style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            _StatCard(
              title: '성장',
              subtitle: lp.remainToNext == 0 ? '최고 레벨에 도달했어요 🎉' : '다음 레벨까지 ${lp.remainToNext} EXP',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lv ${lp.level} · ${lp.name} (진행도 $pct%)',
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '누적 EXP  ${widget.totalExp}',
                        style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '최근 7일 +$last7Exp',
                        style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: switchKey,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatCard(
                    title: '행동 성격 분포',
                    subtitle: _kindSubtitle(good: good, bad: bad, neutral: neutral, total: totalCount),
                    child: SizedBox(
                      height: 170,
                      child: Center(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _KindCard(
                                label: 'GOOD',
                                count: good,
                                total: totalCount,
                                color: Colors.green,
                                onTap: () => _showKindLogs(ActionKind.good, filteredLogs, range),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KindCard(
                                label: 'NEUTRAL',
                                count: neutral,
                                total: totalCount,
                                color: cs.primary,
                                onTap: () => _showKindLogs(ActionKind.neutral, filteredLogs, range),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _KindCard(
                                label: 'BAD',
                                count: bad,
                                total: totalCount,
                                color: Colors.red,
                                onTap: () => _showKindLogs(ActionKind.bad, filteredLogs, range),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  _StatCard(
                    title: '요일별 행동',
                    subtitle: '요일을 선택하면 그날 했던 행동이 바로 보여요',
                    child: _WeekdayInlineList(
                      weekdayPick: _weekdayPick,
                      onPick: (idx) => setState(() => _weekdayPick = idx),
                      logs: filteredLogs,
                      actions: widget.actions,
                    ),
                  ),

                  _StatCard(
                    title: '📖 자기관리',
                    subtitle: selfCareLogs.isEmpty ? '아직 자기관리 기록이 없어요' : '짧아도 꾸준함이 쌓이고 있어요',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '총 ${selfCareHours}시간 ${selfCareRemainMin}분',
                          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '평균 ${selfCareAvg}분 / 회',
                          style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        if (topSubtype.isNotEmpty)
                          Text(
                            '가장 많이 한 것: $topSubtype',
                            style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),

                  _StatCard(
                    title: '🛒 구매 성향',
                    subtitle: totalPurchaseCount == 0 ? '아직 구매 기록이 없어요' : '요즘 소비 패턴을 한눈에 볼 수 있어요',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (totalPurchaseCount == 0)
                          Text('—', style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
                        else ...[
                          Text(
                            '총 ${totalPurchaseCount}회',
                            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          ...purchaseTypeCount.entries.map((e) {
                            final ratio = e.value / totalPurchaseCount;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(width: 80, child: Text(e.key)),
                                  Expanded(
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: cs.primary.withOpacity(0.15),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: ratio,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(6),
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${e.value}'),
                                ],
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                          if (topPurchaseType.isNotEmpty)
                            Text(
                              '가장 많았던 구매: $topPurchaseType',
                              style: t.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                        ],
                      ],
                    ),
                  ),

                  _StatCard(
                    title: '가장 많이 한 행동',
                    subtitle: topActions.isEmpty ? '아직 기록이 없어요' : '요즘 이 행동이 가장 자주 반복되고 있어요',
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            topInsight,
                            style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (topActions.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('—', style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          )
                        else
                          ...topActions.take(5).map(
                                (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: cs.surfaceContainerLowest,
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      e.key,
                                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${e.value}회',
                                      style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
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

/// =======================
/// 공용 카드 래퍼
/// =======================
class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// =======================
/// 성격 카드 (탭 애니메이션)
/// =======================
class _KindCard extends StatefulWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final VoidCallback? onTap;

  const _KindCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    this.onTap,
  });

  @override
  State<_KindCard> createState() => _KindCardState();
}

class _KindCardState extends State<_KindCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final pct = widget.total == 0 ? 0 : ((widget.count / widget.total) * 100).round();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: cs.surfaceContainerLowest,
            border: Border.all(
              color: _pressed ? widget.color.withOpacity(0.8) : cs.outlineVariant.withOpacity(0.55),
            ),
            boxShadow: _pressed
                ? []
                : [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: widget.color.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.count}회',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '$pct%',
                style: t.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// ✅ 요일 선택 → 같은 카드 안에서 행동 리스트 표시 (기간 적용)
/// 체크(✓) 없이 색만 변하는 UI + 999까지 표시(넘으면 999+)
/// ✅ 리스트/빈상태 AnimatedSwitcher로 전환(오늘 자동이동 튐 제거)
/// =======================
class _WeekdayInlineList extends StatelessWidget {
  final int weekdayPick; // 0=월..6=일
  final void Function(int) onPick;
  final List<LogItem> logs;
  final List<ActionDef> actions;

  const _WeekdayInlineList({
    required this.weekdayPick,
    required this.onPick,
    required this.logs,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    const labels = ['월', '화', '수', '목', '금', '토', '일'];

    // 요일별 카운트
    final counts = List<int>.filled(7, 0);
    for (final l in logs) {
      final idx = l.at.weekday - 1;
      if (idx >= 0 && idx < 7) counts[idx]++;
    }

    // 선택 요일 로그
    final selectedWeekday = weekdayPick + 1;
    final dayLogs = logs
        .where((l) => l.at.weekday == selectedWeekday)
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 체크표시 없는 커스텀 버튼 Row (높이 고정 → overflow 방지)
        Row(
          children: List.generate(7, (i) {
            final isPick = i == weekdayPick;

            final c = counts[i];
            final countText = c > 999 ? '999+' : '$c';

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onPick(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    height: 44,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isPick ? cs.primary.withOpacity(0.14) : cs.surfaceContainerLowest,
                      border: Border.all(
                        color: isPick ? cs.primary.withOpacity(0.65) : cs.outlineVariant.withOpacity(0.55),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isPick ? FontWeight.w900 : FontWeight.w700,
                            color: isPick ? cs.primary : cs.onSurface,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            countText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isPick ? cs.primary : cs.onSurfaceVariant,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 12),
        Text(
          '${labels[weekdayPick]}요일 기록 ${dayLogs.length}개',
          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),

        // ✅ 여기만 변경: 리스트/빈상태 전환을 7일/1달처럼 자연스럽게
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: dayLogs.isEmpty
              ? Container(
            key: ValueKey('empty-$weekdayPick'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
            ),
            child: Text(
              '이 요일엔 기록이 없어요',
              style: t.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
              : ConstrainedBox(
            key: ValueKey('list-$weekdayPick-${dayLogs.length}'),
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: dayLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final l = dayLogs[i];
                final def = findDefByName(actions, l.action);
                final aIcon = def?.icon ?? Icons.bolt_rounded;

                final detail = detailTextForSnack(
                  action: l.action,
                  subtype: l.subtype,
                  minutes: l.minutes,
                  purchaseType: l.purchaseType,
                );

                final expText = l.expGained > 0 ? '+${l.expGained} EXP' : '0 EXP';

                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(aIcon, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l.time,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: cs.primary.withOpacity(0.25)),
                        ),
                        child: Text(
                          expText,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// =======================
/// 분포 해석 문구
/// =======================
String _kindSubtitle({
  required int good,
  required int bad,
  required int neutral,
  required int total,
}) {
  if (total == 0) return '아직 기록이 없어요';

  final goodPct = (good / total) * 100;
  final badPct = (bad / total) * 100;
  final neutralPct = (neutral / total) * 100;

  if (goodPct >= 50) return '회복/성장 행동이 중심이에요';
  if (badPct >= 40) return '유혹이 잦았던 기간이에요 (괜찮아, 다시 가면 돼)';
  if (neutralPct >= 50) return '일상 루틴 위주로 흘러가고 있어요';
  return '고르게 섞여 있어요. 흐름을 관찰해봐요';
}

/// =======================
/// TOP 행동 해석 문구 생성
/// =======================
String buildTopActionInsight({
  required String action,
  required ActionKind kind,
  required List<LogItem> logs,
}) {
  if (logs.isEmpty) return '아직 기록이 없어요';

  final actionLogs = logs.where((l) => l.action == action).toList();
  final count = actionLogs.length;
  if (count == 0) return '아직 기록이 없어요';

  final weekdayCount = List<int>.filled(7, 0);
  for (final l in actionLogs) {
    final d = l.at.weekday - 1;
    if (d >= 0 && d < 7) weekdayCount[d]++;
  }
  final weekdayMax = weekdayCount.reduce((a, b) => a > b ? a : b);
  final weekdayIdx = weekdayCount.indexOf(weekdayMax);
  const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  final weekdayRatio = weekdayMax / count;

  int morning = 0, daytime = 0, night = 0;
  for (final l in actionLogs) {
    final h = l.at.hour;
    if (h >= 5 && h < 11) {
      morning++;
    } else if (h >= 11 && h < 18) {
      daytime++;
    } else {
      night++;
    }
  }
  final maxTime = [morning, daytime, night].reduce((a, b) => a > b ? a : b);
  final timeRatio = maxTime / count;

  final now = DateTime.now();
  int recent = 0, before = 0;
  for (final l in actionLogs) {
    final days = now.difference(l.at).inDays;
    if (days >= 0 && days < 7) {
      recent++;
    } else if (days >= 7 && days < 14) {
      before++;
    }
  }
  final increased = recent >= before + 2 && recent >= 3;

  if (increased) {
    switch (kind) {
      case ActionKind.good:
        return '최근 들어 이 행동이 늘고 있어요\n흐름이 좋아 보여요';
      case ActionKind.bad:
        return '최근에 이 행동이 조금 늘었어요\n컨디션을 한 번만 점검해봐요';
      case ActionKind.neutral:
        return '요즘 이 선택이 자주 반복되고 있어요';
    }
  }

  if (weekdayRatio >= 0.4) {
    return '특히 ${weekdayLabels[weekdayIdx]}요일에 이 행동이 많이 나타났어요';
  }

  if (timeRatio >= 0.5) {
    if (night == maxTime) {
      return kind == ActionKind.bad
          ? '주로 밤에 이 선택을 하게 돼요\n피로 때문일 수도 있어요'
          : '밤 시간에 이 행동이 자주 있었어요';
    }
    if (morning == maxTime) {
      return kind == ActionKind.good
          ? '하루를 시작할 때 좋은 선택을 자주 했어요'
          : '아침 시간대에 이 행동이 반복되고 있어요';
    }
    if (daytime == maxTime) {
      return '낮 시간대에 이 행동이 가장 많았어요';
    }
  }

  switch (kind) {
    case ActionKind.good:
      return '회복과 성장을 위한 선택이 자주 있었어요';
    case ActionKind.neutral:
      return '일상 루틴이 흐름을 만들고 있어요';
    case ActionKind.bad:
      return '유혹이 반복되기 쉬운 구간이에요\n괜찮아요, 알아차린 게 중요해요';
  }
}
