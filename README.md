# 사진 가계부 (budget_app)

영수증이나 쇼핑앱 결제 화면 사진으로 지출을 기록하는 안드로이드 가계부 앱입니다. Flutter로 만들고, 데이터는 폰 안(SQLite)에만 저장합니다.

## 지금 되는 것 (1단계)

- 홈: 월 선택, 이번 달 총지출, 카테고리별 누적 금액과 비율
- 카테고리 상세: 그 달의 결제 내역 목록, 누르면 수정·삭제
- 내역 직접 입력: 품목, 금액, 날짜, 카테고리, 구매처, 메모
- 카테고리 관리: 추가, 이름·아이콘·색상 변경, 삭제(내역은 미분류로 이동), 드래그로 순서 변경
- 기본 카테고리 7개: 식비, 카페/간식, 쇼핑, 생활/마트, 교통, 문화/여가, 기타

## 다음 단계

2. 사진 첨부와 원본 영수증/결제 화면 보기
3. 날짜별 꺾은선 그래프, 월별 누적 기록
4. 사진 자동 인식
5. 플레이스토어 출시 준비

## Windows에서 실행하기

1. [Flutter 설치 안내](https://docs.flutter.dev/get-started/install/windows/mobile)를 따라 Flutter SDK와 Android Studio를 설치합니다.
2. 명령 프롬프트에서 `flutter doctor`를 실행해 빨간 X가 없는지 확인합니다. (`flutter doctor --android-licenses`로 라이선스 동의)
3. 안드로이드 폰에서 개발자 옵션과 USB 디버깅을 켜고 PC에 연결합니다. (또는 Android Studio의 에뮬레이터 사용)
4. 이 폴더에서:
   ```
   flutter pub get
   flutter run
   ```
5. 테스트: `flutter test`

## 폴더 구조

```
lib/
  main.dart                 앱 시작, 테마, 한국어 설정
  data/models.dart          Category, Expense 데이터 구조
  data/database.dart        SQLite 테이블과 조회·저장 함수
  data/category_icons.dart  고를 수 있는 아이콘·색상 목록
  state/providers.dart      화면에 데이터를 공급하는 Riverpod provider
  ui/                       화면들
test/                       DB·화면 테스트
```
