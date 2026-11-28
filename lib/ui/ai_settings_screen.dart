import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recognition/ai_classifier.dart';
import '../state/providers.dart';

enum _AiMode { apiKey, server }

/// AI 자동 분류 설정 화면.
/// - API 키 직접: 폰에 Anthropic API 키를 저장하고 앱이 Claude를 바로 부른다 (시험용).
/// - 내 서버: proxy 폴더의 Cloudflare Worker 주소와 앱 비밀번호를 넣는다.
/// 비워 두면 AI를 쓰지 않고 지금처럼 키워드 규칙으로만 분류한다.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _apiKey = TextEditingController();
  final _url = TextEditingController();
  final _token = TextEditingController();
  _AiMode _mode = _AiMode.apiKey;
  bool _hideSecret = true;
  bool _busy = false;
  String? _result;
  bool _resultOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    String? key;
    try {
      key = await ref
          .read(secureStorageProvider)
          .read(key: DirectCategoryAi.apiKeyStorageKey);
    } catch (_) {}
    final url = await db.setting(AiServerConfig.urlKey);
    final token = await db.setting(AiServerConfig.tokenKey);
    if (!mounted) return;
    setState(() {
      _apiKey.text = key ?? '';
      _url.text = url ?? '';
      _token.text = token ?? '';
      if ((key ?? '').isEmpty && url != null) _mode = _AiMode.server;
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  CategoryAi? _fromInputs() => switch (_mode) {
    _AiMode.apiKey when _apiKey.text.trim().isNotEmpty => DirectCategoryAi(
      _apiKey.text.trim(),
    ),
    _AiMode.server
        when _url.text.trim().isNotEmpty && _token.text.trim().isNotEmpty =>
      AiCategoryClassifier(
        AiServerConfig(url: _url.text.trim(), token: _token.text.trim()),
      ),
    _ => null,
  };

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final storage = ref.read(secureStorageProvider);
    try {
      if (_mode == _AiMode.apiKey && _apiKey.text.trim().isNotEmpty) {
        await storage.write(
          key: DirectCategoryAi.apiKeyStorageKey,
          value: _apiKey.text.trim(),
        );
      } else {
        await storage.delete(key: DirectCategoryAi.apiKeyStorageKey);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('API 키를 폰에 저장하지 못했어요')));
      }
      return;
    }
    final server = _mode == _AiMode.server;
    await db.setSetting(AiServerConfig.urlKey, server ? _url.text : null);
    await db.setSetting(AiServerConfig.tokenKey, server ? _token.text : null);
    ref.invalidate(categoryAiProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _fromInputs() != null
              ? 'AI 자동 분류를 켰어요'
              : 'AI 자동 분류를 껐어요 (키워드 규칙만 사용)',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  /// 예시 품목 하나를 보내서 제대로 답하는지 확인한다.
  Future<void> _test() async {
    final ai = _fromInputs();
    if (ai == null) {
      setState(() {
        _result = _mode == _AiMode.apiKey
            ? 'API 키를 넣어 주세요.'
            : '서버 주소와 앱 비밀번호를 모두 넣어 주세요.';
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
      final picks = await ai.classifyOrThrow([
        (name: sample, merchant: null),
      ], categories);
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

  Widget _secretField(TextEditingController c, String label, {String? hint}) =>
      TextField(
        controller: c,
        obscureText: _hideSecret,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: IconButton(
            icon: Icon(_hideSecret ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hideSecret = !_hideSecret),
          ),
        ),
      );

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
          const SizedBox(height: 16),
          SegmentedButton<_AiMode>(
            segments: const [
              ButtonSegment(value: _AiMode.apiKey, label: Text('API 키 직접')),
              ButtonSegment(value: _AiMode.server, label: Text('내 서버')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _result = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_mode == _AiMode.apiKey) ...[
            _secretField(_apiKey, 'Anthropic API 키', hint: 'sk-ant-...'),
            const SizedBox(height: 8),
            Text(
              '키는 이 폰의 안전한 저장소(아이폰 키체인)에만 저장돼요. '
              '나 혼자 쓰는 시험용 방법이라, 다른 사람에게 앱을 나눠 줄 때는 "내 서버" 방식을 써 주세요.',
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
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
            _secretField(_token, '앱 비밀번호 (서버에 넣은 APP_TOKEN)'),
          ],
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
