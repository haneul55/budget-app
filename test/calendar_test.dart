import 'package:budget_app/ui/calendar_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2026년 10월은 목요일 시작, 앞에 빈칸 4개와 31일', () {
    final cells = calendarDays(DateTime(2026, 10));
    expect(cells.take(4), everyElement(isNull));
    expect(cells[4], DateTime(2026, 10, 1));
    expect(cells.length, 4 + 31);
    expect(cells.last, DateTime(2026, 10, 31));
  });

  test('일요일에 시작하는 달은 빈칸이 없다', () {
    final cells = calendarDays(DateTime(2026, 2)); // 2026-02-01 일요일
    expect(cells.first, DateTime(2026, 2, 1));
    expect(cells.length, 28);
  });
}
