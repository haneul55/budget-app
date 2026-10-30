import 'package:budget_app/data/database.dart';
import 'package:budget_app/data/models.dart';
import 'package:budget_app/state/providers.dart';
import 'package:budget_app/ui/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('날짜 칸을 누르면 그날 내역과 카테고리, 하루 합계가 보인다', (tester) async {
    sqfliteFfiInit();
    late AppDatabase db;
    final today = DateTime.now();
    await tester.runAsync(() async {
      await initializeDateFormatting('ko_KR');
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final food = (await db.categories()).first;
      await db.addExpense(
        Expense(
          itemName: '김밥',
          amount: 3500,
          spentAt: today,
          categoryId: food.id,
        ),
      );
      await db.addExpense(
        Expense(itemName: '우산', amount: 8000, spentAt: today),
      );
    });

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    // 휴대폰 화면 크기
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );
    await settle();

    await tester.tap(find.text('${today.day}'));
    await tester.pumpAndSettle();

    expect(find.text('김밥'), findsOneWidget);
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('미분류'), findsOneWidget);
    expect(find.text('하루 합계 · 2건'), findsOneWidget);
    expect(find.text('11,500원'), findsWidgets);
    await tester.runAsync(db.close);
  });
}
