import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'app_theme.dart';
import 'expense_form_screen.dart';
import 'widgets/category_avatar.dart';
import 'widgets/spending_charts.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 달력에 그릴 주(週) 목록. 일요일부터 시작하고, 앞뒤 빈칸은 이전·다음 달 날짜로 채운다.
List<List<DateTime>> calendarWeeks(DateTime month) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final leading = first.weekday % 7; // 일요일 = 0
  final cellCount = ((leading + days) / 7).ceil() * 7;
  return [
    for (var w = 0; w < cellCount ~/ 7; w++)
      [
        for (var d = 0; d < 7; d++)
          DateTime(month.year, month.month, 1 - leading + w * 7 + d),
      ],
  ];
}

const _cellHeight = 78.0;

/// 한 달 달력. 날짜 칸을 누르면 그 칸이 커지면서 그날 내역이 보인다.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final expenses = ref.watch(monthExpensesProvider).value ?? const [];
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };

    final byDay = <int, List<Expense>>{};
    for (final e in expenses) {
      byDay.putIfAbsent(e.spentAt.day, () => []).add(e);
    }
    final monthTotal = expenses.fold<int>(0, (s, e) => s + e.amount);
    final weeks = calendarWeeks(month);
    final theme = Theme.of(context);
    const border = BorderSide(color: AppColors.line);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  ref.read(selectedMonthProvider.notifier).previous(),
            ),
            Text(formatMonth(month)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(selectedMonthProvider.notifier).next(),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                Text('이번 달 합계', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  formatWon(monthTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                // 요일 머리줄
                Container(
                  color: AppColors.peach,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      for (final w in _weekdays)
                        Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var w = 0; w < weeks.length; w++)
                  Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          child: Container(
                            height: _cellHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                top: border,
                                left: d == 0 ? BorderSide.none : border,
                              ),
                            ),
                            child: weeks[w][d].month != month.month
                                ? _OtherMonthCell(day: weeks[w][d])
                                : _DayCell(
                                    key: ValueKey('day-${dateKey(weeks[w][d])}'),
                                    day: weeks[w][d],
                                    expenses:
                                        byDay[weeks[w][d].day] ?? const [],
                                    categories: categories,
                                  ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 앞뒤 달 날짜: 흐린 숫자만.
class _OtherMonthCell extends StatelessWidget {
  const _OtherMonthCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 6, 4),
        child: Text(
          '${day.day}',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.textFaint),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.expenses,
    required this.categories,
  });

  final DateTime day;
  final List<Expense> expenses;
  final Map<int?, Category> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final total = expenses.fold<int>(0, (s, e) => s + e.amount);
    // 그날 쓴 카테고리 색 점 (최대 3개)
    final dotColors = <Color>{
      for (final e in expenses) categoryColor(categories[e.categoryId]),
    }.take(3);

    return Material(
      color: isToday ? AppColors.selectedCell : Colors.transparent,
      child: InkWell(
        onTap: () => _openDay(context, day),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 6, 6, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${day.day}',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSub,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
              const Spacer(),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.peachLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      compactWon(total),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.peachText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final c in dotColors)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 누른 칸 위치에서 커지듯이 그날 내역 카드를 띄운다.
void _openDay(BuildContext cellContext, DateTime day) {
  final box = cellContext.findRenderObject() as RenderBox?;
  final screen = MediaQuery.sizeOf(cellContext);
  var origin = Alignment.center;
  if (box != null && box.hasSize) {
    final center = box.localToGlobal(box.size.center(Offset.zero));
    origin = Alignment(
      center.dx / screen.width * 2 - 1,
      center.dy / screen.height * 2 - 1,
    );
  }
  showGeneralDialog(
    context: cellContext,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: AppColors.text.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => _DayDetail(day: day),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          alignment: origin,
          scale: Tween(begin: 0.1, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 확대된 날짜 칸: 그날 내역과 카테고리, 아래에 하루 합계.
class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expenses = (ref.watch(monthExpensesProvider).value ?? const [])
        .where((e) => dateKey(e.spentAt) == dateKey(day))
        .toList();
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final total = expenses.fold<int>(0, (s, e) => s + e.amount);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: AppColors.peach,
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    child: Row(
                      children: [
                        Text(formatDay(day), style: theme.textTheme.titleLarge),
                        const Spacer(),
                        IconButton(
                          tooltip: '닫기',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  if (expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('이날은 쓴 돈이 없어요'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: expenses.length,
                        itemBuilder: (context, i) {
                          final e = expenses[i];
                          final c = categories[e.categoryId];
                          return ListTile(
                            leading: CategoryAvatar(category: c, size: 36),
                            title: Text(
                              e.itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                categoryName(c),
                                if (e.merchant != null) e.merchant!,
                              ].join(' · '),
                            ),
                            trailing: Text(
                              formatWon(e.amount),
                              style: theme.textTheme.titleSmall,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExpenseFormScreen(initial: e),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.peachLight,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Row(
                      children: [
                        Text(
                          '하루 합계 · ${expenses.length}건',
                          style: theme.textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Text(
                          formatWon(total),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
  }
}
