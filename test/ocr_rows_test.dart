import 'package:budget_app/recognition/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('같은 높이의 품목명과 금액을 한 줄로 합친다', () {
    final rows = mergeIntoRows([
      ('1,500', 300, 102, 120),
      ('삼각김밥', 10, 100, 120),
      ('GS25', 10, 10, 30),
      ('바나나우유', 10, 140, 160),
      ('3,400', 300, 141, 159),
    ]);
    expect(rows, ['GS25', '삼각김밥 1,500', '바나나우유 3,400']);
  });
}
