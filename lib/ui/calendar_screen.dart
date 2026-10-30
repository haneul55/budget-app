import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'expense_form_screen.dart';
import 'widgets/category_avatar.dart';
import 'widgets/spending_charts.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 달력 칸 목록. 일요일부터 시작하고, 1일 앞의 빈칸은 null.
List<DateTime?> calendarDays(DateTime month) {
  final first = DateTime(month.year, month.month);
  final days = DateTime(month.year, month.month + 1, 0).day;
  final leading = first.weekday % 7; // 일요일 = 0
  return [
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
  ];
}

Color? _weekdayColor(int column) => switch (column) {
  0 => Colors.red.shade400,
  6 => Colors.blue.shade400,
  _ => null,
};

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
    final cells = calendarDays(month);
    final theme = Theme.of(context);

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
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[i],
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _weekdayColor(i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.72,
            children: [
              for (var i = 0; i < cells.length; i++)
                cells[i] == null
                    ? const SizedBox.shrink()
                    : _DayCell(
                        day: cells[i]!,
                        column: i % 7,
                        expenses: byDay[cells[i]!.day] ?? const [],
                        categories: categories,
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.column,
    required this.expenses,
    required this.categories,
  });

  final DateTime day;
  final int column;
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
      for (final e in expenses)
        categories[e.categoryId] == null
            ? Colors.grey
            : Color(categories[e.categoryId]!.colorValue),
    }.take(3);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: total > 0
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isToday
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDay(context, day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _weekdayColor(column),
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
                const Spacer(),
                if (total > 0)
                  FittedBox(
                    child: Text(
                      compactWon(total),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in dotColors)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
            ),
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
    barrierColor: Colors.black45,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
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
                  const Divider(height: 1),
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
                    color: theme.colorScheme.surfaceContainerHighest,
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
