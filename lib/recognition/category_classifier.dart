import '../data/database.dart' show normalizeKeyword;
import '../data/models.dart';

/// 키워드 규칙으로 카테고리를 고른다.
/// 품목명에서 맞는 키워드를 먼저 찾고, 없으면 구매처 이름으로 찾는다.
/// 여러 개가 맞으면 가장 긴(구체적인) 키워드가 이긴다.
class CategoryClassifier {
  CategoryClassifier(List<CategoryRule> rules)
    : _rules = [
        for (final r in rules)
          (
            normalizeKeyword(r.keyword),
            r.categoryId,
            _matcherFor(normalizeKeyword(r.keyword)),
          ),
      ];

  final List<(String, int, bool Function(String))> _rules;

  /// 영문·숫자 키워드(cu, ktx 등)는 단어 경계에서만 맞춘다. 한글은 포함 여부로.
  static bool Function(String) _matcherFor(String keyword) {
    if (RegExp(r'^[a-z0-9 ]+$').hasMatch(keyword)) {
      final re = RegExp('(?<![a-z0-9])${RegExp.escape(keyword)}(?![a-z0-9])');
      return re.hasMatch;
    }
    return (text) => text.contains(keyword);
  }

  int? _bestIn(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final t = normalizeKeyword(text);
    String? bestKeyword;
    int? best;
    for (final (keyword, categoryId, matches) in _rules) {
      if (matches(t) &&
          (bestKeyword == null || keyword.length > bestKeyword.length)) {
        bestKeyword = keyword;
        best = categoryId;
      }
    }
    return best;
  }

  int? classify(String itemName, {String? merchant}) =>
      _bestIn(itemName) ?? _bestIn(merchant);
}

/// 사용자가 고친 카테고리를 기억할 때 쓸 키워드: 대괄호·괄호 안 문구(옵션, 행사)를 뺀 품목명.
String learningKeyword(String itemName) => itemName
    .replaceAll(RegExp(r'\[.*?\]|\(.*?\)'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
