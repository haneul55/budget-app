import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../util/format.dart';
import 'app_theme.dart';
import 'widgets/spending_charts.dart';

/// 최근 12개월의 월별 누적 금액. 달을 누르면 그 달로 이동한다.
class MonthlyHistoryScreen extends ConsumerWidget {
  const MonthlyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final monthly = ref.watch(monthlyTotalsProvider);
    final theme = Theme.of(context);

    void open(DateTime m) {
      ref.read(selectedMonthProvider.notifier).select(m);
      Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('월별 기록')),
      body: monthly.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (months) {
          final withData = months.where((m) => m.total > 0).toList();
          final average = withData.isEmpty
              ? 0
              : withData.fold<int>(0, (s, m) => s + m.total) ~/ withData.length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  '최근 12개월 · 월 평균 ${formatWon(average)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(
                height: 220,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                  child: MonthlyBarChart(
                    months: months,
                    selected: selected,
                    onTapMonth: open,
                  ),
                ),
              ),
              const Divider(height: 32),
              for (var i = months.length - 1; i >= 0; i--)
                _MonthTile(
                  month: months[i].month,
                  total: months[i].total,
                  previous: i > 0 ? months[i - 1].total : null,
                  selected:
                      months[i].month.year == selected.year &&
                      months[i].month.month == selected.month,
                  onTap: () => open(months[i].month),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.total,
    required this.previous,
    required this.selected,
    required this.onTap,
  });

  final DateTime month;
  final int total;
  final int? previous;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? diffText;
    Color? diffColor;
    if (previous != null && previous! > 0 && total > 0) {
      final diff = total - previous!;
      if (diff == 0) {
        diffText = '지난달과 같아요';
      } else {
        diffText = '지난달보다 ${formatWon(diff.abs())} ${diff > 0 ? '더' : '덜'} 썼어요';
        diffColor = diff > 0 ? AppColors.more : AppColors.less;
      }
    }
    return ListTile(
      selected: selected,
      title: Text(formatMonth(month)),
      subtitle: diffText == null
          ? null
          : Text(diffText, style: TextStyle(color: diffColor)),
      trailing: Text(
        total == 0 ? '-' : formatWon(total),
        style: theme.textTheme.titleSmall,
      ),
      onTap: onTap,
    );
  }
}
