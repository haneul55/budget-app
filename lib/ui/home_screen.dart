import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'app_theme.dart';
import 'category_detail_screen.dart';
import 'expense_form_screen.dart';
import 'receipt_review_screen.dart';
import 'widgets/category_avatar.dart';
import 'widgets/spending_charts.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);

    return Scaffold(
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (totals) => _SummaryList(totals: totals),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('내역 추가'),
        onPressed: () => _showAddOptions(context),
      ),
    );
  }

  Future<void> _showAddOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진·캡처에서 불러오기'),
              subtitle: const Text('영수증이나 결제 내역 화면 캡처'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('영수증 촬영하기'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('직접 입력하기'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'manual') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptReviewScreen(imagePath: picked.path),
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
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(16),
          ),
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
        const _DailyChartCard(),
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
                color: categoryColor(t.category),
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

/// 이번 달 날짜별 쓴 돈 꺾은선 그래프 (일별 / 누적 전환).
class _DailyChartCard extends ConsumerStatefulWidget {
  const _DailyChartCard();

  @override
  ConsumerState<_DailyChartCard> createState() => _DailyChartCardState();
}

class _DailyChartCardState extends ConsumerState<_DailyChartCard> {
  bool _cumulative = false;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final daily = ref.watch(dailyTotalsProvider).value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: false, label: Text('일별')),
              ButtonSegment(value: true, label: Text('누적')),
            ],
            selected: {_cumulative},
            onSelectionChanged: (v) => setState(() => _cumulative = v.first),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: daily == null
                ? const SizedBox.shrink()
                : DailyLineChart(
                    month: month,
                    dailyTotals: daily,
                    cumulative: _cumulative,
                  ),
          ),
        ],
      ),
    );
  }
}
