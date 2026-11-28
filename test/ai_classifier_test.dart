import 'dart:convert';

import 'package:budget_app/data/models.dart';
import 'package:budget_app/recognition/ai_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const categories = [
    Category(id: 1, name: '식비', iconKey: 'food', colorValue: 0),
    Category(id: 2, name: '쇼핑', iconKey: 'shop', colorValue: 0),
  ];
  const config = AiServerConfig(url: 'my-proxy.workers.dev/', token: 'pw');

  test('서버가 고른 카테고리 이름을 id로 바꾼다', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'results': ['쇼핑', null, '없는 카테고리'],
          }),
        ),
        200,
      );
    });
    final picks = await AiCategoryClassifier(config, client: client).classify([
      (name: '케이블 가디건', merchant: '에이블리'),
      (name: '???', merchant: null),
      (name: '무언가', merchant: null),
    ], categories);
    expect(picks, [2, null, null]);
    expect(sent.url.toString(), 'https://my-proxy.workers.dev/classify');
    expect(sent.headers['authorization'], 'Bearer pw');
    final body = jsonDecode(sent.body) as Map;
    expect(body['categories'], ['식비', '쇼핑']);
    expect(body['items'][0], {'name': '케이블 가디건', 'merchant': '에이블리'});
    expect(body['items'][1], {'name': '???'});
  });

  test('서버 오류나 연결 실패면 모두 미분류로 둔다', () async {
    final error = MockClient(
      (_) async => http.Response('{"error":"wrong_token"}', 401),
    );
    expect(
      await AiCategoryClassifier(
        config,
        client: error,
      ).classify([(name: '니트', merchant: null)], categories),
      [null],
    );
    await expectLater(
      AiCategoryClassifier(
        config,
        client: error,
      ).classifyOrThrow([(name: '니트', merchant: null)], categories),
      throwsA(
        isA<AiUnavailable>().having(
          (e) => e.message,
          'message',
          contains('비밀번호'),
        ),
      ),
    );

    final offline = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    expect(
      await AiCategoryClassifier(
        config,
        client: offline,
      ).classify([(name: '니트', merchant: null)], categories),
      [null],
    );
  });
}
