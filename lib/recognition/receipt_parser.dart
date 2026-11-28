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

/// 결제 총액을 뜻하는 줄. (비교할 때는 띄어쓰기를 지우므로 '합 계'도 '합계'로 본다)
const _totalWords = [
  '합계',
  '총액',
  '총결제',
  '결제금액',
  '결제액',
  '결제대상',
  '청구액',
  '청구금액',
  '최종',
  '받을금액',
  '판매총액',
  '총금액',
  '주문금액',
  '총주문',
  '결제예정',
];

/// 실제로 낸 돈을 뜻하는 총액 줄. 있으면 '합계'보다 먼저 쓴다(할인 전 합계와 헷갈리지 않게).
const _paidWords = [
  '총결제',
  '결제금액',
  '결제액',
  '결제대상',
  '청구액',
  '청구금액',
  '받을금액',
  '결제예정',
];

/// 품목이 아닌 금액 줄(할인, 배송비, 세금, 카드 정보 등).
const _skipWords = [
  '할인',
  '쿠폰',
  '적립',
  '포인트',
  '배송비',
  '배달비',
  '부가세',
  '부가가치세',
  '과세물품',
  '면세물품',
  '물품가액',
  '공급가',
  '순매출',
  '봉사료',
  '거스름',
  '받은금액',
  '잔액',
  '잔여',
  '승인',
  '카드번호',
  '신용카드',
  '체크카드',
  '카드결제',
  '카드매출',
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
  '판매계',
];

/// 할인 줄. 바로 위 품목의 금액에서 뺀다.
const _discountWords = ['할인', '쿠폰'];

/// 품목 목록이 시작됨을 알리는 머리줄.
const _headerWords = ['상품명', '품명', '메뉴', '상품'];

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

/// 금액 후보: 앞에 ₩, 뒤에 '원'이 붙을 수 있고 천 단위는 쉼표(가끔 OCR이 점으로 읽음)로 나뉜다.
final _amountRe = RegExp(
  r'(?<![\d.,])(-?)(₩\s*)?(\d{1,3}(?:[,.]\d{3})+|\d+)(?:\s*(원))?',
);
final _letterRe = RegExp(r'[가-힣a-zA-Z]');
final _hangulRe = RegExp(r'[가-힣]');

/// 줄의 금액들(부호 포함). 쉼표/점 구분이 있거나 ₩·'원'이 붙은 숫자만 금액으로 본다
/// (전화번호·날짜·바코드 제외).
List<int> _signedAmountsIn(String line) {
  final out = <int>[];
  for (final m in _amountRe.allMatches(line)) {
    final digits = m.group(3)!;
    final hasSep = digits.contains(',') || digits.contains('.');
    final hasWon = m.group(2) != null || m.group(4) != null;
    // 줄 끝의 음수(할 인 액 -780)는 쉼표가 없어도 할인 금액으로 본다
    final negAtEnd =
        m.group(1) == '-' &&
        m.end == line.length &&
        (m.start == 0 || line[m.start - 1] == ' ');
    if (!hasSep && !hasWon && !negAtEnd) continue;
    // 바로 뒤가 %, 점수(점), 소수점이면 금액이 아님 (예: 10.00%, 13,369.56점)
    final rest = line.substring(m.end);
    if (rest.startsWith('%') || rest.startsWith('점')) continue;
    if (RegExp(r'^[.,]\d').hasMatch(rest)) continue;
    final v = int.parse(digits.replaceAll(RegExp(r'[,.]'), ''));
    if (v <= 0 || v > 100000000) continue;
    out.add(m.group(1) == '-' ? -v : v);
  }
  return out;
}

List<int> _amountsIn(String line) =>
    _signedAmountsIn(line).where((v) => v > 0).toList();

/// 띄어쓰기를 지운 소문자. '합 계', '부 가 세'처럼 벌려 찍힌 글자도 같은 말로 본다.
String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

bool _containsAny(String line, List<String> words) {
  final l = _squash(line);
  return words.any((w) => l.contains(_squash(w)));
}

/// 품목명 뒤에 붙는 단가·수량·금액 칸 하나.
final _numberCellRe = RegExp(
  r'^[(]?-?₩?[\d,.]+(원|개|ea|EA)?[)]?$|^[xX×]\d+$|^T$|^\d+%$',
);

/// 줄에서 금액·수량·기호·상품코드를 걷어낸 품목명 후보.
String _nameOf(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  while (tokens.isNotEmpty && _numberCellRe.hasMatch(tokens.last)) {
    tokens.removeLast();
  }
  // 맨 앞의 긴 숫자(바코드·상품코드)는 이름이 아님
  if (tokens.isNotEmpty && RegExp(r'^\d{6,}$').hasMatch(tokens.first)) {
    tokens.removeAt(0);
  }
  return tokens
      .join(' ')
      .replaceAll(RegExp(r'^\d{1,3}\)\s*'), '') // 001) 1)
      .replaceAll(RegExp(r'^\d{1,2}\s+'), '') // 01 품목
      .replaceAll(RegExp(r'^[\s*+>·•\-:|└▶]+'), '')
      .trim();
}

bool _looksLikeName(String s) {
  if (_letterRe.allMatches(s).length < 2) return false;
  if (_containsAny(s, _notNameWords)) return false;
  // 한글 없이 영문+숫자로만 된 한 덩어리(DY1025001 같은 상품코드)는 이름이 아님
  if (!_hangulRe.hasMatch(s) && !s.contains(' ') && RegExp(r'\d').hasMatch(s)) {
    return false;
  }
  return true;
}

/// '포장비 100', 'COS 쇼핑백 100'처럼 쉼표 없는 세 자리 금액이 줄 끝에 있는 경우.
int? _smallTrailingAmount(String line) {
  final m = RegExp(r'[가-힣a-zA-Z)]\s+(\d{3})$').firstMatch(line);
  if (m == null) return null;
  final v = int.parse(m[1]!);
  return v % 10 == 0 ? v : null;
}

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
  final paidTotals = <int>[];
  final otherTotals = <int>[];

  // 마지막 품목 바로 뒤에 할인 줄이 오면 그 품목 금액에서 뺀다.
  var canDiscount = false;
  // 품목 목록이 시작됐는지(머리줄을 봤거나 품목을 하나 찾음)
  var inItems = false;
  // 합계·소계 줄이 나오면 그 뒤로는 품목이 아니다(카드·포인트 안내 등).
  var itemsClosed = false;

  String? nameAbove(int i) {
    for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
      final prev = lines[j];
      if (_amountsIn(prev).isNotEmpty) break;
      if (_containsAny(prev, _totalWords) || _containsAny(prev, _headerWords)) {
        break;
      }
      final candidate = _nameOf(prev);
      if (_looksLikeName(candidate)) return candidate;
    }
    return null;
  }

  bool isNamelessAmountLine(String line) =>
      _amountsIn(line).isNotEmpty &&
      !_containsAny(line, _totalWords) &&
      !_containsAny(line, _skipWords) &&
      !_looksLikeName(_nameOf(line));

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final squashed = _squash(line);
    final signed = _signedAmountsIn(line);
    final amounts = signed.where((v) => v > 0).toList();
    final isTotal = _containsAny(line, _totalWords);

    if (isTotal) {
      (_containsAny(line, _paidWords) ? paidTotals : otherTotals).addAll(
        amounts,
      );
    }
    if (itemsClosed) continue;
    if (isTotal || squashed.startsWith('소계')) {
      if (items.isNotEmpty) itemsClosed = true;
      canDiscount = false;
      continue;
    }
    if (!inItems &&
        amounts.isEmpty &&
        _headerWords.any((w) => squashed.startsWith(w))) {
      inItems = true;
      continue;
    }

    // 할인 줄: '-3,100' 또는 '할인 30% -40,500 94,500'
    final negatives = signed.where((v) => v < 0).toList();
    if (negatives.isNotEmpty || _containsAny(line, _discountWords)) {
      if (canDiscount && negatives.isNotEmpty && items.isNotEmpty) {
        final last = items.removeLast();
        final after = amounts.isNotEmpty && amounts.last < last.amount
            ? amounts.last
            : last.amount + negatives.first;
        items.add(ParsedItem(last.name, after > 0 ? after : last.amount));
      }
      canDiscount = false;
      continue;
    }
    if (_containsAny(line, _skipWords)) {
      canDiscount = false;
      continue;
    }

    if (amounts.isEmpty) {
      // 쉼표 없는 작은 금액(포장비 100). 다음 줄이 금액만 있는 줄이면 이 줄은 품목명이다.
      final small = inItems ? _smallTrailingAmount(line) : null;
      final nextIsAmountOnly =
          i + 1 < lines.length && isNamelessAmountLine(lines[i + 1]);
      if (small != null && !nextIsAmountOnly) {
        final name = _nameOf(line);
        if (_looksLikeName(name)) {
          items.add(ParsedItem(name, small));
          canDiscount = true;
        }
      }
      continue;
    }

    // 같은 줄에 단가·수량·금액이 함께 있으면 마지막 값이 그 품목의 금액
    final amount = amounts.last;
    var name = _nameOf(line);
    if (!_looksLikeName(name)) {
      // 금액만 있는 줄이면 바로 위의 품목명 줄을 찾는다 (옵션 줄은 건너뜀)
      name = nameAbove(i) ?? '';
    }
    if (name.isEmpty) continue;
    items.add(ParsedItem(name, amount));
    inItems = true;
    canDiscount = true;
  }

  int? maxOf(List<int> l) =>
      l.isEmpty ? null : l.reduce((a, b) => a > b ? a : b);
  return ParsedReceipt(
    date: _parseDate(lines, today),
    merchant: _parseMerchant(lines),
    items: items,
    total: maxOf(paidTotals) ?? maxOf(otherTotals),
  );
}
