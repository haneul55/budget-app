import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 사진에서 한글·영문 글자를 읽어 "화면에 보이는 줄" 순서로 돌려준다.
/// ML Kit은 기기 안에서 동작하므로 사진이 밖으로 나가지 않는다.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  Future<List<String>> readLines(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    final lines = [for (final b in result.blocks) ...b.lines];
    return mergeIntoRows([
      for (final l in lines)
        (l.text, l.boundingBox.left, l.boundingBox.top, l.boundingBox.bottom),
    ]);
  }

  Future<void> close() => _recognizer.close();
}

/// 같은 높이에 있는 글자 덩어리(예: 왼쪽 품목명, 오른쪽 금액)를 한 줄로 합친다.
List<String> mergeIntoRows(
  List<(String text, double left, double top, double bottom)> pieces,
) {
  final sorted = [...pieces]
    ..sort((a, b) => (a.$3 + a.$4).compareTo(b.$3 + b.$4));
  final rows = <List<(String, double, double, double)>>[];
  for (final p in sorted) {
    final center = (p.$3 + p.$4) / 2;
    final height = p.$4 - p.$3;
    if (rows.isNotEmpty) {
      final last = rows.last;
      final lastCenter =
          last.map((e) => (e.$3 + e.$4) / 2).reduce((a, b) => a + b) /
          last.length;
      if ((center - lastCenter).abs() < height * 0.5) {
        last.add(p);
        continue;
      }
    }
    rows.add([p]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.$2.compareTo(b.$2))).map((e) => e.$1).join(' '),
  ];
}
