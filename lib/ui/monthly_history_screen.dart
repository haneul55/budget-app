import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../util/format.dart';
import 'app_theme.dart';
import 'widgets/month_picker.dart';
import 'widgets/spending_charts.dart';

/// 고른 달이 속한 해(1~12월)의 월별 누적 금액. 아래의 달 선택 칸을 누르면 달 목록이 펼쳐진다.
class MonthlyHistoryScreen extends ConsumerStatefulWidget {
  const MonthlyHistoryScreen({super.key});

  @override
  ConsumerState<MonthlyHistoryScreen> createState() =>
      _MonthlyHistoryScreenState();
}

class _MonthlyHistoryScreenState extends ConsumerState<MonthlyHistoryScreen> {
  bool _pickerOpen = false;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedMonthProvider);
    final monthly = ref.watch(monthlyTotalsProvider);
    final pickerMonths = ref.watch(pickerMonthsProvider).value ?? const [];
    final theme = Theme.of(context);
    final notifier = ref.read(selectedMonthProvider.notifier);

    int totalOf(DateTime m) {
      for (final e in pickerMonths) {
        if (e.month.year == m.year && e.month.month == m.month) return e.total;
      }
      return 0;
    }

    final total = totalOf(selected);
    final previous = totalOf(DateTime(selected.year, selected.month - 1));

    return Scaffold(
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
                  '${selected.year}년 · 월 평균 ${formatWon(average)}',
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
                    onTapMonth: notifier.select,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 달 선택 칸: 누르면 아래로 달 목록이 펼쳐진다
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _pickerOpen ? AppColors.peachDeep : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _pickerOpen = !_pickerOpen),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: Row(
                            children: [
                              Text(
                                '달 선택',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSub,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatMonth(selected),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _pickerOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.keyboard_arrow_down),
                              ),
                            ],
                          ),
                        ),
                      ),
                      MonthPickerPanel(
                        open: _pickerOpen,
                        months: pickerMonths,
                        selected: selected,
                        maxHeight: 280,
                        onSelected: (m) {
                          notifier.select(m);
                          setState(() => _pickerOpen = false);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MonthSummary(
                month: selected,
                total: total,
                previous: previous,
                onOpen: () =>
                    ref.read(currentTabProvider.notifier).go(AppTab.home),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 고른 달의 합계와 지난달 대비 증감.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.month,
    required this.total,
    required this.previous,
    required this.onOpen,
  });

  final DateTime month;
  final int total;
  final int previous;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? diffText;
    Color? diffColor;
    if (previous > 0 && total > 0) {
      final diff = total - previous;
      if (diff == 0) {
        diffText = '지난달과 같아요';
      } else {
        diffText = '지난달보다 ${formatWon(diff.abs())} ${diff > 0 ? '더' : '덜'} 썼어요';
        diffColor = diff > 0 ? AppColors.more : AppColors.less;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.peachLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatMonth(month)}에 쓴 돈',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              formatWon(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (diffText != null) ...[
              const SizedBox(height: 4),
              Text(diffText, style: TextStyle(color: diffColor)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                child: const Text('이 달 내역 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
