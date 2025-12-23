import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Drift 타입들(Value / LogsCompanion) 쓰려면 필요
import 'package:drift/drift.dart' show Value;

import '../core.dart';

// ✅ AppDatabase 있는 파일 경로에 맞게 수정해줘!
// 예) lib/db/app_db.dart  ->  import '../db/app_db.dart';
// 예) lib/app_db.dart     ->  import '../app_db.dart';
import '../db/app_db.dart';

// ✅ 탭 위젯들 경로도 네 프로젝트에 맞게 맞춰져 있어야 함
import '../ui/log_tab.dart';
import '../ui/decide_tab.dart';
import '../ui/stats_tab.dart';

class HaedoApp extends StatelessWidget {
  const HaedoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6D5EF6));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,

        // ✅ (수정) Flutter 최신 테마에서는 dialogTheme 타입이 DialogThemeData?
        // UI/스타일은 동일하게 유지
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
        ),

        dividerTheme: DividerThemeData(
          thickness: 1,
          color: scheme.outlineVariant.withOpacity(0.55),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          elevation: 0,
          backgroundColor: scheme.surface.withOpacity(0.96),
          surfaceTintColor: Colors.transparent,
          indicatorColor: scheme.primary.withOpacity(0.10),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 24,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.55)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.55)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.primary.withOpacity(0.65), width: 1.2),
          ),
        ),
      ),
      home: const TabShell(),
    );
  }
}

class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> with WidgetsBindingObserver {
  // =====================
  // Drift DB
  // =====================
  late final AppDatabase _db;
  bool _loadingDb = true;

  // ✅ 하루 EXP 캡
  static const int dailyMaxExp = 40;

  int _idx = 0;

  final List<LogItem> _timeline = [];

  // ✅ DB row id 리스트 (LogItem에 id 필드 안 넣고도 삭제 가능)
  final List<int> _timelineIds = [];

  // ✅ 오늘 EXP(0~40) 트래킹
  int _todayExp = 0;
  DateTime _expDay = DateTime.now();

  // ✅ 누적 EXP (레벨 진행도용 / 절대 리셋 X)
  int _totalExp = 0;

  // =====================
  // ✅ 커스텀 행동 저장 (SharedPreferences)
  // =====================
  static const String _prefsCustomActionsKey = 'haedo_custom_actions_v1';

  // ✅ 기본 행동
  final List<ActionDef> _actions = [
    const ActionDef(name: '자기관리', kind: ActionKind.good, icon: Icons.fitness_center),
    const ActionDef(name: '휴식', kind: ActionKind.good, icon: Icons.bedtime),
    const ActionDef(name: '청소', kind: ActionKind.good, icon: Icons.cleaning_services_rounded),
    const ActionDef(name: '자기전 폰', kind: ActionKind.bad, icon: Icons.phone_android),
    const ActionDef(name: '술', kind: ActionKind.bad, icon: Icons.local_bar),
    const ActionDef(name: '폭식', kind: ActionKind.bad, icon: Icons.fastfood),
    const ActionDef(name: '구매', kind: ActionKind.neutral, icon: Icons.shopping_bag),
    const ActionDef(name: '게임', kind: ActionKind.neutral, icon: Icons.sports_esports),
    const ActionDef(name: '카페인', kind: ActionKind.neutral, icon: Icons.coffee),
  ];

  // =====================
  // ✅ (추가) 2) 자정 리셋 100% 보장: 타이머
  // =====================
  Timer? _midnightTimer;

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final diff = nextMidnight.difference(now);

    // 약간의 여유(200ms) — 경계값에서 안전하게
    _midnightTimer = Timer(diff + const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _ensureDay(forceSetState: true);
      _scheduleMidnightReset(); // 다음날도 계속
    });
  }

  // =====================
  // ✅ (추가) 3) 중복 저장 방어: write lock + 짧은 디바운스
  // =====================
  bool _writeLock = false;
  DateTime _lastWriteAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastWriteSig = '';

  bool _shouldBlockDuplicate({
    required String action,
    String? subtype,
    int? minutes,
    String? purchaseType,
  }) {
    final now = DateTime.now();

    // 아주 빠른 연타 방어(예: 700ms)
    final tooSoon = now.difference(_lastWriteAt).inMilliseconds < 700;

    final sig = [
      action.trim(),
      (subtype ?? '').trim(),
      (minutes ?? -1).toString(),
      (purchaseType ?? '').trim(),
    ].join('|');

    final sameSig = sig == _lastWriteSig;
    if (tooSoon && sameSig) return true;

    _lastWriteAt = now;
    _lastWriteSig = sig;
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _db = AppDatabase();
    _initLoad();

    // ✅ 앱 켜져있는 동안 자정 리셋 보장
    _scheduleMidnightReset();
  }

  Future<void> _initLoad() async {
    await _loadCustomActionsFromPrefs();
    await _loadFromDb();

    if (!mounted) return;
    setState(() => _loadingDb = false);

    // 로딩 끝난 시점에도 한 번 확실히 체크
    _ensureDay(forceSetState: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _db.close();
    super.dispose();
  }

  // ✅ 앱이 백그라운드 → 포그라운드로 돌아오면 날짜 갱신 보장
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureDay(forceSetState: true);
      _scheduleMidnightReset();
    }
  }

  void _ensureDay({bool forceSetState = false}) {
    final now = DateTime.now();
    if (!isSameDay(now, _expDay)) {
      _expDay = now;
      _todayExp = 0;
      if (forceSetState && mounted) setState(() {});
    }
  }

  // =====================
  // Logs (DB load)
  // =====================
  Future<void> _loadFromDb() async {
    final rows = await _db.getAllLogs();

    _timeline.clear();
    _timelineIds.clear();

    // 최신순
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int todaySum = 0;
    int totalSum = 0;

    for (final r in rows) {
      _timelineIds.add(r.id);

      // ✅ (수정) 너 core.dart의 LogItem 생성자에 kind: 가 없어서 에러났던 부분
      // => UI/기능 영향 없이 "kind 필드"는 LogItem에 저장하지 않고,
      //    필요하면 액션 정의(_actions)로부터 findDefByName로 추론하면 됨.
      final item = LogItem(
        action: r.action,
        time: hhmmFrom(r.createdAt),
        subtype: r.subtype,
        minutes: r.minutes,
        purchaseType: r.purchaseType,
        expGained: r.expGained,
        at: r.createdAt,
      );

      _timeline.add(item);

      totalSum += r.expGained;

      if (isToday(r.createdAt)) {
        todaySum += r.expGained;
      }
    }

    _todayExp = todaySum.clamp(0, dailyMaxExp);
    _totalExp = totalSum;

    if (mounted) setState(() {});
  }

  // =====================
  // Toast
  // =====================
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _celebrate40() async {
    HapticFeedback.heavyImpact();
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.primary.withOpacity(0.55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.20),
                blurRadius: 26,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 46, color: cs.primary),
              const SizedBox(height: 10),
              const Text(
                '오늘 40 EXP 달성!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '오늘 고생했다 ✨ 내일 또 쌓아보자',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('좋아'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================
  // Actions (Prefs)
  // =====================
  bool _isBaseName(String name) {
    const base = {
      '자기관리',
      '휴식',
      '청소',
      '자기전 폰',
      '술',
      '폭식',
      '구매',
      '게임',
      '카페인',
    };
    return base.contains(name.trim());
  }

  Future<void> _saveCustomActionsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final customs = _actions.where((a) => !_isBaseName(a.name)).toList();

    // 아주 단순 직렬화: name|kind|iconCodePoint
    final list = customs.map((a) => '${a.name}|${a.kind.name}|${a.icon.codePoint}').toList();
    await prefs.setStringList(_prefsCustomActionsKey, list);
  }

  Future<void> _loadCustomActionsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> list = const [];

    // ✅ 안전하게 읽기: 예전에 String으로 저장돼있어도 죽지 않게
    final raw = prefs.get(_prefsCustomActionsKey);

    if (raw is List<String>) {
      list = raw;
    } else if (raw is String) {
      final s = raw.trim();

      // (1) JSON 배열 형태로 저장돼있던 경우: ["a|b|c", "d|e|f"]
      if (s.startsWith('[') && s.endsWith(']')) {
        try {
          final decoded = jsonDecode(s);
          if (decoded is List) {
            list = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          // fall through
        }
      }

      // (2) JSON이 아니면 구분자 추정
      if (list.isEmpty && s.isNotEmpty) {
        if (s.contains('\n')) {
          list = s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else if (s.contains('||')) {
          list = s.split('||').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else if (s.contains(',')) {
          list = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else {
          // 단일 문자열 1개였던 구버전
          list = [s];
        }
      }

      // ✅ 정상 타입(List<String>)으로 다시 저장해두기 (다음부터 안전)
      await prefs.setStringList(_prefsCustomActionsKey, list);
    } else {
      // null 또는 다른 타입이면 빈 리스트로
      list = const [];
    }

    // ===== 여기부터는 기존 로직 그대로 =====
    for (final s in list) {
      final parts = s.split('|');
      if (parts.length < 3) continue;

      final name = parts[0].trim();
      final kindName = parts[1].trim();
      final iconCode = int.tryParse(parts[2]) ?? Icons.bolt.codePoint;

      if (_isBaseName(name)) continue;
      if (_actions.any((a) => a.name.trim() == name)) continue;

      final kind = ActionKind.values.firstWhere(
            (k) => k.name == kindName,
        orElse: () => ActionKind.neutral,
      );

      final icon = IconData(iconCode, fontFamily: 'MaterialIcons');
      _actions.add(ActionDef(name: name, kind: kind, icon: icon));
    }
  }


  void addCustomAction(ActionDef def) {
    _addCustomActionAsync(def);
  }

  Future<void> _addCustomActionAsync(ActionDef def) async {
    final name = def.name.trim();
    if (name.isEmpty) return;

    final exists = _actions.any((a) => a.name.trim() == name);
    if (exists) {
      _toast('이미 같은 이름의 행동이 있어요');
      return;
    }

    setState(() => _actions.add(def));
    await _saveCustomActionsToPrefs();
    _toast('행동이 추가됐어요 ✅');
  }

  void removeCustomActionByName(String name) {
    _removeCustomActionAsync(name);
  }

  Future<void> _removeCustomActionAsync(String name) async {
    if (_isBaseName(name)) return;

    setState(() {
      _actions.removeWhere((a) => a.name == name);
    });

    await _saveCustomActionsToPrefs();
    await _db.deleteLogsByAction(name);
    await _loadFromDb();

    _toast('행동을 삭제했어요');
  }

  // =====================
  // Logs (DB write)
  // =====================
  void addLog({
    required String action,
    String? subtype,
    int? minutes,
    bool isCustomMinutes = false,
    String? purchaseType,
  }) {
    _addLogAsync(
      action: action,
      subtype: subtype,
      minutes: minutes,
      isCustomMinutes: isCustomMinutes,
      purchaseType: purchaseType,
    );
  }

  Future<void> _addLogAsync({
    required String action,
    String? subtype,
    int? minutes,
    bool isCustomMinutes = false,
    String? purchaseType,
  }) async {
    _ensureDay();

    // ✅ (추가) 중복 저장 방어
    if (_shouldBlockDuplicate(
      action: action,
      subtype: subtype,
      minutes: minutes,
      purchaseType: purchaseType,
    )) {
      return; // UX 깨지지 않게 조용히 무시
    }

    // ✅ (추가) write lock
    if (_writeLock) return;
    _writeLock = true;

    try {
      final now = DateTime.now();
      final def = findDefByName(_actions, action);
      final kind = def?.kind ?? ActionKind.neutral;

      final rawExp = expForLog(
        action: action,
        kind: kind,
        minutes: minutes,
        isCustomMinutes: isCustomMinutes,
        purchaseType: purchaseType,
      );

      final before = _todayExp;
      final remain = (dailyMaxExp - _todayExp).clamp(0, dailyMaxExp);
      final gained = rawExp.clamp(0, remain);

      await _db.insertLog(
        LogsCompanion.insert(
          action: action,
          kind: kind.name,
          subtype: Value(subtype),
          minutes: Value(minutes),
          purchaseType: Value(purchaseType),
          expGained: gained,
          createdAt: now,
        ),
      );

      await _loadFromDb();

      final detail = detailTextForSnack(
        action: action,
        subtype: subtype,
        minutes: minutes,
        purchaseType: purchaseType,
      );

      if (gained <= 0) {
        _toast('✔ $detail   (오늘 EXP는 40이 Max)');
      } else {
        _toast('✔ $detail   +$gained EXP');
      }

      if (before < dailyMaxExp && _todayExp >= dailyMaxExp) {
        _celebrate40();
      }
    } finally {
      _writeLock = false;
    }
  }

  void deleteLogAt(int index) {
    _deleteLogAtAsync(index);
  }

  Future<void> _deleteLogAtAsync(int index) async {
    _ensureDay();
    if (index < 0 || index >= _timelineIds.length) return;

    // ✅ (추가) write lock
    if (_writeLock) return;
    _writeLock = true;

    try {
      final item = _timeline[index];
      final id = _timelineIds[index];

      await _db.deleteLog(id);
      await _loadFromDb();

      _toast('기록이 삭제됐어요  -${item.expGained} EXP');
    } finally {
      _writeLock = false;
    }
  }

  // =====================
  // ✅ (추가) 1) 기록 수정(Edit)
  // =====================
  void editLogAt(int index) {
    _editLogAtAsync(index);
  }

  Future<void> _editLogAtAsync(int index) async {
    _ensureDay();
    if (index < 0 || index >= _timelineIds.length) return;

    if (_writeLock) return;
    _writeLock = true;

    try {
      final oldItem = _timeline[index];
      final id = _timelineIds[index];

      String? newSubtype = oldItem.subtype;
      int? newMinutes = oldItem.minutes;
      bool newIsCustomMinutes = false;
      String? newPurchaseType = oldItem.purchaseType;

      // ✅ UI 변경 없이: “롱프레스 → 기존 입력 다이얼로그 재사용”
      if (oldItem.action == '자기관리') {
        final res = await showSelfCareDialog(context);
        if (res == null) return;
        newSubtype = res.subtype;
        newMinutes = res.minutes;
        newIsCustomMinutes = res.isCustom;
      } else if (oldItem.action == '구매') {
        final p = await showPurchaseDialog(context);
        if (p == null) return;
        newPurchaseType = p;
      } else {
        _toast('이 기록은 수정할 항목이 없어요');
        return;
      }

      final def = findDefByName(_actions, oldItem.action);
      final kind = def?.kind ?? ActionKind.neutral;

      final rawExp = expForLog(
        action: oldItem.action,
        kind: kind,
        minutes: newMinutes,
        isCustomMinutes: newIsCustomMinutes,
        purchaseType: newPurchaseType,
      );

      final todaySumWithoutThis = _timeline
          .asMap()
          .entries
          .where((e) => e.key != index)
          .where((e) => isToday(e.value.at))
          .fold<int>(0, (p, e) => p + e.value.expGained);

      final remain = (dailyMaxExp - todaySumWithoutThis).clamp(0, dailyMaxExp);
      final newGained = rawExp.clamp(0, remain);

      await _db.updateLogById(
        id,
        LogsCompanion(
          action: Value(oldItem.action),
          kind: Value(kind.name),
          subtype: Value(newSubtype),
          minutes: Value(newMinutes),
          purchaseType: Value(newPurchaseType),
          expGained: Value(newGained),
          createdAt: Value(oldItem.at),
        ),
      );

      await _loadFromDb();

      final detail = detailTextForSnack(
        action: oldItem.action,
        subtype: newSubtype,
        minutes: newMinutes,
        purchaseType: newPurchaseType,
      );

      _toast('✏️ 수정됨: $detail');
    } finally {
      _writeLock = false;
    }
  }

  // =====================
  // UI
  // =====================
  @override
  Widget build(BuildContext context) {
    if (_loadingDb) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 기존처럼 build에서도 체크 (유지)
    _ensureDay();

    final tabs = <Widget>[
      LogTab(
        actions: _actions,
        timeline: _timeline,
        todayExp: _todayExp,
        dailyMax: dailyMaxExp,
        totalExp: _totalExp,
        onAddLog: addLog,
        onDeleteAt: deleteLogAt,
        onEditAt: editLogAt, // ✅ 추가
        onAddAction: addCustomAction,
        onRemoveActionByName: removeCustomActionByName,
        isBaseName: _isBaseName,
      ),
      DecideTab(
        actions: _actions,
        logs: _timeline,
        onSaveFromJudge: addLog,
      ),
      StatsTab(
        logs: _timeline,
        totalExp: _totalExp,
        actions: _actions,
      ),
    ];

    return Scaffold(
      body: tabs[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (v) => setState(() => _idx = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: '기록'),
          NavigationDestination(icon: Icon(Icons.help_outline), label: '해도될까'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '통계'),
        ],
      ),
    );
  }
}
