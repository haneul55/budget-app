import 'package:budget_app/data/database.dart';
import 'package:budget_app/data/models.dart';
import 'package:budget_app/state/providers.dart';
import 'package:budget_app/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('영수증 저장 후 그날로 이동하면 달력에서 그날 내역이 열린다', (tester) async {
    sqfliteFfiInit();
    late AppDatabase db;
    final day = DateTime(2025, 3, 14);
    await tester.runAsync(() async {
      await initializeDateFormatting('ko_KR');
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await db.addExpense(Expense(itemName: '떡볶이', amount: 6000, spentAt: day));
    });
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await settle();

    // 영수증 화면이 저장하면서 하는 일과 같다
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    container.read(selectedMonthProvider.notifier).select(day);
    container.read(currentTabProvider.notifier).go(AppTab.calendar);
    container.read(openDayRequestProvider.notifier).request(day);
    await settle();
    await tester.pump(const Duration(milliseconds: 500));
    await settle();

    expect(find.text('2025년 3월'), findsOneWidget);
    expect(find.text('떡볶이'), findsOneWidget);
    expect(find.text('하루 합계 · 1건'), findsOneWidget);
    expect(container.read(openDayRequestProvider), isNull);
    await tester.runAsync(db.close);
  });
}
