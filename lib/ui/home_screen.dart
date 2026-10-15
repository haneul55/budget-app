import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'category_detail_screen.dart';
import 'category_manage_screen.dart';
import 'expense_form_screen.dart';
import 'widgets/category_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  ref.read(selectedMonthProvider.notifier).previous(),
            ),
            Text(formatMonth(month)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => ref.read(selectedMonthProvider.notifier).next(),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '카테고리 관리',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryManageScreen()),
            ),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (totals) => _SummaryList(totals: totals),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('내역 추가'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ExpenseFormScreen())),
      ),
    );
  }
}

class _SummaryList extends StatelessWidget {
  const _SummaryList({required this.totals});

  final List<CategoryTotal> totals;

  @override
  Widget build(BuildContext context) {
    final sum = totals.fold<int>(0, (s, t) => s + t.total);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이번 달 쓴 돈', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                formatWon(sum),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        for (final t in totals)
          ListTile(
            leading: CategoryAvatar(category: t.category),
            title: Text(categoryName(t.category)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: sum == 0 ? 0 : t.total / sum,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: t.category == null
                    ? Colors.grey
                    : Color(t.category!.colorValue),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatWon(t.total), style: theme.textTheme.titleSmall),
                Text('${t.count}건', style: theme.textTheme.bodySmall),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(category: t.category),
              ),
            ),
          ),
      ],
    );
  }
}
