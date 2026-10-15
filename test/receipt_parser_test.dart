import 'package:budget_app/recognition/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 15);

  test('편의점 종이 영수증: 품목, 합계, 날짜를 읽는다', () {
    final r = parseReceipt([
      'GS25 역삼점',
      '사업자 123-45-67890 전화 02-123-4567',
      '2026-10-14 18:32',
      '상품명 수량 금액',
      '삼각김밥 참치 1 1,500',
      '바나나우유 2 3,400',
      '과세물품 4,450',
      '부가세 450',
      '합계 4,900',
      '신용카드 4,900',
    ], now: now);
    expect(r.date, DateTime(2026, 10, 14));
    expect(r.merchant, 'GS25');
    expect(r.items.map((e) => (e.name, e.amount)), [
      ('삼각김밥 참치', 1500),
      ('바나나우유', 3400),
    ]);
    expect(r.total, 4900);
  });

  test('쇼핑앱 주문 화면: 금액만 있는 줄은 위 품목명과 묶고 옵션 줄은 건너뛴다', () {
    final r = parseReceipt([
      '에이블리',
      '주문일자 2026.10.03',
      '루즈핏 케이블 니트 가디건',
      '옵션: 아이보리 / FREE · 1개',
      '29,900원',
      '와이드 데님 팬츠',
      '옵션: 연청 / M · 1개',
      '32,000원',
      '배송비 0원',
      '쿠폰 할인 -3,000원',
      '총 결제금액 58,900원',
    ], now: now);
    expect(r.merchant, '에이블리');
    expect(r.date, DateTime(2026, 10, 3));
    expect(r.items.map((e) => (e.name, e.amount)), [
      ('루즈핏 케이블 니트 가디건', 29900),
      ('와이드 데님 팬츠', 32000),
    ]);
    expect(r.total, 58900);
  });

  test('쿠팡 화면: 월·일만 있으면 올해 날짜로, 미래면 작년으로', () {
    final r = parseReceipt([
      'coupang',
      '10.12(일) 도착',
      '곰곰 무농약 바나나 1.2kg, 1개',
      '4,980원',
    ], now: now);
    expect(r.merchant, '쿠팡');
    expect(r.date, DateTime(2026, 10, 12));
    expect(r.items.single.name, contains('바나나'));
    expect(r.items.single.amount, 4980);

    final r2 = parseReceipt(['12월 24일 결제', '케이크 35,000원'], now: now);
    expect(r2.date, DateTime(2025, 12, 24));
  });

  test('품목을 못 찾으면 합계만 남긴다', () {
    final r = parseReceipt(['스타벅스', '결제금액', '총 결제금액 6,500원'], now: now);
    expect(r.items, isEmpty);
    expect(r.total, 6500);
    expect(r.merchant, '스타벅스');
  });

  test('전화번호·주문번호·날짜 숫자는 금액으로 보지 않는다', () {
    final r = parseReceipt([
      '주문번호 20261015123456',
      '010-1234-5678',
      '2026.10.15',
    ], now: now);
    expect(r.items, isEmpty);
    expect(r.total, isNull);
  });
}
