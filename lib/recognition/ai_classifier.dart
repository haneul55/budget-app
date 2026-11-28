import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

/// AI 분류 서버(proxy 폴더의 Cloudflare Worker) 접속 정보.
/// 둘 다 앱의 'AI 자동 분류' 설정 화면에서 넣는다.
class AiServerConfig {
  const AiServerConfig({required this.url, required this.token});

  static const urlKey = 'ai_server_url';
  static const tokenKey = 'ai_server_token';

  final String url;
  final String token;

  Uri get classifyUri {
    var base = url.trim();
    if (!base.startsWith('http')) base = 'https://$base';
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/classify');
  }
}

/// 분류할 품목 하나.
typedef AiItem = ({String name, String? merchant});

/// 키워드 규칙으로 분류하지 못한 품목을 AI 서버에 보내 카테고리를 받아 온다.
/// 인터넷이 없거나 서버에 문제가 있으면 예외 대신 빈 결과를 돌려줘서,
/// 앱은 지금처럼 '미분류'로 두고 계속 동작한다.
class AiCategoryClassifier {
  AiCategoryClassifier(
    this.config, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final AiServerConfig config;
  final http.Client _client;
  final Duration timeout;

  /// 서버가 받는 최대 품목 수 (proxy/src/index.ts의 MAX_ITEMS).
  static const maxItems = 30;

  /// 품목 순서대로 카테고리 id를 돌려준다. 못 고른 품목은 null.
  /// 서버에 닿지 못하면 [AiUnavailable]을 던진다.
  Future<List<int?>> classifyOrThrow(
    List<AiItem> items,
    List<Category> categories,
  ) async {
    if (items.isEmpty || categories.isEmpty) return [];
    final batch = items.take(maxItems).toList();
    final http.Response res;
    try {
      res = await _client
          .post(
            config.classifyUri,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer ${config.token}',
            },
            body: jsonEncode({
              'categories': [for (final c in categories) c.name],
              'items': [
                for (final it in batch)
                  {'name': it.name, 'merchant': ?it.merchant},
              ],
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw AiUnavailable('서버에 연결하지 못했어요. 인터넷 연결과 서버 주소를 확인해 주세요.');
    }

    if (res.statusCode != 200) {
      throw AiUnavailable(_errorMessage(res));
    }
    final List<Object?> results;
    try {
      results =
          (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['results'] as List;
    } catch (_) {
      throw AiUnavailable('서버 응답을 이해하지 못했어요.');
    }
    final byName = {for (final c in categories) c.name: c.id};
    return [
      for (var i = 0; i < items.length; i++)
        i < results.length ? byName[results[i]] : null,
    ];
  }

  /// [classifyOrThrow]와 같지만, 실패하면 모두 null(미분류)을 돌려준다.
  Future<List<int?>> classify(
    List<AiItem> items,
    List<Category> categories,
  ) async {
    try {
      return await classifyOrThrow(items, categories);
    } on AiUnavailable {
      return List.filled(items.length, null);
    }
  }

  static String _errorMessage(http.Response res) {
    String? code;
    try {
      code = (jsonDecode(res.body) as Map)['error'] as String?;
    } catch (_) {}
    return switch (code) {
      'wrong_token' => '앱 비밀번호가 서버와 달라요.',
      'bad_api_key' => '서버에 넣은 Anthropic API 키가 올바르지 않아요.',
      'server_not_configured' => '서버에 API 키나 앱 비밀번호가 아직 없어요.',
      'rate_limited' => '요청이 너무 많아요. 잠시 뒤 다시 해 주세요.',
      _ when res.statusCode == 404 => '서버 주소가 맞는지 확인해 주세요.',
      _ => '서버 오류가 났어요 (${res.statusCode}).',
    };
  }
}

class AiUnavailable implements Exception {
  AiUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}
