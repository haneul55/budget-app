import 'package:flutter/material.dart';

import '../../data/category_icons.dart';
import '../../data/models.dart';

/// 카테고리 아이콘 원형 배지. [category]가 null이면 미분류.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 40});

  final Category? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = category == null ? Colors.grey : Color(category!.colorValue);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(
        category == null ? Icons.help_outline : iconFor(category!.iconKey),
        color: color,
        size: size * 0.55,
      ),
    );
  }
}

String categoryName(Category? c) => c?.name ?? '미분류';
