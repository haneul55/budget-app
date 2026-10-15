import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// 처음 설치할 때 넣는 기본 카테고리 (모두 수정·삭제 가능).
const defaultCategories = [
  Category(
    name: '식비',
    iconKey: 'restaurant',
    colorValue: 0xFFE57373,
    sortOrder: 0,
  ),
  Category(
    name: '카페/간식',
    iconKey: 'local_cafe',
    colorValue: 0xFFA1887F,
    sortOrder: 1,
  ),
  Category(
    name: '쇼핑',
    iconKey: 'shopping_bag',
    colorValue: 0xFFF06292,
    sortOrder: 2,
  ),
  Category(
    name: '생활/마트',
    iconKey: 'shopping_cart',
    colorValue: 0xFF4DB6AC,
    sortOrder: 3,
  ),
  Category(
    name: '교통',
    iconKey: 'directions_bus',
    colorValue: 0xFF64B5F6,
    sortOrder: 4,
  ),
  Category(
    name: '문화/여가',
    iconKey: 'movie',
    colorValue: 0xFF9575CD,
    sortOrder: 5,
  ),
  Category(name: '기타', iconKey: 'more', colorValue: 0xFF90A4AE, sortOrder: 6),
];

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 1;

  /// [factory]와 [path]를 바꿔 끼우면 테스트에서 메모리 DB를 쓸 수 있다.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final p = path ?? '${await f.getDatabasesPath()}/budget.db';
    final db = await f.openDatabase(
      p,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_key TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )''');
    // 영수증/결제 화면 원본 사진. 2단계(사진 첨부)부터 사용.
    await db.execute('''
      CREATE TABLE source_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        type TEXT NOT NULL,
        raw_text TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        spent_at TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        source_image_id INTEGER REFERENCES source_images(id) ON DELETE SET NULL,
        merchant TEXT,
        memo TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )''');
    await db.execute(
      'CREATE INDEX idx_expenses_spent_at ON expenses(spent_at)',
    );
    for (final c in defaultCategories) {
      await db.insert('categories', c.toMap());
    }
  }

  Future<void> close() => _db.close();

  // ---- 카테고리 ----

  Future<List<Category>> categories() async {
    final rows = await _db.query('categories', orderBy: 'sort_order, id');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> addCategory(Category c) async {
    final maxOrder =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT MAX(sort_order) FROM categories'),
        ) ??
        -1;
    return _db.insert(
      'categories',
      c.copyWith(sortOrder: maxOrder + 1).toMap(),
    );
  }

  Future<void> updateCategory(Category c) =>
      _db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  /// 카테고리를 지우면 그 안의 내역은 미분류(category_id = NULL)로 남는다.
  Future<void> deleteCategory(int id) =>
      _db.delete('categories', where: 'id = ?', whereArgs: [id]);

  Future<void> reorderCategories(List<int> idsInOrder) =>
      _db.transaction((txn) async {
        for (var i = 0; i < idsInOrder.length; i++) {
          await txn.update(
            'categories',
            {'sort_order': i},
            where: 'id = ?',
            whereArgs: [idsInOrder[i]],
          );
        }
      });

  // ---- 결제 내역 ----

  Future<int> addExpense(Expense e) => _db.insert('expenses', e.toMap());

  Future<void> updateExpense(Expense e) =>
      _db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  Future<void> deleteExpense(int id) =>
      _db.delete('expenses', where: 'id = ?', whereArgs: [id]);

  /// [month]가 속한 달의 내역. [categoryId]를 주면 그 카테고리만,
  /// [uncategorizedOnly]면 미분류만.
  Future<List<Expense>> expensesInMonth(
    DateTime month, {
    int? categoryId,
    bool uncategorizedOnly = false,
  }) async {
    final (start, end) = _monthRange(month);
    var where = 'spent_at >= ? AND spent_at < ?';
    final args = <Object?>[start, end];
    if (uncategorizedOnly) {
      where += ' AND category_id IS NULL';
    } else if (categoryId != null) {
      where += ' AND category_id = ?';
      args.add(categoryId);
    }
    final rows = await _db.query(
      'expenses',
      where: where,
      whereArgs: args,
      orderBy: 'spent_at DESC, id DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// 카테고리별 월 합계: {categoryId(미분류는 null): (합계, 건수)}.
  Future<Map<int?, ({int total, int count})>> categoryTotals(
    DateTime month,
  ) async {
    final (start, end) = _monthRange(month);
    final rows = await _db.rawQuery(
      '''
      SELECT category_id, SUM(amount) AS total, COUNT(*) AS cnt
      FROM expenses WHERE spent_at >= ? AND spent_at < ?
      GROUP BY category_id''',
      [start, end],
    );
    return {
      for (final r in rows)
        r['category_id'] as int?: (
          total: r['total'] as int,
          count: r['cnt'] as int,
        ),
    };
  }

  static (String, String) _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (dateKey(start), dateKey(end));
  }
}
