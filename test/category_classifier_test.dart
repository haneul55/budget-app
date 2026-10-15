import 'package:budget_app/data/models.dart';
import 'package:budget_app/recognition/category_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const food = 1, cafe = 2, shopping = 3, life = 4;
  final c = CategoryClassifier(const [
    CategoryRule(categoryId: food, keyword: '김밥'),
    CategoryRule(categoryId: food, keyword: '우유'),
    CategoryRule(categoryId: cafe, keyword: '바나나우유'),
    CategoryRule(categoryId: cafe, keyword: '스타벅스'),
    CategoryRule(categoryId: shopping, keyword: '니트'),
    CategoryRule(categoryId: shopping, keyword: '에이블리'),
    CategoryRule(categoryId: life, keyword: 'cu'),
  ]);

  test('품목명의 키워드로 분류하고, 긴 키워드가 이긴다', () {
    expect(c.classify('삼각김밥 참치'), food);
    expect(c.classify('바나나우유'), cafe);
    expect(c.classify('서울우유 1L'), food);
  });

  test('품목명으로 못 찾으면 구매처로 분류한다', () {
    expect(c.classify('아이스 아메리카노', merchant: '스타벅스'), cafe);
    expect(c.classify('루즈핏 가디건', merchant: '에이블리'), shopping);
    expect(c.classify('케이블 니트', merchant: '스타벅스'), shopping);
  });

  test('영문 키워드는 단어 단위로만 맞춘다', () {
    expect(c.classify('CU 역삼점'), life);
    expect(c.classify('cucumber'), isNull);
  });

  test('맞는 규칙이 없으면 미분류', () {
    expect(c.classify('알 수 없는 상품'), isNull);
  });
}
