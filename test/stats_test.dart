import 'package:budget_app/data/database.dart';
import 'package:budget_app/data/models.dart';
import 'package:budget_app/ui/widgets/spending_charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    Future<void> add(int amount, DateTime d) =>
        db.addExpense(Expense(itemName: '테스트', amount: amount, spentAt: d));
    await add(3000, DateTime(2026, 9, 30));
    await add(5000, DateTime(2026, 10, 1));
    await add(2000, DateTime(2026, 10, 1));
    await add(7000, DateTime(2026, 10, 31));
    await add(1000, DateTime(2025, 12, 5));
  });
  tearDown(() => db.close());

  test('날짜별 합계는 그 달 일수만큼, 같은 날은 합쳐진다', () async {
    final daily = await db.dailyTotals(DateTime(2026, 10));
    expect(daily.length, 31);
    expect(daily[0], 7000);
    expect(daily[30], 7000);
    expect(daily.fold<int>(0, (s, v) => s + v), 14000);
  });

  test('최근 12개월 월 합계를 오래된 달부터 돌려준다', () async {
    final months = await db.monthlyTotals(DateTime(2026, 10));
    expect(months.length, 12);
    expect(months.first.month, DateTime(2025, 11));
    expect(months.last.month, DateTime(2026, 10));
    expect(months.last.total, 14000);
    expect(months[10].total, 3000); // 9월
    expect(months[1].total, 1000); // 2025년 12월
    expect(months[0].total, 0);
  });

  test('그래프 축 금액 표기', () {
    expect(compactWon(500), '500');
    expect(compactWon(2000), '2천');
    expect(compactWon(2500), '2.5천');
    expect(compactWon(15000), '1.5만');
    expect(compactWon(20000), '2만');
    expect(compactWon(250000), '25만');
  });
}
