import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/utils/intuition_recap_calculator.dart';
import 'package:lockerroom/utils/recap_video_exporter.dart';
import 'package:lockerroom/widgets/kbo_footprint_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class IntuitionRecapPage extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final int? selectedYear;
  final Color teamColor;
  final String userNickName;

  const IntuitionRecapPage({
    super.key,
    required this.records,
    required this.selectedYear,
    required this.teamColor,
    required this.userNickName,
  });

  @override
  State<IntuitionRecapPage> createState() => _IntuitionRecapPageState();
}

class _IntuitionRecapPageState extends State<IntuitionRecapPage>
    with SingleTickerProviderStateMixin {
  late final IntuitionRecapData _recapData;
  late final AnimationController _controller;
  final ScreenshotController _screenshotController = ScreenshotController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final NumberFormat _numFormat = NumberFormat('#,###');
  bool _isCapturing = false;
  bool _isExportingVideo = false;
  int _exportProgress = 0;
  bool _isMuted = false;
  bool _isPreparingPhotos = false;

  @override
  void initState() {
    super.initState();
    _recapData = IntuitionRecapData.fromRecords(widget.records);
    final crossSeaCount = _recapData.steps
        .where((s) => IntuitionRecapData.isCrossSeaStep(s))
        .length;
    final photoStepCount = _recapData.steps
        .where((s) => s.imageUrls.isNotEmpty)
        .length;
    final durationMs =
        (_recapData.steps.length * 900 +
                photoStepCount * 1800 +
                crossSeaCount * 2000)
            .clamp(8000, 60000);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    if (photoStepCount > 0) {
      _isPreparingPhotos = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepareAndStart();
      });
    } else {
      _controller.forward();
      _initBgm();
    }
  }

  Future<void> _prepareAndStart() async {
    await _precacheMemoryPhotos();
    if (!mounted) return;
    setState(() => _isPreparingPhotos = false);
    _controller.forward();
    _initBgm();
  }

  Future<void> _initBgm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.75);
      await _audioPlayer.play(
        AssetSource('audio/My Achy Heart - Audio Hertz.mp3'),
      );
    } catch (e) {
      debugPrint('⚠️ Recap BGM 재생 실패: $e');
    }
  }

  Future<void> _precacheMemoryPhotos() async {
    final urls = _recapData.steps
        .where((s) => s.imageUrls.isNotEmpty)
        .map((s) => s.imageUrls.first)
        .take(50)
        .toList();
    if (urls.isEmpty) return;

    try {
      await Future.wait(
        urls.map(
          (url) => precacheImage(
            ResizeImage(NetworkImage(url), width: 360),
            context,
          ).catchError((_) {}),
        ),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {
      // 타임아웃 시에도 즉시 재생 시작
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _audioPlayer.setVolume(_isMuted ? 0.0 : 0.75);
  }

  void _togglePlayPause() {
    if (_controller.isAnimating) {
      _controller.stop();
      _audioPlayer.pause();
    } else {
      if (_controller.value >= 1.0) {
        _controller.forward(from: 0.0);
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.resume();
      } else {
        _controller.forward();
        _audioPlayer.resume();
      }
    }
    setState(() {});
  }

  void _replay() {
    _controller.forward(from: 0.0);
    _audioPlayer.seek(Duration.zero);
    _audioPlayer.resume();
    setState(() {});
  }

  Future<Uint8List?> _captureRecapImage() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 60));
    final bytes = await _screenshotController.capture(pixelRatio: 2.5);
    if (mounted) {
      setState(() => _isCapturing = false);
    }
    return bytes;
  }

  Future<void> _saveToGallery() async {
    try {
      final bytes = await _captureRecapImage();
      if (bytes == null) return;
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.success,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관 여정 이미지를 갤러리에 저장했어요!'),
      );
    } catch (e) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: Text('저장 실패: $e'),
      );
    }
  }

  Future<void> _shareRecap() async {
    try {
      final bytes = await _captureRecapImage();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/thebase_recap_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      final yearLabel = widget.selectedYear == null
          ? '전체'
          : '${widget.selectedYear}년';
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '⚾ ${widget.userNickName}님의 $yearLabel ILU 직관 여정 (${_recapData.totalGames}경기 · 약 ${_numFormat.format(_recapData.totalDistanceKm)}km)',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: Text('공유 실패: $e'),
      );
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<String?> _prepareAudioTempFile() async {
    if (_isMuted) return null;
    try {
      final dir = await getTemporaryDirectory();
      final audioFile = File('${dir.path}/recap_bgm_mix.mp3');
      if (!await audioFile.exists()) {
        final byteData = await rootBundle.load(
          'assets/audio/My Achy Heart - Audio Hertz.mp3',
        );
        await audioFile.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
      }
      return audioFile.path;
    } catch (e) {
      debugPrint('⚠️ BGM 임시 파일 추출 실패: $e');
      return null;
    }
  }

  Future<void> _exportVideo({required bool shareAfter}) async {
    if (_isExportingVideo) return;
    _controller.stop();
    await _audioPlayer.pause();
    final savedValue = _controller.value;

    setState(() {
      _isExportingVideo = true;
      _isCapturing = true;
      _exportProgress = 0;
    });

    try {
      const int fps = 18;
      // 실제 화면에 재생되는 템포(_controller.duration, 최대 60초)에 1:1 맞춰 프레임 생성 + 마지막 정지 1초
      final int animMs = _controller.duration?.inMilliseconds ?? 8000;
      final int animFrames = ((animMs / 1000.0) * fps).round().clamp(
        fps * 4,
        fps * 60,
      );
      const int holdFrames = fps;
      final int totalFrames = animFrames + holdFrames;

      final dir = await getTemporaryDirectory();
      final outputPath =
          '${dir.path}/thebase_recap_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final audioPath = await _prepareAudioTempFile();

      bool encoderStarted = false;

      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) return;
        final double t = i < animFrames
            ? (i / (animFrames - 1)).clamp(0.0, 1.0)
            : 1.0;
        _controller.value = t;
        setState(() {});
        await WidgetsBinding.instance.endOfFrame;

        final bytes = await _screenshotController.capture(pixelRatio: 1.6);
        if (bytes == null) continue;

        if (!encoderStarted) {
          final img = await _decodeImage(bytes);
          final w = img.width;
          final h = img.height;
          img.dispose();
          await RecapVideoExporter.startEncoding(
            width: w,
            height: h,
            fps: fps,
            outputPath: outputPath,
            audioPath: audioPath,
          );
          encoderStarted = true;
        }

        await RecapVideoExporter.appendFrame(bytes);

        if (mounted) {
          setState(() {
            _exportProgress = ((i + 1) * 100 ~/ totalFrames).clamp(1, 99);
          });
        }
      }

      if (!encoderStarted) {
        throw Exception('캡처된 프레임이 없습니다.');
      }

      final mp4Path = await RecapVideoExporter.finishEncoding();

      if (mounted) {
        setState(() {
          _exportProgress = 100;
          _isExportingVideo = false;
          _isCapturing = false;
          _controller.value = savedValue;
        });
      }

      if (shareAfter) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100);
        final yearLabel = widget.selectedYear == null
            ? '전체'
            : '${widget.selectedYear}년';
        await Share.shareXFiles(
          [XFile(mp4Path)],
          text:
              '⚾ ${widget.userNickName}님의 $yearLabel ILU 직관 여정 (${_recapData.totalGames}경기 · 약 ${_numFormat.format(_recapData.totalDistanceKm)}km)',
          sharePositionOrigin: origin,
        );
      } else {
        await Gal.putVideo(mp4Path);
        if (!mounted) return;
        toastification.show(
          context: context,
          type: ToastificationType.success,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 2),
          title: const Text('직관 여정 동영상을 갤러리에 저장했어요!'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExportingVideo = false;
          _isCapturing = false;
          _controller.value = savedValue;
        });
        toastification.show(
          context: context,
          type: ToastificationType.error,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: const Duration(seconds: 3),
          title: Text('동영상 생성 실패: $e'),
        );
      }
    }
  }

  void _showShareOptionsSheet(Color teamColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15171E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3F4B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '직관 여정 공유하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: teamColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.movie_rounded, color: teamColor),
                  ),
                  title: const Text(
                    '동영상(MP4)으로 공유',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    '애니메이션 전체를 영상으로 만들어 공유해요',
                    style: TextStyle(color: Color(0xFF8B92A5), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _exportVideo(shareAfter: true);
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF23262E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.image_rounded, color: Colors.white),
                  ),
                  title: const Text(
                    '이미지로 공유',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    '현재 화면을 고화질 이미지로 공유해요',
                    style: TextStyle(color: Color(0xFF8B92A5), fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareRecap();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _resolveDarkAccent(Color raw) {
    if (raw.toARGB32() == KIWOOM.toARGB32()) {
      return raw;
    }
    final hsl = HSLColor.fromColor(raw);
    if (hsl.saturation < 0.12 && hsl.lightness < 0.22) {
      return const Color(0xFFFF4D4D);
    }
    if (hsl.lightness < 0.22) {
      return hsl
          .withLightness(0.56)
          .withSaturation((hsl.saturation * 1.1).clamp(0.45, 0.95))
          .toColor();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = _resolveDarkAccent(widget.teamColor);
    final yearLabel = widget.selectedYear == null
        ? 'ALL TIME'
        : '${widget.selectedYear}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0B0F),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // 상단 바 (캡처 영역 밖 또는 캡처 시 닫기 버튼 숨김)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1C23),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2C2F3A),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1C23),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: teamColor.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                '$yearLabel · ${widget.userNickName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1C23),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF2C2F3A),
                                  ),
                                ),
                                child: Icon(
                                  _isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: _isMuted
                                      ? const Color(0xFF7B8190)
                                      : teamColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 캡처 가능한 메인 애니메이션 영역
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final progress = _controller.value;
                        final snapshot = _recapData.snapshotAtProgress(
                          progress,
                        );
                        final isFinished = progress >= 0.999;
                        final top1 = snapshot.top3Stadiums.isNotEmpty
                            ? snapshot.top3Stadiums.first
                            : null;

                        return Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            color: const Color(0xFF0A0B0F),
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 섹션 라벨
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: teamColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '직관 여정',
                                      style: TextStyle(
                                        color: Color(0xFFD0D4DE),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 메인 카피 (실시간 카운트업)
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      height: 1.24,
                                      letterSpacing: -0.6,
                                      color: Colors.white,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${snapshot.gamesCount}경기',
                                        style: TextStyle(color: teamColor),
                                      ),
                                      const TextSpan(text: '를 보러\n'),
                                      TextSpan(
                                        text:
                                            '${snapshot.visitedStadiumCount}개 구장',
                                        style: TextStyle(color: teamColor),
                                      ),
                                      const TextSpan(text: '을 찾아\n약 '),
                                      TextSpan(
                                        text:
                                            '${_numFormat.format(snapshot.totalDistanceKm)}km',
                                        style: TextStyle(color: teamColor),
                                      ),
                                      const TextSpan(text: '를 이동했어요'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // 서브 텍스트 (진행 중엔 현재 경기, 완료 시 최다 방문 구장)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: isFinished && top1 != null
                                      ? Text(
                                          '가장 자주 찾은 곳은 ${top1.displayName}으로, ${top1.count}번 방문했어요.',
                                          key: const ValueKey('done_sub'),
                                          style: const TextStyle(
                                            color: Color(0xFF9EA4B3),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : Text(
                                          snapshot.currentStep != null
                                              ? '📍 ${snapshot.currentStep!.date} · ${snapshot.currentStep!.stadiumDisplayName}${snapshot.currentStep!.oppTeam.isNotEmpty ? ' (vs ${snapshot.currentStep!.oppTeam})' : ''}'
                                              : '직관 여정을 불러오는 중...',
                                          key: ValueKey(
                                            snapshot.currentStep?.index ?? -1,
                                          ),
                                          style: TextStyle(
                                            color: teamColor.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),

                                const SizedBox(height: 14),

                                // Top 3 구장 랭킹 카드
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF15171E),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF252834),
                                    ),
                                  ),
                                  child: snapshot.top3Stadiums.isEmpty
                                      ? const Center(
                                          child: Text(
                                            '방문한 구장 기록을 집계 중입니다',
                                            style: TextStyle(
                                              color: Color(0xFF7B8190),
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: List.generate(
                                            snapshot.top3Stadiums.length,
                                            (i) {
                                              final item =
                                                  snapshot.top3Stadiums[i];
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      i ==
                                                          snapshot
                                                                  .top3Stadiums
                                                                  .length -
                                                              1
                                                      ? 0
                                                      : 10,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 22,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color: i == 0
                                                            ? teamColor
                                                            : teamColor
                                                                  .withValues(
                                                                    alpha: 0.72,
                                                                  ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          '${i + 1}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        item.displayName,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${item.count}회',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFFD0D4DE,
                                                        ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 10),

                                // 한반도 (+ 일본) 직관 여정 애니메이션 지도 + 추억 회상 폴라로이드 카드
                                Expanded(
                                  child: Stack(
                                    children: [
                                      KboFootprintMap(
                                        steps: _recapData.steps,
                                        progress: progress,
                                        teamColor: teamColor,
                                        stadiumVisits: snapshot.stadiumVisits,
                                        includeJapan: _recapData.hasJapanVisit,
                                      ),
                                      if (!isFinished &&
                                          snapshot.currentStep != null &&
                                          snapshot
                                              .currentStep!
                                              .imageUrls
                                              .isNotEmpty)
                                        Positioned(
                                          right: 2,
                                          bottom: 6,
                                          child: _buildMemoryPhotoCard(
                                            step: snapshot.currentStep!,
                                            stepFraction: snapshot.stepFraction,
                                            teamColor: teamColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 캡처 시에만 보이는 워터마크 푸터
                                if (_isCapturing)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ILU 직관 리캡',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.45,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 하단 타임라인 컨트롤 + 저장/공유 액션
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final isPlaying = _controller.isAnimating;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1C23),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF2C2F3A),
                                      ),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 12,
                                          ),
                                      activeTrackColor: teamColor,
                                      inactiveTrackColor: const Color(
                                        0xFF2A2D37,
                                      ),
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: _controller.value,
                                      onChanged: (val) {
                                        _controller.stop();
                                        _controller.value = val;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _replay,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1C23),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF2C2F3A),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.replay_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                InkWell(
                                  onTap: _isExportingVideo
                                      ? null
                                      : _saveToGallery,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1C23),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF2C2F3A),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          '이미지',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: _isExportingVideo
                                        ? null
                                        : () => _exportVideo(shareAfter: false),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: teamColor,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            '동영상 저장',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _isExportingVideo
                                      ? null
                                      : () => _showShareOptionsSheet(teamColor),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1C23),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF2C2F3A),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.share_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          '공유',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_isPreparingPhotos)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0A0B0F).withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: teamColor,
                          strokeWidth: 3.5,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '직관 추억 사진 불러오는 중...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isExportingVideo)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15171E),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: teamColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _exportProgress / 100,
                                  strokeWidth: 4.5,
                                  color: teamColor,
                                  backgroundColor: const Color(0xFF2A2D37),
                                ),
                                Text(
                                  '$_exportProgress%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '직관 여정 동영상 생성 중...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '잠시만 기다려 주세요',
                            style: TextStyle(
                              color: Color(0xFF8B92A5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryPhotoCard({
    required RecapStep step,
    required double stepFraction,
    required Color teamColor,
  }) {
    // 라인 도착 이후에만 사진 표시 (첫 스텝은 출발지이므로 즉시 표시)
    final bool isCrossSea = IntuitionRecapData.isCrossSeaStep(step);
    final double arrivalAt = step.index == 0 ? 0.0 : (isCrossSea ? 0.45 : 0.35);
    if (stepFraction < arrivalAt) {
      return const SizedBox.shrink();
    }

    final double photoT = ((stepFraction - arrivalAt) / (1.0 - arrivalAt))
        .clamp(0.0, 1.0);
    // 빠른 페이드 인(0.0~0.12) -> 충분히 오래 머무르기(0.12~0.88) -> 부드러운 페이드 아웃(0.88~1.0)
    double opacity = 1.0;
    if (photoT < 0.12) {
      opacity = (photoT / 0.12).clamp(0.0, 1.0);
    } else if (photoT > 0.88) {
      opacity = ((1.0 - photoT) / 0.12).clamp(0.0, 1.0);
    }
    final double zoomScale = 1.0 + (photoT * 0.07);
    final String resultBadge = step.result.isNotEmpty
        ? ' · ${step.result}'
        : '';

    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: -0.035,
        child: Container(
          width: 132,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF171922),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: teamColor.withValues(alpha: 0.6),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 120,
                  height: 112,
                  child: Transform.scale(
                    scale: zoomScale,
                    child: Image(
                      image: ResizeImage(
                        NetworkImage(step.imageUrls.first),
                        width: 360,
                      ),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF23262E),
                        child: const Icon(
                          Icons.photo_rounded,
                          color: Color(0xFF7B8190),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.date,
                style: TextStyle(
                  color: teamColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                '${step.oppTeam.isNotEmpty ? 'vs ${step.oppTeam}' : step.stadiumCode}$resultBadge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
