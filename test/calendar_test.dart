import 'package:budget_app/ui/calendar_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2026년 10월: 9월 27일(일)부터 10월 31일(토)까지 5주', () {
    final weeks = calendarWeeks(DateTime(2026, 10));
    expect(weeks.length, 5);
    expect(weeks.first.first, DateTime(2026, 9, 27));
    expect(weeks.first[4], DateTime(2026, 10, 1));
    expect(weeks.last.last, DateTime(2026, 10, 31));
    expect(weeks.every((w) => w.length == 7), isTrue);
  });

  test('일요일에 시작하는 2026년 2월은 딱 4주', () {
    final weeks = calendarWeeks(DateTime(2026, 2));
    expect(weeks.length, 4);
    expect(weeks.first.first, DateTime(2026, 2, 1));
    expect(weeks.last.last, DateTime(2026, 2, 28));
  });

  test('다음 달 날짜로 마지막 주를 채운다', () {
    final weeks = calendarWeeks(DateTime(2026, 11)); // 11월 1일 일요일, 30일 월요일
    expect(weeks.last.first, DateTime(2026, 11, 29));
    expect(weeks.last.last, DateTime(2026, 12, 5));
  });
}
