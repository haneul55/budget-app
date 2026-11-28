import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../recognition/ai_classifier.dart';

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
  void select(DateTime month) => state = DateTime(month.year, month.month);
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);

/// 위쪽 고정 바에서 고르는 화면.
enum AppTab { home, calendar, history, categories }

class CurrentTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void go(AppTab tab) => state = tab;
}

final currentTabProvider = NotifierProvider<CurrentTab, AppTab>(CurrentTab.new);

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
  ref.invalidate(dailyTotalsProvider);
  ref.invalidate(monthlyTotalsProvider);
  ref.invalidate(monthExpensesProvider);
  ref.invalidate(pickerMonthsProvider);
}

/// 카테고리 자동 분류 규칙 전체.
final rulesProvider = FutureProvider<List<CategoryRule>>(
  (ref) => ref.watch(databaseProvider).rules(),
);

final sourceImageProvider = FutureProvider.family<SourceImage?, int>(
  (ref, id) => ref.watch(databaseProvider).sourceImage(id),
);

/// 선택한 달의 날짜별 합계(1일부터 말일까지).
final dailyTotalsProvider = FutureProvider<List<int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.dailyTotals(ref.watch(selectedMonthProvider));
});

/// 선택한 달이 속한 해의 1월~12월 월 합계.
final monthlyTotalsProvider =
    FutureProvider<List<({DateTime month, int total})>>((ref) {
      final db = ref.watch(databaseProvider);
      // 고른 달이 속한 해의 1월~12월 (지금 달 기준이면 올해)
      final year = ref.watch(selectedMonthProvider.select((m) => m.year));
      return db.monthlyTotals(DateTime(year, 12));
    });

/// 선택한 달의 모든 내역 (달력 화면용).
final monthExpensesProvider = FutureProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.expensesInMonth(ref.watch(selectedMonthProvider));
});

/// 월 선택 목록용: 이번 달까지 최근 24개월의 월 합계 (선택한 달과 상관없이 고정).
final pickerMonthsProvider =
    FutureProvider<List<({DateTime month, int total})>>((ref) {
      final now = DateTime.now();
      return ref
          .watch(databaseProvider)
          .monthlyTotals(DateTime(now.year, now.month), count: 24);
    });

/// API 키처럼 민감한 값을 폰의 안전한 저장소(iOS 키체인, 안드로이드 암호화 저장소)에 둔다.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// 지금 설정된 AI 분류 방법. 없으면 null → 키워드 규칙만 사용.
/// 폰에 넣은 API 키가 있으면 그걸 먼저 쓰고, 없으면 내 서버 설정을 쓴다.
final categoryAiProvider = FutureProvider<CategoryAi?>((ref) async {
  String? apiKey;
  try {
    apiKey = await ref
        .watch(secureStorageProvider)
        .read(key: DirectCategoryAi.apiKeyStorageKey);
  } catch (_) {
    // 저장소를 못 읽으면 키가 없는 것으로 본다
  }
  if (apiKey != null && apiKey.trim().isNotEmpty) {
    return DirectCategoryAi(apiKey);
  }
  final db = ref.watch(databaseProvider);
  final url = await db.setting(AiServerConfig.urlKey);
  final token = await db.setting(AiServerConfig.tokenKey);
  if (url == null || token == null) return null;
  return AiCategoryClassifier(AiServerConfig(url: url, token: token));
});
