/// 카테고리. [iconKey]는 category_icons.dart의 키 문자열.
class Category {
  final int? id;
  final String name;
  final String iconKey;
  final int colorValue;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    this.sortOrder = 0,
  });

  Category copyWith({
    String? name,
    String? iconKey,
    int? colorValue,
    int? sortOrder,
  }) => Category(
    id: id,
    name: name ?? this.name,
    iconKey: iconKey ?? this.iconKey,
    colorValue: colorValue ?? this.colorValue,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'icon_key': iconKey,
    'color_value': colorValue,
    'sort_order': sortOrder,
  };

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as int,
    name: m['name'] as String,
    iconKey: m['icon_key'] as String,
    colorValue: m['color_value'] as int,
    sortOrder: m['sort_order'] as int,
  );
}

/// 결제 내역 1건. [spentAt]은 날짜만 의미가 있음(시각은 무시).
/// [categoryId]가 null이면 미분류.
class Expense {
  final int? id;
  final String itemName;
  final int amount;
  final DateTime spentAt;
  final int? categoryId;
  final int? sourceImageId;
  final String? merchant;
  final String? memo;

  const Expense({
    this.id,
    required this.itemName,
    required this.amount,
    required this.spentAt,
    this.categoryId,
    this.sourceImageId,
    this.merchant,
    this.memo,
  });

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'item_name': itemName,
    'amount': amount,
    'spent_at': dateKey(spentAt),
    'category_id': categoryId,
    'source_image_id': sourceImageId,
    'merchant': merchant,
    'memo': memo,
  };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int,
    itemName: m['item_name'] as String,
    amount: m['amount'] as int,
    spentAt: DateTime.parse(m['spent_at'] as String),
    categoryId: m['category_id'] as int?,
    sourceImageId: m['source_image_id'] as int?,
    merchant: m['merchant'] as String?,
    memo: m['memo'] as String?,
  );
}

/// DB에 저장하는 날짜 문자열(yyyy-MM-dd). 문자열 비교로 기간 조회가 가능.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 카테고리별 월 합계. [category]가 null이면 미분류.
class CategoryTotal {
  final Category? category;
  final int total;
  final int count;

  const CategoryTotal({
    required this.category,
    required this.total,
    required this.count,
  });
}

/// 카테고리 자동 분류 규칙: 품목명·구매처에 [keyword]가 들어 있으면 [categoryId]로 분류.
class CategoryRule {
  final int? id;
  final int categoryId;
  final String keyword;

  const CategoryRule({
    this.id,
    required this.categoryId,
    required this.keyword,
  });

  factory CategoryRule.fromMap(Map<String, Object?> m) => CategoryRule(
    id: m['id'] as int,
    categoryId: m['category_id'] as int,
    keyword: m['keyword'] as String,
  );
}

/// 앱 폴더에 저장된 영수증/결제 화면 원본 사진.
class SourceImage {
  final int? id;
  final String filePath;
  final String? rawText;

  const SourceImage({this.id, required this.filePath, this.rawText});

  factory SourceImage.fromMap(Map<String, Object?> m) => SourceImage(
    id: m['id'] as int,
    filePath: m['file_path'] as String,
    rawText: m['raw_text'] as String?,
  );
}
