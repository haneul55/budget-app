// 실제 한국 영수증 20장(HumynLabs/Korean_Receipts_Dataset, CC BY 4.0)에서
// 손으로 옮긴 글자 줄과 정답으로 영수증 해석 정확도를 잰다.
// 자세한 출처는 test/fixtures/README.md 참고.
import 'dart:convert';
import 'dart:io';

import 'package:budget_app/recognition/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// 품목명 비교용: 공백·앞쪽 기호/번호를 지우고 소문자로.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'^[\s*+>\-\d)]+'), '')
    .replaceAll(RegExp(r'\s+'), '');

bool _sameName(String parsed, String expected) {
  final p = _norm(parsed), e = _norm(expected);
  if (p.length < 2 || e.length < 2) return p == e;
  return p == e || p.contains(e) || e.contains(p);
}

class Score {
  int receipts = 0, dateOk = 0, totalOk = 0, allOk = 0;
  int expectedItems = 0, foundItems = 0, matchedItems = 0;

  double get precision => foundItems == 0 ? 0 : matchedItems / foundItems;
  double get recall => expectedItems == 0 ? 0 : matchedItems / expectedItems;
  double get f1 => precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);

  String pct(num a, num b) => '${(100 * a / b).toStringAsFixed(0)}%';

  @override
  String toString() =>
      '날짜 $dateOk/$receipts (${pct(dateOk, receipts)}), '
      '합계 $totalOk/$receipts (${pct(totalOk, receipts)}), '
      '품목 정답 $matchedItems/$expectedItems, 잘못 찾은 품목 ${foundItems - matchedItems}개 '
      '(F1 ${(f1 * 100).toStringAsFixed(0)}%), '
      '모두 맞은 영수증 $allOk/$receipts';
}

Score scoreDataset(
  List<Map<String, dynamic>> receipts, {
  bool verbose = false,
}) {
  final s = Score();
  for (final r in receipts) {
    final lines = (r['lines'] as List).cast<String>();
    final exp = r['expected'] as Map<String, dynamic>;
    final got = parseReceipt(lines, now: DateTime(2025, 12, 31));

    final expDate = DateTime.parse(exp['date'] as String);
    final dateOk = got.date == expDate;
    final totalOk = got.total == exp['total'];

    final expItems = [
      for (final i in exp['items'] as List)
        (i['name'] as String, i['amount'] as int),
    ];
    final unmatched = [...expItems];
    var matched = 0;
    for (final it in got.items) {
      final k = unmatched.indexWhere(
        (e) => e.$2 == it.amount && _sameName(it.name, e.$1),
      );
      if (k >= 0) {
        matched++;
        unmatched.removeAt(k);
      }
    }
    final itemsOk =
        matched == expItems.length && got.items.length == expItems.length;

    s.receipts++;
    if (dateOk) s.dateOk++;
    if (totalOk) s.totalOk++;
    if (dateOk && totalOk && itemsOk) s.allOk++;
    s.expectedItems += expItems.length;
    s.foundItems += got.items.length;
    s.matchedItems += matched;

    if (verbose && !(dateOk && totalOk && itemsOk)) {
      // ignore: avoid_print
      print(
        '✗ ${r['image']}\n'
        '   날짜 ${got.date} (정답 $expDate)\n'
        '   합계 ${got.total} (정답 ${exp['total']})\n'
        '   품목 ${got.items}\n'
        '   정답 $expItems',
      );
    }
  }
  return s;
}

void main() {
  final data = jsonDecode(
    File('test/fixtures/korean_receipts.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final receipts = (data['receipts'] as List).cast<Map<String, dynamic>>();

  test('한국 영수증 20장 인식 정확도', () {
    final s = scoreDataset(receipts, verbose: true);
    // ignore: avoid_print
    print('정확도: $s');

    // 개선 후 수준이 다시 떨어지지 않도록 지키는 최소 기준
    expect(s.dateOk, s.receipts);
    expect(s.totalOk, greaterThanOrEqualTo(19));
    expect(s.recall, greaterThanOrEqualTo(0.9));
    expect(s.precision, greaterThanOrEqualTo(0.9));
  });
}
