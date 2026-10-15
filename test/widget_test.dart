import 'package:budget_app/data/database.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('홈 화면에 기본 카테고리가 보인다', (tester) async {
    sqfliteFfiInit();
    late AppDatabase db;
    await tester.runAsync(() async {
      await initializeDateFormatting('ko_KR');
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const BudgetApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('식비'), findsOneWidget);
    expect(find.text('0원'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
