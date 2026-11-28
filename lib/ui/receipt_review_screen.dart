import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_store.dart';
import '../data/models.dart';
import '../recognition/ai_classifier.dart';
import '../recognition/category_classifier.dart';
import '../recognition/ocr_service.dart';
import '../recognition/receipt_parser.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'widgets/category_avatar.dart';
import 'widgets/source_image_view.dart';

/// 사진에서 읽은 내역을 보여주고, 저장 전에 품목·금액·날짜·카테고리를 고칠 수 있는 화면.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _Draft {
  _Draft({String name = '', int? amount, this.categoryId})
    : suggestedCategoryId = categoryId,
      name = TextEditingController(text: name),
      amount = TextEditingController(text: amount?.toString() ?? '');

  final TextEditingController name;
  final TextEditingController amount;

  /// 키워드 규칙이 고른 카테고리.
  final int? suggestedCategoryId;

  /// 규칙으로 못 고른 품목에 AI가 고른 카테고리.
  int? aiCategoryId;
  int? categoryId;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _aiPending = false;
  String? _notice;
  String? _rawText;
  String? _merchant;
  int? _total;
  DateTime _date = DateTime.now();
  final _drafts = <_Draft>[];

  @override
  void initState() {
    super.initState();
    _recognize();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _recognize() async {
    var lines = <String>[];
    final ocr = OcrService();
    try {
      lines = await ocr.readLines(widget.imagePath);
    } catch (_) {
      _notice = '사진에서 글자를 읽지 못했어요. 아래에 직접 입력해 주세요.';
    } finally {
      await ocr.close();
    }

    final parsed = parseReceipt(lines);
    final classifier = CategoryClassifier(await ref.read(rulesProvider.future));
    var items = parsed.items;
    if (items.isEmpty && parsed.total != null) {
      items = [ParsedItem(parsed.merchant ?? '결제 내역', parsed.total!)];
    }

    if (!mounted) return;
    setState(() {
      _rawText = lines.join('\n');
      _merchant = parsed.merchant;
      _total = parsed.total;
      _date = parsed.date ?? DateTime.now();
      for (final it in items) {
        _drafts.add(
          _Draft(
            name: it.name,
            amount: it.amount,
            categoryId: classifier.classify(it.name, merchant: parsed.merchant),
          ),
        );
      }
      if (_drafts.isEmpty) {
        _drafts.add(_Draft());
        _notice ??= '품목과 금액을 찾지 못했어요. 아래에 직접 입력해 주세요.';
      }
      _loading = false;
    });
    await _askAi();
  }

  /// 규칙으로 못 고른 품목만 AI 서버에 물어본다. 설정이 없거나 실패하면 미분류 그대로.
  Future<void> _askAi() async {
    final config = await ref.read(aiConfigProvider.future);
    final categories = await ref.read(categoriesProvider.future);
    final pending = [
      for (final d in _drafts)
        if (d.categoryId == null && d.name.text.trim().isNotEmpty) d,
    ];
    if (config == null || pending.isEmpty || categories.isEmpty || !mounted) {
      return;
    }
    setState(() => _aiPending = true);
    final picks = await AiCategoryClassifier(config).classify([
      for (final d in pending) (name: d.name.text.trim(), merchant: _merchant),
    ], categories);
    if (!mounted) return;
    setState(() {
      _aiPending = false;
      for (var i = 0; i < pending.length; i++) {
        final d = pending[i];
        // 그사이 사용자가 직접 고른 항목은 건드리지 않는다
        if (picks[i] == null || d.categoryId != null) continue;
        d.aiCategoryId = picks[i];
        d.categoryId = picks[i];
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    for (final d in _drafts) {
      if (d.name.text.trim().isEmpty ||
          (int.tryParse(d.amount.text) ?? 0) <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모든 항목에 품목과 금액을 입력해 주세요')));
        return;
      }
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final storedPath = await saveReceiptImage(widget.imagePath);
    final imageId = await db.addSourceImage(storedPath, rawText: _rawText);
    var learned = 0;
    for (final d in _drafts) {
      final name = d.name.text.trim();
      await db.addExpense(
        Expense(
          itemName: name,
          amount: int.parse(d.amount.text),
          spentAt: _date,
          categoryId: d.categoryId,
          sourceImageId: imageId,
          merchant: _merchant,
        ),
      );
      // 규칙과 다르게 정해진 카테고리(직접 고쳤거나 AI가 고른 것)는 기억해서
      // 다음부터 같은 품목은 AI에 묻지 않고 바로 분류
      if (d.categoryId != null && d.categoryId != d.suggestedCategoryId) {
        await db.learnKeyword(learningKeyword(name), d.categoryId!);
        learned++;
      }
    }
    refreshData(ref);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${_drafts.length}건을 저장했어요'
          '${learned > 0 ? ' · 새로 정한 카테고리 $learned개는 다음부터 바로 분류돼요' : ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final itemSum = _drafts.fold<int>(
      0,
      (s, d) => s + (int.tryParse(d.amount.text) ?? 0),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('인식 결과 확인')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('사진에서 내역을 읽고 있어요'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReceiptImage(
                      path: widget.imagePath,
                      width: 96,
                      height: 128,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_merchant != null)
                            Text(
                              _merchant!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(formatDay(_date)),
                            onPressed: _pickDate,
                          ),
                          Text('품목 합계 ${formatWon(itemSum)}'),
                          if (_total != null && _total != itemSum)
                            Text(
                              '영수증 합계 ${formatWon(_total!)}와 달라요 (할인·배송비 때문일 수 있어요)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _notice!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_aiPending)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('AI가 카테고리를 고르고 있어요'),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                for (var i = 0; i < _drafts.length; i++)
                  _DraftCard(
                    key: ObjectKey(_drafts[i]),
                    draft: _drafts[i],
                    categories: categories,
                    onChanged: () => setState(() {}),
                    onDelete: _drafts.length == 1
                        ? null
                        : () {
                            final removed = _drafts.removeAt(i);
                            setState(() {});
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => removed.dispose(),
                            );
                          },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                  onPressed: () => setState(() => _drafts.add(_Draft())),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text('${_drafts.length}건 저장'),
                ),
              ),
            ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    super.key,
    required this.draft,
    required this.categories,
    required this.onChanged,
    this.onDelete,
  });

  final _Draft draft;
  final List<Category> categories;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final auto =
        draft.categoryId != null &&
        draft.categoryId == draft.suggestedCategoryId;
    final byAi =
        draft.categoryId != null && draft.categoryId == draft.aiCategoryId;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.name,
                    decoration: const InputDecoration(labelText: '품목'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: draft.amount,
                    decoration: const InputDecoration(
                      labelText: '금액',
                      suffixText: '원',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: '이 항목 빼기',
                  icon: const Icon(Icons.close),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              auto
                  ? '카테고리 (자동 분류됨, 눌러서 바꿀 수 있어요)'
                  : byAi
                  ? '카테고리 (AI가 골랐어요, 눌러서 바꿀 수 있어요)'
                  : '카테고리',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: CategoryAvatar(category: c, size: 22),
                        label: Text(c.name),
                        selected: draft.categoryId == c.id,
                        onSelected: (_) {
                          draft.categoryId = c.id;
                          onChanged();
                        },
                      ),
                    ),
                  ChoiceChip(
                    avatar: const CategoryAvatar(category: null, size: 22),
                    label: const Text('미분류'),
                    selected: draft.categoryId == null,
                    onSelected: (_) {
                      draft.categoryId = null;
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
