import 'dart:typed_data';

import 'package:flutter/services.dart';

class RecapVideoExporter {
  static const MethodChannel _channel = MethodChannel(
    'com.codegrove.thebase/recap_video',
  );

  static Future<void> startEncoding({
    required int width,
    required int height,
    required int fps,
    required String outputPath,
    String? audioPath,
  }) async {
    await _channel.invokeMethod('startEncoding', {
      'width': width,
      'height': height,
      'fps': fps,
      'outputPath': outputPath,
      'audioPath': audioPath,
    });
  }

  static Future<void> appendFrame(Uint8List pngBytes) async {
    await _channel.invokeMethod('appendFrame', {'bytes': pngBytes});
  }

  static Future<String> finishEncoding() async {
    final path = await _channel.invokeMethod<String>('finishEncoding');
    if (path == null || path.isEmpty) {
      throw Exception('동영상 파일 생성에 실패했습니다.');
    }
    return path;
  }
}
