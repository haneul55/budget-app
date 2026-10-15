/// 영수증·쇼핑앱 결제 화면에서 읽은 글자 줄들을 규칙으로 해석한다.
/// (OCR과 분리된 순수 Dart 코드라 테스트로 검증할 수 있다)
library;

class ParsedItem {
  final String name;
  final int amount;

  const ParsedItem(this.name, this.amount);

  @override
  String toString() => 'ParsedItem($name, $amount)';
}

class ParsedReceipt {
  final DateTime? date;
  final String? merchant;
  final List<ParsedItem> items;
  final int? total;

  const ParsedReceipt({
    this.date,
    this.merchant,
    this.items = const [],
    this.total,
  });
}

/// 앱·가게 이름 → 표시할 구매처 이름. 위에서부터 먼저 맞는 것을 쓴다.
const _merchants = <(String, String)>[
  ('쿠팡이츠', '쿠팡이츠'),
  ('coupang eats', '쿠팡이츠'),
  ('쿠팡', '쿠팡'),
  ('coupang', '쿠팡'),
  ('스마트스토어', '네이버 스마트스토어'),
  ('네이버페이', '네이버페이'),
  ('naver', '네이버'),
  ('에이블리', '에이블리'),
  ('ably', '에이블리'),
  ('무신사', '무신사'),
  ('musinsa', '무신사'),
  ('지그재그', '지그재그'),
  ('zigzag', '지그재그'),
  ('29cm', '29CM'),
  ('마켓컬리', '컬리'),
  ('컬리', '컬리'),
  ('오늘의집', '오늘의집'),
  ('11번가', '11번가'),
  ('g마켓', 'G마켓'),
  ('지마켓', 'G마켓'),
  ('옥션', '옥션'),
  ('ssg', 'SSG'),
  ('배달의민족', '배달의민족'),
  ('요기요', '요기요'),
  ('올리브영', '올리브영'),
  ('다이소', '다이소'),
  ('스타벅스', '스타벅스'),
  ('이마트', '이마트'),
  ('홈플러스', '홈플러스'),
  ('gs25', 'GS25'),
  ('세븐일레븐', '세븐일레븐'),
];

/// 결제 총액을 뜻하는 줄.
const _totalWords = [
  '합계',
  '총액',
  '총 결제',
  '총결제',
  '결제금액',
  '결제 금액',
  '최종',
  '받을금액',
  '받을 금액',
  '청구금액',
  '판매총액',
  '총금액',
  '총 금액',
  '주문금액',
  '총 주문',
  '결제예정',
];

/// 품목이 아닌 금액 줄(할인, 배송비, 세금, 카드 정보 등).
const _skipWords = [
  '할인',
  '쿠폰',
  '적립',
  '포인트',
  '배송비',
  '부가세',
  '부가가치세',
  '과세',
  '면세',
  '공급가',
  '거스름',
  '받은금액',
  '받은 금액',
  '잔액',
  '승인',
  '카드번호',
  '신용카드',
  '체크카드',
  '카드결제',
  '사업자',
  '전화',
  'tel',
  '주문번호',
  '할부',
  '마일리지',
  '캐시',
  '환불',
  '취소',
  '예상',
  '단가',
  '수량',
  '금액',
  '정가',
  '판매가',
];

/// 품목명 줄로 쓰지 않을 줄(옵션, 배송 안내 등).
const _notNameWords = [
  '옵션',
  '수량',
  '사이즈',
  '색상',
  '배송',
  '도착',
  '구매확정',
  '주문',
  '결제',
  '교환',
  '반품',
  '리뷰',
  '장바구니',
  '판매자',
  '상품정보',
];

final _amountRe = RegExp(r'(-?)(\d{1,3}(?:,\d{3})+|\d+)\s*(원)?');
final _letterRe = RegExp(r'[가-힣a-zA-Z]');

/// 줄에 들어 있는 금액들. 쉼표가 있거나 '원'이 붙은 숫자만 금액으로 본다(전화번호·날짜 제외).
List<int> _amountsIn(String line) {
  final out = <int>[];
  for (final m in _amountRe.allMatches(line)) {
    final digits = m.group(2)!;
    final hasComma = digits.contains(',');
    final hasWon = m.group(3) != null;
    if (!hasComma && !hasWon) continue;
    // 바로 뒤가 숫자/%/. 이면 금액이 아님 (예: 1,5% 같은 경우)
    final after = m.end < line.length ? line[m.end] : '';
    if (after == '%') continue;
    if (m.group(1) == '-') continue; // 할인(음수) 금액
    final v = int.parse(digits.replaceAll(',', ''));
    if (v <= 0 || v > 100000000) continue;
    out.add(v);
  }
  return out;
}

bool _containsAny(String line, List<String> words) {
  final l = line.toLowerCase();
  return words.any(l.contains);
}

/// 줄에서 금액·수량·기호를 걷어낸 품목명 후보.
String _nameOf(String line) {
  var s = line
      .replaceAll(_amountRe, ' ')
      .replaceAll(RegExp(r'\d+\s*(개|ea|EA|매|병|팩|봉)\b'), ' ')
      .replaceAll(RegExp(r'[xX×]\s*\d+'), ' ')
      .replaceAll(RegExp(r'^[\s\d.\-*·•:|]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s;
}

bool _looksLikeName(String s) =>
    _letterRe.allMatches(s).length >= 2 && !_containsAny(s, _notNameWords);

DateTime? _parseDate(List<String> lines, DateTime now) {
  final full = RegExp(r'(20\d{2})\s*[.\-/년]\s*(\d{1,2})\s*[.\-/월]\s*(\d{1,2})');
  final short = RegExp(r'(?<!\d)(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})(?!\d)');
  final monthDay = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  final dotted = RegExp(r'(?<![\d,])(\d{1,2})[./](\d{1,2})\s*\(');

  DateTime? valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    if (date.month != m) return null;
    return date;
  }

  DateTime? withThisYear(int m, int d) {
    final date = valid(now.year, m, d);
    if (date == null) return null;
    // 올해 날짜가 미래면 작년 결제로 본다
    return date.isAfter(now) ? valid(now.year - 1, m, d) : date;
  }

  for (final line in lines) {
    final m = full.firstMatch(line);
    if (m != null) {
      final d = valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) return d;
    }
  }
  for (final line in lines) {
    final m = short.firstMatch(line);
    if (m != null) {
      final d = valid(
        2000 + int.parse(m[1]!),
        int.parse(m[2]!),
        int.parse(m[3]!),
      );
      if (d != null) return d;
    }
  }
  for (final line in lines) {
    final m = monthDay.firstMatch(line) ?? dotted.firstMatch(line);
    if (m != null) {
      final d = withThisYear(int.parse(m[1]!), int.parse(m[2]!));
      if (d != null) return d;
    }
  }
  return null;
}

String? _parseMerchant(List<String> lines) {
  final text = lines.join('\n').toLowerCase();
  for (final (key, name) in _merchants) {
    if (text.contains(key)) return name;
  }
  return null;
}

ParsedReceipt parseReceipt(List<String> rawLines, {DateTime? now}) {
  final lines = rawLines
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final today = now ?? DateTime.now();
  final items = <ParsedItem>[];
  final totals = <int>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final amounts = _amountsIn(line);
    if (amounts.isEmpty) continue;

    if (_containsAny(line, _totalWords)) {
      totals.addAll(amounts);
      continue;
    }
    if (_containsAny(line, _skipWords)) continue;

    // 같은 줄에 단가·수량·금액이 함께 있으면 마지막 값이 그 품목의 금액
    final amount = amounts.last;
    var name = _nameOf(line);
    if (!_looksLikeName(name)) {
      // 금액만 있는 줄이면 바로 위의 품목명 줄을 찾는다 (옵션 줄은 건너뜀)
      name = '';
      for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
        final prev = lines[j];
        if (_amountsIn(prev).isNotEmpty) break;
        final candidate = _nameOf(prev);
        if (_looksLikeName(candidate) && !_containsAny(prev, _totalWords)) {
          name = candidate;
          break;
        }
      }
    }
    if (name.isEmpty) continue;
    items.add(ParsedItem(name, amount));
  }

  final total = totals.isEmpty ? null : totals.reduce((a, b) => a > b ? a : b);
  return ParsedReceipt(
    date: _parseDate(lines, today),
    merchant: _parseMerchant(lines),
    items: items,
    total: total,
  );
}
