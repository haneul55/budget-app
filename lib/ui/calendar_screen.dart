import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'app_theme.dart';
import 'expense_form_screen.dart';
import 'widgets/category_avatar.dart';
import 'widgets/pressable.dart';

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

Color? _weekdayColor(int column) => switch (column) {
  0 => AppColors.sunday,
  6 => AppColors.saturday,
  _ => null,
};

/// 한 달 달력. 화면을 꽉 채우고, 날짜 칸을 누르면 그 칸이 커지면서 그날 내역이 보인다.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final expenses = ref.watch(monthExpensesProvider).value ?? const [];
    // 날짜를 눌렀을 때 바로 카테고리 이름이 보이도록 미리 불러 둔다
    ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    final totalsByDay = <int, int>{};
    for (final e in expenses) {
      totalsByDay[e.spentAt.day] = (totalsByDay[e.spentAt.day] ?? 0) + e.amount;
    }
    final monthTotal = expenses.fold<int>(0, (s, e) => s + e.amount);
    final weeks = calendarWeeks(month);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // 요일 줄
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                      child: Row(
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  _weekdays[i],
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color:
                                        _weekdayColor(i) ?? AppColors.textSub,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 남은 높이를 주(週) 수로 나눠 꽉 채운다
                    Expanded(
                      child: Column(
                        children: [
                          for (final week in weeks)
                            Expanded(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppColors.line),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      for (var d = 0; d < 7; d++)
                                        Expanded(
                                          child: week[d].month != month.month
                                              ? _OtherMonthCell(day: week[d])
                                              : _DayCell(
                                                  key: ValueKey(
                                                    'day-${dateKey(week[d])}',
                                                  ),
                                                  day: week[d],
                                                  column: d,
                                                  total:
                                                      totalsByDay[week[d]
                                                          .day] ??
                                                      0,
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 이번 달 합계
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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

/// 앞뒤 달 날짜: 흐린 숫자만, 누를 수 없음.
class _OtherMonthCell extends StatelessWidget {
  const _OtherMonthCell({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${day.day}',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.textFaint),
        ),
      ),
    );
  }
}

/// 이번 달 날짜 칸: 날짜 아래에 그날 합계. 쓴 돈이 없으면 숫자만 있는 흰 칸.
class _DayCell extends ConsumerWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.column,
    required this.total,
  });

  final DateTime day;
  final int column;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    // 영수증을 막 저장한 날이면, 화면 전환이 끝난 뒤 이 칸에서 그날 내역을 펼친다
    final requested = ref.watch(
      openDayRequestProvider.select(
        (d) =>
            d != null &&
            d.year == day.year &&
            d.month == day.month &&
            d.day == day.day,
      ),
    );
    if (requested) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!context.mounted) return;
        if (ref.read(openDayRequestProvider) == null) return;
        ref.read(openDayRequestProvider.notifier).clear();
        _openDay(context, day);
      });
    }
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return Pressable(
      onTap: () => _openDay(context, day),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: isToday
                  ? const BoxDecoration(
                      color: AppColors.peachDeep,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday
                      ? Colors.white
                      : _weekdayColor(column) ?? AppColors.text,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatAmount(total),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.peachText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
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
