import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

/// 규칙으로 못 고른 품목의 카테고리를 AI에게 묻는 방법.
/// [DirectCategoryAi]: 앱이 Anthropic API를 바로 부름 (API 키를 폰에 저장, 시험용)
/// [AiCategoryClassifier]: 내 서버(proxy 폴더)를 거쳐 부름 (키가 앱에 없음)
abstract class CategoryAi {
  /// 서버가 받는 최대 품목 수.
  static const maxItems = 30;

  /// 품목 순서대로 카테고리 id를 돌려준다. 못 고른 품목은 null.
  /// AI에 닿지 못하면 [AiUnavailable]을 던진다.
  Future<List<int?>> classifyOrThrow(
    List<AiItem> items,
    List<Category> categories,
  );

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
}

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
class AiCategoryClassifier extends CategoryAi {
  AiCategoryClassifier(
    this.config, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final AiServerConfig config;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<List<int?>> classifyOrThrow(
    List<AiItem> items,
    List<Category> categories,
  ) async {
    if (items.isEmpty || categories.isEmpty) return [];
    final batch = items.take(CategoryAi.maxItems).toList();
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

/// 앱이 Anthropic API를 직접 부르는 분류기. 스토어에 올리지 않는 시험용.
/// (Dart용 공식 Anthropic SDK가 없어서 HTTP로 직접 부른다. 서버 쪽 proxy/src/index.ts와 같은 요청.)
class DirectCategoryAi extends CategoryAi {
  DirectCategoryAi(
    this.apiKey, {
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static const apiKeyStorageKey = 'anthropic_api_key';
  static const model = 'claude-haiku-5-5';
  static const unknown = '모름';
  static final _endpoint = Uri.parse('https://api.anthropic.com/v1/messages');

  static const systemPrompt =
      '''너는 한국어 가계부 앱의 지출 분류기다.
영수증이나 쇼핑앱 결제 화면에서 읽은 품목마다, 사용자가 만든 카테고리 목록 중 가장 알맞은 것을 하나 고른다.
- 품목명이 우선이고, 구매처(가게 이름)는 참고만 한다.
- 품목명이 글자 인식 오류로 조금 깨져 있을 수 있으니 뜻을 짐작해서 고른다.
- 어느 카테고리에도 맞지 않거나 무엇인지 알 수 없으면 "$unknown"를 고른다. 억지로 고르지 않는다.
- 결과는 품목 번호(index)마다 하나씩 낸다.''';

  final String apiKey;
  final http.Client _client;
  final Duration timeout;

  /// Messages API 요청 본문. 카테고리 이름(또는 "모름") 중에서만 고르도록 JSON 스키마로 묶는다.
  static Map<String, Object?> requestBody(
    List<AiItem> items,
    List<String> categoryNames,
  ) {
    final list = [
      for (var i = 0; i < items.length; i++)
        '$i. ${items[i].name}'
            '${items[i].merchant == null ? '' : ' (구매처: ${items[i].merchant})'}',
    ].join('\n');
    return {
      'model': model,
      'max_tokens': 2048,
      'thinking': {'type': 'disabled'},
      'output_config': {
        'effort': 'low',
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'results': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'index': {'type': 'integer'},
                    'category': {
                      'type': 'string',
                      'enum': [unknown, ...categoryNames],
                    },
                  },
                  'required': ['index', 'category'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['results'],
            'additionalProperties': false,
          },
        },
      },
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': '카테고리 목록: ${categoryNames.join(', ')}\n\n품목:\n$list',
        },
      ],
    };
  }

  @override
  Future<List<int?>> classifyOrThrow(
    List<AiItem> items,
    List<Category> categories,
  ) async {
    if (items.isEmpty || categories.isEmpty) return [];
    final batch = items.take(CategoryAi.maxItems).toList();
    final names = {for (final c in categories) c.name}.toList();
    final http.Response res;
    try {
      res = await _client
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2026-10-21',
            },
            body: jsonEncode(requestBody(batch, names)),
          )
          .timeout(timeout);
    } catch (_) {
      throw AiUnavailable('Claude에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.');
    }
    if (res.statusCode != 200) throw AiUnavailable(_errorMessage(res));

    final List<Object?> results;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      if (body['stop_reason'] == 'refusal') {
        return List.filled(items.length, null);
      }
      final text = (body['content'] as List)
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join();
      results = (jsonDecode(text) as Map)['results'] as List;
    } catch (_) {
      throw AiUnavailable('Claude 응답을 이해하지 못했어요.');
    }

    final byName = {for (final c in categories) c.name: c.id};
    final picks = List<int?>.filled(items.length, null);
    for (final r in results.whereType<Map>()) {
      final i = r['index'];
      if (i is int && i >= 0 && i < batch.length) {
        picks[i] = byName[r['category']];
      }
    }
    return picks;
  }

  static String _errorMessage(http.Response res) {
    var message = '';
    try {
      message =
          ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['error']
                  as Map)['message']
              as String;
    } catch (_) {}
    final lower = message.toLowerCase();
    if (res.statusCode == 401) return 'API 키가 올바르지 않아요. 다시 붙여 넣어 주세요.';
    if (res.statusCode == 403) return '이 API 키로는 쓸 수 없어요. 키 권한을 확인해 주세요.';
    if (lower.contains('credit')) {
      return '크레딧이 부족해요. Anthropic 콘솔의 Billing에서 충전해 주세요.';
    }
    if (res.statusCode == 429) return '요청이 너무 많아요. 잠시 뒤 다시 해 주세요.';
    if (res.statusCode == 529 || res.statusCode >= 500) {
      return 'Claude 서버가 바빠요. 잠시 뒤 다시 해 주세요.';
    }
    return 'Claude 오류가 났어요 (${res.statusCode})${message.isEmpty ? '' : ': $message'}';
  }
}
