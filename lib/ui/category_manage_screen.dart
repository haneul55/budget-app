import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_icons.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'widgets/category_avatar.dart';

/// 카테고리 추가·수정·삭제·순서 변경.
class CategoryManageScreen extends ConsumerWidget {
  const CategoryManageScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Category? c]) async {
    final result = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryEditSheet(initial: c),
    );
    if (result == null) return;
    final db = ref.read(databaseProvider);
    if (result.id == null) {
      await db.addCategory(result);
    } else {
      await db.updateCategory(result);
    }
    refreshData(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${c.name}" 카테고리를 삭제할까요?'),
        content: const Text('이 카테고리의 내역은 지워지지 않고 미분류로 옮겨져요.'),
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
    await ref.read(databaseProvider).deleteCategory(c.id!);
    refreshData(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('카테고리 관리')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오지 못했어요: $e')),
        data: (list) => ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          onReorderItem: (oldIndex, newIndex) async {
            final ids = list.map((c) => c.id!).toList();
            ids.insert(newIndex, ids.removeAt(oldIndex));
            await ref.read(databaseProvider).reorderCategories(ids);
            refreshData(ref);
          },
          itemBuilder: (context, i) {
            final c = list[i];
            return ListTile(
              key: ValueKey(c.id),
              leading: CategoryAvatar(category: c),
              title: Text(c.name),
              onTap: () => _edit(context, ref, c),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, c),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('카테고리 추가'),
        onPressed: () => _edit(context, ref),
      ),
    );
  }
}

/// 카테고리 이름·아이콘·색상 편집 시트. 저장하면 수정된 [Category]를 pop 한다.
class CategoryEditSheet extends StatefulWidget {
  const CategoryEditSheet({super.key, this.initial});

  final Category? initial;

  @override
  State<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<CategoryEditSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late String _iconKey = widget.initial?.iconKey ?? categoryIcons.keys.first;
  late int _color = widget.initial?.colorValue ?? categoryColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final base =
        widget.initial ??
        Category(name: name, iconKey: _iconKey, colorValue: _color);
    Navigator.of(context)
        .pop(base.copyWith(name: name, iconKey: _iconKey, colorValue: _color));
  }

  @override
  Widget build(BuildContext context) {
    final preview = Category(
      name: _name.text,
      iconKey: _iconKey,
      colorValue: _color,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CategoryAvatar(category: preview, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: widget.initial == null,
                    decoration: const InputDecoration(labelText: '카테고리 이름'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('색상', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('아이콘', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: GridView.count(
                crossAxisCount: 6,
                children: [
                  for (final entry in categoryIcons.entries)
                    IconButton(
                      isSelected: _iconKey == entry.key,
                      style: IconButton.styleFrom(
                        backgroundColor: _iconKey == entry.key
                            ? Color(_color).withValues(alpha: 0.2)
                            : null,
                      ),
                      icon: Icon(
                        entry.value,
                        color: _iconKey == entry.key ? Color(_color) : null,
                      ),
                      onPressed: () => setState(() => _iconKey = entry.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
