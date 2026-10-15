import 'dart:io';

import 'package:budget_app/data/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('1단계 버전 DB를 열면 분류 키워드 표가 추가된다', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('budget');
    final path = '${dir.path}/old.db';
    // 1단계 버전 구조로 DB 만들기
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon_key TEXT NOT NULL, color_value INTEGER NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE source_images (id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT NOT NULL, type TEXT NOT NULL, raw_text TEXT, created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, item_name TEXT NOT NULL, amount INTEGER NOT NULL, spent_at TEXT NOT NULL, category_id INTEGER, source_image_id INTEGER, merchant TEXT, memo TEXT, created_at TEXT)',
          );
          await db.insert('categories', {
            'name': '교통',
            'icon_key': 'subway',
            'color_value': 1,
            'sort_order': 0,
          });
          await db.insert('categories', {
            'name': '내가 만든 것',
            'icon_key': 'pets',
            'color_value': 1,
            'sort_order': 1,
          });
        },
      ),
    );
    await old.close();

    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final cats = await db.categories();
    expect(await db.keywordsFor(cats.first.id!), contains('택시'));
    expect(await db.keywordsFor(cats.last.id!), isEmpty);
    await db.close();
    await dir.delete(recursive: true);
  });
}
