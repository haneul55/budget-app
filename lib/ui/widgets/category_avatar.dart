import 'package:flutter/material.dart';

import '../../data/category_icons.dart';
import '../../data/models.dart';
import '../app_theme.dart';

/// 카테고리 아이콘 원형 배지. [category]가 null이면 미분류.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 40});

  final Category? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.28),
      child: Icon(
        category == null ? Icons.help_outline : iconFor(category!.iconKey),
        // 파스텔 색 그대로면 크림 바탕에서 흐려서 아이콘만 조금 진하게
        color: _deepen(color),
        size: size * 0.55,
      ),
    );
  }
}

String categoryName(Category? c) => c?.name ?? '미분류';

Color categoryColor(Category? c) =>
    c == null ? AppColors.uncategorized : Color(c.colorValue);

Color _deepen(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0)).toColor();
}
