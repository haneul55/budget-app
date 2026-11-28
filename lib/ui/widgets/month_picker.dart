import 'package:flutter/material.dart';

import '../../util/format.dart';
import '../app_theme.dart';

/// "2026년 11월 ▾" 모양의 달 선택 버튼. 누르면 아래에 [MonthPickerPanel]이 펼쳐진다.
class MonthDropdownButton extends StatelessWidget {
  const MonthDropdownButton({
    super.key,
    required this.month,
    required this.expanded,
    required this.onTap,
  });

  final DateTime month;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMonth(month),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달 목록이 위에서 아래로 좌르륵 펼쳐지는 패널. 닫혀 있으면 높이 0.
class MonthPickerPanel extends StatelessWidget {
  const MonthPickerPanel({
    super.key,
    required this.open,
    required this.months,
    required this.selected,
    required this.onSelected,
    this.maxHeight = 300,
  });

  final bool open;

  /// 오래된 달부터 순서대로 (목록에는 최근 달이 위로 오게 뒤집어 보여준다).
  final List<({DateTime month, int total})> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = months.reversed.toList();
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !open
            ? const SizedBox(width: double.infinity)
            : Material(
                color: AppColors.paper,
                shape: const Border(bottom: BorderSide(color: AppColors.line)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final m = items[i];
                      final isSelected =
                          m.month.year == selected.year &&
                          m.month.month == selected.month;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedColor: AppColors.peachText,
                        selectedTileColor: AppColors.peachLight.withValues(
                          alpha: 0.6,
                        ),
                        title: Text(
                          formatMonth(m.month),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : null,
                            color: isSelected ? AppColors.peachText : null,
                          ),
                        ),
                        trailing: Text(
                          m.total == 0 ? '-' : formatWon(m.total),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: m.total == 0
                                ? AppColors.textFaint
                                : AppColors.textSub,
                          ),
                        ),
                        onTap: () => onSelected(m.month),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
