import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// 타격왕 시상식 타임라인 프레임을 캡처하고 BGM과 합성해 MP4를 생성하는 서비스.
class CeremonyVideoExporter {
  CeremonyVideoExporter._();

  static const MethodChannel _channel = MethodChannel(
    'com.codegrove.thebase/ceremony_video',
  );

  static const String _ceremonyAudioAsset = 'assets/audio/batting_king_ceremony.m4a';

  static Future<String> exportCeremonyMp4({
    required GlobalKey boundaryKey,
    required Duration totalDuration,
    required void Function(double progress) onSeekTimeline,
    required void Function(double progress) onEncodingProgress,
    int fps = 24,
  }) async {
    final safeFps = math.max(1, fps);
    final totalFrames = math.max(
      1,
      (totalDuration.inMilliseconds * safeFps / 1000).round(),
    );

    final tempRoot = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final framesDir = Directory('${tempRoot.path}/ceremony_frames_$timestamp');
    final tempAudioFile = File('${tempRoot.path}/ceremony_audio_$timestamp.m4a');
    final outputPath = '${tempRoot.path}/batting_king_ceremony_$timestamp.mp4';

    await framesDir.create(recursive: true);

    try {
      for (int i = 0; i < totalFrames; i++) {
        final timelineProgress = totalFrames == 1 ? 1.0 : i / (totalFrames - 1);
        onSeekTimeline(timelineProgress);
        await WidgetsBinding.instance.endOfFrame;

        final renderObject = boundaryKey.currentContext?.findRenderObject();
        if (renderObject is! RenderRepaintBoundary) {
          throw StateError('시상식 캡처 영역(RepaintBoundary)을 찾을 수 없습니다.');
        }

        final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);
        try {
          final ByteData? byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('프레임 PNG 인코딩에 실패했습니다 (frame $i).');
          }
          final frameFile = File(
            '${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.png',
          );
          await frameFile.writeAsBytes(
            byteData.buffer.asUint8List(),
            flush: false,
          );
        } finally {
          image.dispose();
        }

        onEncodingProgress(((i + 1) / totalFrames) * 0.85);
      }

      final audioData = await rootBundle.load(_ceremonyAudioAsset);
      await tempAudioFile.writeAsBytes(
        audioData.buffer.asUint8List(),
        flush: true,
      );

      final encodedPath = await _channel.invokeMethod<String>(
        'encodeCeremonyVideo',
        <String, dynamic>{
          'framesDir': framesDir.path,
          'audioPath': tempAudioFile.path,
          'fps': safeFps,
          'outputPath': outputPath,
        },
      );

      if (encodedPath == null || encodedPath.isEmpty) {
        throw StateError('네이티브 시상식 MP4 합성이 빈 경로를 반환했습니다.');
      }

      onEncodingProgress(1.0);
      return encodedPath;
    } finally {
      if (await framesDir.exists()) {
        try {
          await framesDir.delete(recursive: true);
        } catch (_) {}
      }
      if (await tempAudioFile.exists()) {
        try {
          await tempAudioFile.delete();
        } catch (_) {}
      }
    }
  }
}
