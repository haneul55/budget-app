import 'package:budget_app/data/database.dart';
import 'package:budget_app/data/models.dart';
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
  });
  tearDown(() => db.close());

  test('기본 카테고리 7개가 들어간다', () async {
    final cats = await db.categories();
    expect(cats.map((c) => c.name), defaultCategories.map((c) => c.name));
  });

  test('월별·카테고리별 합계를 계산한다', () async {
    final food = (await db.categories()).first;
    await db.addExpense(
      Expense(
        itemName: '김밥',
        amount: 3500,
        spentAt: DateTime(2026, 10, 1),
        categoryId: food.id,
      ),
    );
    await db.addExpense(
      Expense(
        itemName: '라면',
        amount: 1500,
        spentAt: DateTime(2026, 10, 31),
        categoryId: food.id,
      ),
    );
    await db.addExpense(
      Expense(
        itemName: '지난달',
        amount: 9999,
        spentAt: DateTime(2026, 9, 30),
        categoryId: food.id,
      ),
    );
    await db.addExpense(
      Expense(itemName: '분류없음', amount: 700, spentAt: DateTime(2026, 10, 5)),
    );

    final totals = await db.categoryTotals(DateTime(2026, 10));
    expect(totals[food.id], (total: 5000, count: 2));
    expect(totals[null], (total: 700, count: 1));
    expect(
      (await db.expensesInMonth(
        DateTime(2026, 10),
        categoryId: food.id,
      )).map((e) => e.itemName),
      ['라면', '김밥'],
    );
  });

  test('카테고리를 지우면 내역은 미분류로 남는다', () async {
    final food = (await db.categories()).first;
    await db.addExpense(
      Expense(
        itemName: '김밥',
        amount: 3500,
        spentAt: DateTime(2026, 10, 1),
        categoryId: food.id,
      ),
    );
    await db.deleteCategory(food.id!);
    final rest = await db.expensesInMonth(
      DateTime(2026, 10),
      uncategorizedOnly: true,
    );
    expect(rest.single.itemName, '김밥');
  });

  test('새 카테고리는 맨 뒤에 추가되고 순서를 바꿀 수 있다', () async {
    final id = await db.addCategory(
      const Category(name: '반려동물', iconKey: 'pets', colorValue: 0xFF81C784),
    );
    var cats = await db.categories();
    expect(cats.last.id, id);
    await db.reorderCategories([
      id,
      ...cats.where((c) => c.id != id).map((c) => c.id!),
    ]);
    cats = await db.categories();
    expect(cats.first.name, '반려동물');
  });
}
