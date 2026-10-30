import 'package:sqflite/sqflite.dart';

import 'category_icons.dart';
import 'default_rules.dart';
import 'models.dart';

/// 처음 설치할 때 넣는 기본 카테고리 (모두 수정·삭제 가능).
const defaultCategories = [
  Category(
    name: '식비',
    iconKey: 'restaurant',
    colorValue: 0xFFF4A28C,
    sortOrder: 0,
  ),
  Category(
    name: '카페/간식',
    iconKey: 'local_cafe',
    colorValue: 0xFFB89A86,
    sortOrder: 1,
  ),
  Category(
    name: '쇼핑',
    iconKey: 'shopping_bag',
    colorValue: 0xFFE8A0B4,
    sortOrder: 2,
  ),
  Category(
    name: '생활/마트',
    iconKey: 'shopping_cart',
    colorValue: 0xFF9CCFC0,
    sortOrder: 3,
  ),
  Category(
    name: '교통',
    iconKey: 'directions_bus',
    colorValue: 0xFF9DB4D3,
    sortOrder: 4,
  ),
  Category(
    name: '문화/여가',
    iconKey: 'movie',
    colorValue: 0xFFB9A7D3,
    sortOrder: 5,
  ),
  Category(name: '기타', iconKey: 'more', colorValue: 0xFFB5AEA6, sortOrder: 6),
];

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 3;

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
        onUpgrade: _onUpgrade,
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
    await _createRules(db);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) await _createRules(db);
    if (from < 3) {
      // v3: 앱 디자인을 따뜻한 톤으로 바꾸면서 카테고리 색도 새 팔레트로 옮긴다
      for (final MapEntry(key: oldColor, value: newColor)
          in legacyColorMap.entries) {
        await db.update(
          'categories',
          {'color_value': newColor},
          where: 'color_value = ?',
          whereArgs: [oldColor],
        );
      }
    }
  }

  /// v2: 카테고리 자동 분류 키워드 테이블. 키워드 하나는 한 카테고리에만 속한다.
  static Future<void> _createRules(Database db) async {
    await db.execute('''
      CREATE TABLE category_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
        keyword TEXT NOT NULL UNIQUE
      )''');
    final cats = await db.query('categories');
    for (final c in cats) {
      for (final k in defaultRuleKeywords[c['name']] ?? const <String>[]) {
        await db.insert('category_rules', {
          'category_id': c['id'],
          'keyword': k,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
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

  // ---- 분류 규칙 ----

  Future<List<CategoryRule>> rules() async {
    final rows = await _db.query('category_rules', orderBy: 'id');
    return rows.map(CategoryRule.fromMap).toList();
  }

  Future<List<String>> keywordsFor(int categoryId) async {
    final rows = await _db.query(
      'category_rules',
      columns: ['keyword'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'id',
    );
    return rows.map((r) => r['keyword'] as String).toList();
  }

  /// [categoryId]의 키워드를 [keywords]로 바꾼다. 다른 카테고리에 있던 같은 키워드는 이쪽으로 옮겨진다.
  Future<void> setKeywords(int categoryId, List<String> keywords) =>
      _db.transaction((txn) async {
        await txn.delete(
          'category_rules',
          where: 'category_id = ?',
          whereArgs: [categoryId],
        );
        for (final k in keywords.map(normalizeKeyword).toSet()) {
          if (k.isEmpty) continue;
          await txn.insert('category_rules', {
            'category_id': categoryId,
            'keyword': k,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

  /// 사용자가 고른 카테고리를 기억한다: 다음부터 같은 품목명은 이 카테고리로 분류.
  Future<void> learnKeyword(String keyword, int categoryId) async {
    final k = normalizeKeyword(keyword);
    if (k.length < 2) return;
    await _db.insert('category_rules', {
      'category_id': categoryId,
      'keyword': k,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- 원본 사진 ----

  Future<int> addSourceImage(String filePath, {String? rawText}) =>
      _db.insert('source_images', {
        'file_path': filePath,
        'type': 'photo',
        'raw_text': rawText,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<SourceImage?> sourceImage(int id) async {
    final rows = await _db.query(
      'source_images',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : SourceImage.fromMap(rows.first);
  }

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

  /// [month]의 날짜별 합계: 1일부터 말일까지 순서대로(쓴 돈이 없는 날은 0).
  Future<List<int>> dailyTotals(DateTime month) async {
    final (start, end) = _monthRange(month);
    final rows = await _db.rawQuery(
      '''
      SELECT spent_at, SUM(amount) AS total
      FROM expenses WHERE spent_at >= ? AND spent_at < ?
      GROUP BY spent_at''',
      [start, end],
    );
    final days = DateTime(month.year, month.month + 1, 0).day;
    final out = List<int>.filled(days, 0);
    for (final r in rows) {
      final day = DateTime.parse(r['spent_at'] as String).day;
      out[day - 1] = r['total'] as int;
    }
    return out;
  }

  /// [lastMonth]까지 [count]개월의 월 합계를 오래된 달부터 순서대로.
  Future<List<({DateTime month, int total})>> monthlyTotals(
    DateTime lastMonth, {
    int count = 12,
  }) async {
    final first = DateTime(lastMonth.year, lastMonth.month - count + 1);
    final end = DateTime(lastMonth.year, lastMonth.month + 1);
    final rows = await _db.rawQuery(
      '''
      SELECT substr(spent_at, 1, 7) AS ym, SUM(amount) AS total
      FROM expenses WHERE spent_at >= ? AND spent_at < ?
      GROUP BY ym''',
      [dateKey(first), dateKey(end)],
    );
    final byMonth = {
      for (final r in rows) r['ym'] as String: r['total'] as int,
    };
    return [
      for (var i = 0; i < count; i++)
        () {
          final m = DateTime(first.year, first.month + i);
          final key = dateKey(m).substring(0, 7);
          return (month: m, total: byMonth[key] ?? 0);
        }(),
    ];
  }

  static (String, String) _monthRange(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return (dateKey(start), dateKey(end));
  }
}

/// 키워드 비교용 정규화: 소문자, 앞뒤 공백 제거, 연속 공백 하나로.
String normalizeKeyword(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
