import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 파일 경로의 사진. 누르면 전체 화면에서 확대해 볼 수 있다.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({super.key, required this.path, this.width, this.height});

  final String path;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _FullScreenImage(path: path))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: 600,
          errorBuilder: (_, _, _) => SizedBox(
            width: width,
            height: height,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

/// 저장된 내역에 붙은 원본 사진(DB id로 찾음).
class SourceImageView extends ConsumerWidget {
  const SourceImageView({
    super.key,
    required this.sourceImageId,
    this.width,
    this.height,
  });

  final int sourceImageId;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(sourceImageProvider(sourceImageId)).value;
    if (image == null) return SizedBox(width: width, height: height);
    return ReceiptImage(path: image.filePath, width: width, height: height);
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: Image.file(File(path))),
      ),
    );
  }
}
