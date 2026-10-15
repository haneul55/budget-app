import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 고른 사진을 앱 전용 폴더로 복사한다. 갤러리에서 지워도 앱 안 기록은 남는다.
Future<String> saveReceiptImage(String pickedPath) async {
  final dir = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'receipts'),
  );
  await dir.create(recursive: true);
  final ext = p.extension(pickedPath).isEmpty
      ? '.jpg'
      : p.extension(pickedPath);
  final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
  await File(pickedPath).copy(dest);
  return dest;
}
