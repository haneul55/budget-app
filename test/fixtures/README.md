# 테스트용 영수증 데이터

`korean_receipts.json`은 아래 공개 데이터의 영수증 사진 20장에서 글자를 손으로 옮겨 적고,
날짜·품목·가격·합계 정답을 손으로 표시한 것입니다. 사진 자체는 저장소에 넣지 않았습니다.

- 출처: HumynLabs, *Korean Receipts Dataset* —
  https://huggingface.co/datasets/HumynLabs/Korean_Receipts_Dataset
- 라이선스: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
- 변경 사항: 사진 속 글자를 한 줄씩 텍스트로 옮김(왼쪽 품목명과 오른쪽 금액은 앱의
  `mergeIntoRows`처럼 한 줄로 합침), 정답 라벨 추가.

각 항목의 `image`는 원본 데이터셋의 파일 이름입니다.
`test/receipt_dataset_test.dart`가 이 파일로 인식 정확도를 잽니다.
