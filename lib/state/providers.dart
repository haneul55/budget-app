import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/models.dart';

/// main()에서 열린 DB로 override 한다.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(),
);

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);
  void next() => state = DateTime(state.year, state.month + 1);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).categories(),
);

/// 선택한 달의 카테고리별 누적 금액. 금액이 큰 순서, 미분류는 내역이 있을 때만 맨 뒤.
final monthSummaryProvider = FutureProvider<List<CategoryTotal>>((ref) async {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  final categories = await ref.watch(categoriesProvider.future);
  final totals = await db.categoryTotals(month);

  final list = [
    for (final c in categories)
      CategoryTotal(
        category: c,
        total: totals[c.id]?.total ?? 0,
        count: totals[c.id]?.count ?? 0,
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));
  final uncategorized = totals[null];
  if (uncategorized != null) {
    list.add(
      CategoryTotal(
        category: null,
        total: uncategorized.total,
        count: uncategorized.count,
      ),
    );
  }
  return list;
});

/// 선택한 달의 카테고리 내역. 인자가 null이면 미분류.
final categoryExpensesProvider = FutureProvider.family<List<Expense>, int?>((
  ref,
  categoryId,
) {
  final db = ref.watch(databaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.expensesInMonth(
    month,
    categoryId: categoryId,
    uncategorizedOnly: categoryId == null,
  );
});

/// 데이터를 바꾼 뒤 화면들을 다시 불러온다.
void refreshData(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(monthSummaryProvider);
  ref.invalidate(categoryExpensesProvider);
  ref.invalidate(rulesProvider);
}

/// 카테고리 자동 분류 규칙 전체.
final rulesProvider = FutureProvider<List<CategoryRule>>(
  (ref) => ref.watch(databaseProvider).rules(),
);

final sourceImageProvider = FutureProvider.family<SourceImage?, int>(
  (ref, id) => ref.watch(databaseProvider).sourceImage(id),
);
