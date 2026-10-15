import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../recognition/category_classifier.dart';
import '../state/providers.dart';
import '../util/format.dart';
import 'widgets/category_avatar.dart';
import 'widgets/source_image_view.dart';

/// 결제 내역 직접 입력/수정 화면. [initial]이 있으면 수정 모드.
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.initial});

  final Expense? initial;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.itemName);
  late final _amount = TextEditingController(
    text: widget.initial?.amount.toString(),
  );
  late final _merchant = TextEditingController(text: widget.initial?.merchant);
  late final _memo = TextEditingController(text: widget.initial?.memo);
  late DateTime _date = widget.initial?.spentAt ?? DateTime.now();
  late int? _categoryId = widget.initial?.categoryId;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _merchant.dispose();
    _memo.dispose();
    super.dispose();
  }

  String? _trimOrNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseProvider);
    final expense = Expense(
      id: widget.initial?.id,
      itemName: _name.text.trim(),
      amount: int.parse(_amount.text),
      spentAt: _date,
      categoryId: _categoryId,
      sourceImageId: widget.initial?.sourceImageId,
      merchant: _trimOrNull(_merchant.text),
      memo: _trimOrNull(_memo.text),
    );
    if (_editing) {
      await db.updateExpense(expense);
      // 카테고리를 바꿨으면 다음부터 같은 품목은 바꾼 카테고리로 자동 분류
      if (_categoryId != null && _categoryId != widget.initial!.categoryId) {
        await db.learnKeyword(learningKeyword(expense.itemName), _categoryId!);
      }
    } else {
      await db.addExpense(expense);
    }
    refreshData(ref);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 내역을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteExpense(widget.initial!.id!);
    refreshData(ref);
    if (mounted) Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '내역 수정' : '내역 추가'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.initial?.sourceImageId != null) ...[
              SourceImageView(
                sourceImageId: widget.initial!.sourceImageId!,
                height: 220,
                width: double.infinity,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text('사진을 누르면 크게 볼 수 있어요', textAlign: TextAlign.center),
              ),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '품목',
                hintText: '예) 니트 가디건',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '품목을 입력해 주세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: '금액',
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v == null || (int.tryParse(v) ?? 0) <= 0)
                  ? '금액을 입력해 주세요'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDay(_date)),
              trailing: const Text('날짜 변경'),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Text('카테고리', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    avatar: CategoryAvatar(category: c, size: 24),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
                ChoiceChip(
                  avatar: const CategoryAvatar(category: null, size: 24),
                  label: const Text('미분류'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchant,
              decoration: const InputDecoration(
                labelText: '구매처 (선택)',
                hintText: '예) 쿠팡, 에이블리',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
