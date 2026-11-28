import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recognition/ai_classifier.dart';
import '../state/providers.dart';

/// AI 자동 분류 서버 주소와 앱 비밀번호를 넣는 화면.
/// 비워 두면 AI를 쓰지 않고 지금처럼 키워드 규칙으로만 분류한다.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _hideToken = true;
  bool _busy = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    db.setting(AiServerConfig.urlKey).then((v) => _url.text = v ?? '');
    db.setting(AiServerConfig.tokenKey).then((v) => _token.text = v ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.setSetting(AiServerConfig.urlKey, _url.text);
    await db.setSetting(AiServerConfig.tokenKey, _token.text);
    ref.invalidate(aiConfigProvider);
    if (!mounted) return;
    final on = _url.text.trim().isNotEmpty && _token.text.trim().isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(on ? 'AI 자동 분류를 켰어요' : 'AI 자동 분류를 껐어요 (키워드 규칙만 사용)'),
      ),
    );
    Navigator.of(context).pop();
  }

  /// 예시 품목 하나를 보내서 서버가 제대로 답하는지 확인한다.
  Future<void> _test() async {
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) {
      setState(() {
        _result = '서버 주소와 앱 비밀번호를 모두 넣어 주세요.';
        _resultOk = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    final categories = await ref.read(categoriesProvider.future);
    const sample = '아이스 아메리카노';
    String message;
    var ok = false;
    try {
      final picks = await AiCategoryClassifier(
        AiServerConfig(url: _url.text, token: _token.text.trim()),
      ).classifyOrThrow([(name: sample, merchant: null)], categories);
      final picked = categories.where((c) => c.id == picks.first).firstOrNull;
      ok = true;
      message = picked == null
          ? '연결됐어요. ("$sample"은 알맞은 카테고리가 없다고 답했어요)'
          : '연결됐어요. "$sample" → ${picked.name}';
    } on AiUnavailable catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = message;
      _resultOk = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 자동 분류')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '키워드 규칙으로 분류하지 못한 품목만 AI(Claude)에게 물어봐요. '
            '품목 이름, 구매처, 카테고리 이름만 보내고 사진이나 금액은 보내지 않아요.\n'
            'AI가 고른 카테고리를 그대로 저장하면 키워드로 기억해서, 다음부터는 AI에 묻지 않고 바로 분류해요.\n'
            '인터넷이 안 되거나 아래를 비워 두면 지금처럼 키워드 규칙으로만 분류해요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '서버 주소',
              hintText: 'https://budget-ai-proxy.내이름.workers.dev',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: _hideToken,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: '앱 비밀번호 (서버에 넣은 APP_TOKEN)',
              suffixIcon: IconButton(
                icon: Icon(
                  _hideToken ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _hideToken = !_hideToken),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('연결 확인'),
            onPressed: _busy ? null : _test,
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _result!,
                style: TextStyle(
                  color: _resultOk
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _save, child: const Text('저장')),
        ),
      ),
    );
  }
}
