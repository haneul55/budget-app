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

  test('띄어 찍힌 합 계·부 가 세, 합계 뒤 카드·포인트 줄은 품목이 아니다', () {
    final r = parseReceipt([
      '상품명 수량 금액',
      '유니클로(과세) 1 60,000',
      '소 계 60,000',
      '부 가 세 5,454',
      '합 계 60,000',
      '카드 결제액 60,000',
      '명품 잔여 7,483점',
    ], now: now);
    expect(r.items.map((e) => (e.name, e.amount)), [('유니클로(과세)', 60000)]);
    expect(r.total, 60000);
  });

  test('할인 줄은 바로 위 품목 금액에서 빼고, 낸 돈(결제액)을 합계로 쓴다', () {
    final r = parseReceipt([
      '*메이플 페스타 6팩 1 20,100',
      '메이플 페스타 6팩 -3,100',
      '001)포켓 물티슈 8개입 SET',
      'DY1025001 3,900 1 3,900',
      '할 인 액 -780',
      '행사 할인 -780',
      '총 합 계 액 24,000',
      '결 제 액 20,120',
    ], now: now);
    expect(r.items.map((e) => (e.name, e.amount)), [
      ('메이플 페스타 6팩', 17000),
      ('포켓 물티슈 8개입 SET', 3120),
    ]);
    expect(r.total, 20120);
  });

  test('₩ 금액, 점으로 찍힌 천 단위, 쉼표 없는 작은 금액을 읽는다', () {
    final r = parseReceipt([
      '메뉴 수량 금액',
      '리코타 샐러드 1 15.800',
      'Shopping bag ₩100 T',
      '포장비 100',
      '결제금액 16.000',
    ], now: now);
    expect(r.items.map((e) => (e.name, e.amount)), [
      ('리코타 샐러드', 15800),
      ('Shopping bag', 100),
      ('포장비', 100),
    ]);
    expect(r.total, 16000);
  });
}
