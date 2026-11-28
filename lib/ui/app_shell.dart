import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'app_theme.dart';
import 'calendar_screen.dart';
import 'category_manage_screen.dart';
import 'home_screen.dart';
import 'monthly_history_screen.dart';
import 'widgets/month_picker.dart';

/// 앱의 바깥 틀. 위쪽 바(달 바꾸기 + 홈·달력·월별·카테고리 버튼)는 항상 남아 있고,
/// 그 아래에서 화면이 바뀌거나 상세 화면이 열린다.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _navKey = GlobalKey<NavigatorState>();
  bool _pickerOpen = false;

  static const _tabs = [
    (tab: AppTab.home, icon: Icons.home_outlined, label: '홈'),
    (tab: AppTab.calendar, icon: Icons.calendar_month_outlined, label: '달력'),
    (tab: AppTab.history, icon: Icons.bar_chart, label: '월별 기록'),
    (tab: AppTab.categories, icon: Icons.tune, label: '카테고리 관리'),
  ];

  void _go(AppTab tab) {
    _navKey.currentState?.popUntil((r) => r.isFirst);
    ref.read(currentTabProvider.notifier).go(tab);
    if (_pickerOpen) setState(() => _pickerOpen = false);
  }

  void _handleBack() {
    if (_pickerOpen) {
      setState(() => _pickerOpen = false);
    } else if (_navKey.currentState?.canPop() ?? false) {
      _navKey.currentState!.pop();
    } else if (ref.read(currentTabProvider) != AppTab.home) {
      _go(AppTab.home);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final current = ref.watch(currentTabProvider);
    final pickerMonths = ref.watch(pickerMonthsProvider).value ?? const [];
    final notifier = ref.read(selectedMonthProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '이전 달',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: notifier.previous,
                ),
                MonthDropdownButton(
                  month: month,
                  expanded: _pickerOpen,
                  onTap: () => setState(() => _pickerOpen = !_pickerOpen),
                ),
                IconButton(
                  tooltip: '다음 달',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: notifier.next,
                ),
              ],
            ),
          ),
          actions: [
            for (final t in _tabs)
              IconButton(
                tooltip: t.label,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: t.tab == current
                      ? AppColors.peachLight
                      : Colors.transparent,
                  foregroundColor: t.tab == current
                      ? AppColors.peachText
                      : AppColors.textSub,
                ),
                icon: Icon(t.icon),
                onPressed: () => _go(t.tab),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Navigator(
              key: _navKey,
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const _TabPages()),
            ),
            // 달 목록이 열려 있으면 바깥을 눌러 닫는다
            if (_pickerOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _pickerOpen = false),
                  child: ColoredBox(
                    color: AppColors.text.withValues(alpha: 0.12),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MonthPickerPanel(
                open: _pickerOpen,
                months: pickerMonths,
                selected: month,
                onSelected: (m) {
                  notifier.select(m);
                  setState(() => _pickerOpen = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위쪽 바에서 고른 화면. 한 번 연 화면은 스크롤 위치 등을 기억한다.
class _TabPages extends ConsumerWidget {
  const _TabPages();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTabProvider);
    return IndexedStack(
      index: AppTab.values.indexOf(current),
      children: const [
        HomeScreen(),
        CalendarScreen(),
        MonthlyHistoryScreen(),
        CategoryManageScreen(),
      ],
    );
  }
}
