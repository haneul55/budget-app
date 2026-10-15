import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'expense_form_screen.dart';
import 'widgets/category_avatar.dart';

/// 카테고리 안의 결제 내역 목록. [category]가 null이면 미분류.
class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({super.key, required this.category});

  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final expenses = ref.watch(categoryExpensesProvider(category?.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(category: category, size: 28),
            const SizedBox(width: 8),
            Text('${categoryName(category)} · ${month.month}월'),
          ],
        ),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('이번 달 내역이 없어요'));
          }
          final total = list.fold<int>(0, (s, e) => s + e.amount);
          return ListView.separated(
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return ListTile(
                  title: const Text('합계'),
                  trailing: Text(
                    formatWon(total),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }
              final e = list[i - 1];
              return ListTile(
                title: Text(e.itemName),
                subtitle: Text(
                  [
                    formatDay(e.spentAt),
                    if (e.merchant != null) e.merchant!,
                  ].join(' · '),
                ),
                trailing: Text(formatWon(e.amount)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExpenseFormScreen(initial: e),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
