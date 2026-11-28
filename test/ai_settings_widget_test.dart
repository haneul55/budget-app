import 'package:budget_app/data/database.dart';
import 'package:budget_app/main.dart';
import 'package:budget_app/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('카테고리 관리에서 AI 설정을 열고 저장하면 켜짐으로 바뀐다', (tester) async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
    late AppDatabase db;
    await tester.runAsync(() async {
      await initializeDateFormatting('ko_KR');
      db = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
    });
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const BudgetApp(),
      ),
    );
    await settle();
    await tester.tap(find.byTooltip('카테고리 관리'));
    await settle();
    expect(find.text('꺼짐 · 키워드 규칙으로만 분류해요'), findsOneWidget);

    await tester.tap(find.text('AI 자동 분류'));
    await settle();
    // 처음엔 'API 키 직접'이 골라져 있다. 키를 넣고 저장하면 켜진다
    await tester.enterText(find.byType(TextField).first, 'sk-ant-test');
    await tester.tap(find.text('저장'));
    await settle();
    expect(find.text('켜짐 · 키워드로 못 찾은 품목은 AI가 골라요'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'anthropic_api_key'),
      'sk-ant-test',
    );

    // '내 서버'로 바꿔 저장하면 폰의 키는 지워지고 서버 설정이 저장된다
    await tester.tap(find.text('AI 자동 분류'));
    await settle();
    await tester.tap(find.text('내 서버'));
    await settle();
    await tester.enterText(find.byType(TextField).at(0), 'a.workers.dev');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.text('저장'));
    await settle();
    expect(find.text('켜짐 · 키워드로 못 찾은 품목은 AI가 골라요'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.setting('ai_server_url'), 'a.workers.dev');
      expect(
        await const FlutterSecureStorage().read(key: 'anthropic_api_key'),
        isNull,
      );
    });
    await tester.runAsync(db.close);
  });
}
