import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/ceremony_video_exporter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

enum ChampionType { individual, team, unified }

class ChampionOverlay extends StatefulWidget {
  final String winnerName;
  final String? teamName; // 통합 우승 시 사용
  final String seasonLabel;
  final int totalScore;
  final int? teamScore; // 통합 우승 시 사용
  final String currentRank;
  final String? avatarUrl;
  final String? teamLogoUrl; // 통합 우승 시 사용
  final VoidCallback onDismiss;
  final Function(Uint8List imageBytes)? onShareFeed;
  final Function(Uint8List imageBytes)? onShareSNS;
  final RankingUserModel? rankingUserModel;
  final ChampionType type;

  // 월간 타격왕 전용 메타 (하위 호환 optional)
  final double? seasonAvg;
  final int? totalHits;
  final int? totalAtBats;
  final int? maxCombo;
  final String? titleLabel;

  const ChampionOverlay({
    super.key,
    this.winnerName = '익명 야구팬',
    this.teamName,
    this.seasonLabel = '시즌 챔피언',
    this.totalScore = 0,
    this.teamScore,
    this.currentRank = '챔피언',
    this.avatarUrl,
    this.teamLogoUrl,
    required this.onDismiss,
    this.onShareFeed,
    this.onShareSNS,
    this.rankingUserModel,
    this.type = ChampionType.individual,
    this.seasonAvg,
    this.totalHits,
    this.totalAtBats,
    this.maxCombo,
    this.titleLabel,
  });

  @override
  State<ChampionOverlay> createState() => _ChampionOverlayState();
}

class _ChampionOverlayState extends State<ChampionOverlay>
    with TickerProviderStateMixin {
  static const Duration _ceremonyDuration = Duration(milliseconds: 11500);

  late AnimationController _mainController;
  late AnimationController _ambientController;
  late AudioPlayer _audioPlayer;

  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _ceremonyBoundaryKey = GlobalKey();

  bool _isExportingImage = false;
  bool _isExportingVideo = false;
  double _exportProgress = 0.0;

  double get _resolvedAvg {
    if (widget.seasonAvg != null && widget.seasonAvg! > 0) {
      return widget.seasonAvg!.clamp(0.0, 1.0);
    }
    if ((widget.totalAtBats ?? 0) > 0 && (widget.totalHits ?? 0) >= 0) {
      return (widget.totalHits! / widget.totalAtBats!).clamp(0.0, 1.0);
    }
    return 0.893;
  }

  int get _resolvedAtBats => widget.totalAtBats ?? 30;
  int get _resolvedHits =>
      widget.totalHits ?? (_resolvedAvg * _resolvedAtBats).round();
  int get _resolvedStreak => widget.maxCombo ?? 11;

  String _formatAvg(double avg) {
    final thousandths = (avg * 1000).round().clamp(0, 1000);
    if (thousandths >= 1000) return '1.000';
    return '.${thousandths.toString().padLeft(3, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playChampionSound();

    _mainController = AnimationController(
      duration: _ceremonyDuration,
      vsync: this,
    );

    _ambientController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    _mainController.forward();
  }

  Future<void> _playChampionSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/batting_king_ceremony.m4a'));
    } catch (e) {
      debugPrint('Ceremony audio play failed: $e');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _ambientController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showStatusSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFF991B1B)
            : const Color(0xFF151926),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAwardImage() async {
    if (_isExportingImage || _isExportingVideo) return;
    setState(() => _isExportingImage = true);
    try {
      final bytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 20),
      );
      if (bytes == null) {
        _showStatusSnack('이미지 캡처에 실패했습니다.', isError: true);
        return;
      }
      await Gal.putImageBytes(
        bytes,
        name: 'batting_king_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showStatusSnack('✓ 타격왕 수상 카드가 갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('Save award image failed: $e');
      _showStatusSnack('이미지 저장 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingImage = false);
    }
  }

  Future<void> _saveAwardVideo() async {
    if (_isExportingVideo || _isExportingImage) return;
    setState(() {
      _isExportingVideo = true;
      _exportProgress = 0.0;
    });

    final prevValue = _mainController.value;
    String? mp4Path;
    try {
      _mainController.stop();
      mp4Path = await CeremonyVideoExporter.exportCeremonyMp4(
        boundaryKey: _ceremonyBoundaryKey,
        totalDuration: _ceremonyDuration,
        onSeekTimeline: (p) {
          if (mounted) _mainController.value = p.clamp(0.0, 1.0);
        },
        onEncodingProgress: (p) {
          if (mounted) setState(() => _exportProgress = p.clamp(0.0, 1.0));
        },
      );
      await Gal.putVideo(mp4Path);
      _showStatusSnack('✓ 시상식 MP4 영상이 갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('Save award video failed: $e');
      _showStatusSnack('영상 저장 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mp4Path != null) {
        try {
          final f = File(mp4Path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) {
        _mainController.value = prevValue;
        setState(() {
          _isExportingVideo = false;
          _exportProgress = 0.0;
        });
      }
    }
  }

  Future<void> _shareExternal({required bool asVideo}) async {
    if (_isExportingVideo || _isExportingImage) return;
    final shareText =
        '👑 ${widget.seasonLabel} 타격왕 등극! ${widget.winnerName} · 타율 ${_formatAvg(_resolvedAvg)} ($_resolvedAtBats타수 $_resolvedHits안타)';

    if (!asVideo) {
      setState(() => _isExportingImage = true);
      File? tempImg;
      try {
        final bytes = await _screenshotController.capture(
          pixelRatio: 3.0,
          delay: const Duration(milliseconds: 20),
        );
        if (bytes == null) {
          _showStatusSnack('공유 이미지 생성에 실패했습니다.', isError: true);
          return;
        }
        final tempDir = await getTemporaryDirectory();
        tempImg = File(
          '${tempDir.path}/batting_king_share_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await tempImg.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles([XFile(tempImg.path)], text: shareText);
      } catch (e) {
        debugPrint('Share image failed: $e');
        _showStatusSnack('이미지 공유 중 오류가 발생했습니다.', isError: true);
      } finally {
        if (tempImg != null && await tempImg.exists()) {
          try {
            await tempImg.delete();
          } catch (_) {}
        }
        if (mounted) setState(() => _isExportingImage = false);
      }
      return;
    }

    setState(() {
      _isExportingVideo = true;
      _exportProgress = 0.0;
    });
    final prevValue = _mainController.value;
    String? mp4Path;
    try {
      _mainController.stop();
      mp4Path = await CeremonyVideoExporter.exportCeremonyMp4(
        boundaryKey: _ceremonyBoundaryKey,
        totalDuration: _ceremonyDuration,
        onSeekTimeline: (p) {
          if (mounted) _mainController.value = p.clamp(0.0, 1.0);
        },
        onEncodingProgress: (p) {
          if (mounted) setState(() => _exportProgress = p.clamp(0.0, 1.0));
        },
      );
      await Share.shareXFiles([XFile(mp4Path)], text: shareText);
    } catch (e) {
      debugPrint('Share video failed: $e');
      _showStatusSnack('영상 공유 중 오류가 발생했습니다.', isError: true);
    } finally {
      if (mp4Path != null) {
        try {
          final f = File(mp4Path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) {
        _mainController.value = prevValue;
        setState(() {
          _isExportingVideo = false;
          _exportProgress = 0.0;
        });
      }
    }
  }

  void _openShareSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '타격왕 수상 기록 공유',
                  style: TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF7E09B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '공유할 형식을 선택하세요',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildShareOptionTile(
                        icon: Icons.image_outlined,
                        title: '이미지 (PNG)',
                        subtitle: '고해상도 수상 카드',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _shareExternal(asVideo: false);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildShareOptionTile(
                        icon: Icons.movie_creation_outlined,
                        title: '시상식 영상 (MP4)',
                        subtitle: '11.5초 5막 + 오케스트라',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _shareExternal(asVideo: true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF7E09B), size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  double _interval(double t, double startSec, double endSec) {
    final s = startSec / 11.5;
    final e = endSec / 11.5;
    if (t <= s) return 0.0;
    if (t >= e) return 1.0;
    return ((t - s) / (e - s)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ??
        const Color(0xFF131230);
    final titleText = widget.titleLabel ?? '타격왕';

    return Material(
      color: const Color(0xFF06070B),
      child: Stack(
        children: [
          Screenshot(
            controller: _screenshotController,
            child: RepaintBoundary(
              key: _ceremonyBoundaryKey,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _mainController,
                  _ambientController,
                ]),
                builder: (context, _) {
                  final t = _mainController.value;
                  final sec = t * 11.5;
                  final flashP = sec >= 7.0 && sec <= 7.35
                      ? math.sin(((sec - 7.0) / 0.35) * math.pi) * 0.65
                      : 0.0;

                  return Container(
                    color: const Color(0xFF06070B),
                    child: Stack(
                      children: [
                        // 1. 무대 스포트라이트 & 보케 배경
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CeremonyStagePainter(
                              teamColor: teamColor,
                              timelineSec: sec,
                              ambientPhase: _ambientController.value,
                            ),
                          ),
                        ),

                        // 2. Act 4 플래시
                        if (flashP > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                color: const Color(
                                  0xFFFFF7D6,
                                ).withValues(alpha: flashP.clamp(0.0, 1.0)),
                              ),
                            ),
                          ),

                        // 3. 메인 컨텐츠
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Stack(
                              children: [
                                // 상단 공식 시상식 헤더
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Opacity(
                                    opacity: Curves.easeOut.transform(
                                      _interval(t, 0.0, 0.7),
                                    ),
                                    child: _buildCeremonyHeader(),
                                  ),
                                ),

                                // Acts 1 ~ 4 단독 센터 스테이지
                                if (sec < 9.2)
                                  Center(
                                    child: _buildSoloActs(t, sec, teamColor),
                                  ),

                                // Act 5 그랜드 피날레
                                if (sec >= 9.2)
                                  _buildGrandFinale(t, teamColor, titleText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 우상단 닫기 버튼 (캡처 영역 밖)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ),
            ),
          ),

          // 동영상 인코딩 진행률 오버레이
          if (_isExportingVideo)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.78),
                alignment: Alignment.center,
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121521),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '시상식 MP4 영상 생성 중...',
                        style: TextStyle(
                          fontFamily: 'kbo',
                          color: Color(0xFFF7E09B),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '11.5초 5막 연출 + 오케스트라 BGM 합성',
                        style: TextStyle(color: Colors.white60, fontSize: 11.5),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _exportProgress,
                          minHeight: 7,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF7E09B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_exportProgress * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCeremonyHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '2026 ILU KBO AWARDS',
              style: TextStyle(
                color: Color(0xFFE5C158),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFFE5C158).withValues(alpha: 0.65),
                ),
              ),
              child: const Text(
                'OFFICIAL CEREMONY',
                style: TextStyle(
                  color: Color(0xFFFFF2C2),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'MONTHLY BATTING CHAMPION',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSoloActs(double t, double sec, Color teamColor) {
    // Act 1 (0.0s ~ 2.4s): SEASON AVG
    if (sec < 2.4) {
      final inP = Curves.easeOutExpo.transform(_interval(t, 0.0, 0.6));
      final outP = sec > 2.0 ? 1.0 - _interval(t, 2.0, 2.4) : 1.0;
      final rollP = Curves.easeOutCubic.transform(_interval(t, 0.6, 1.6));
      final avgNow = _resolvedAvg * rollP;

      return Opacity(
        opacity: (_interval(t, 0.0, 0.45) * outP).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-68 * (1 - inP), 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SEASON AVG',
                style: TextStyle(
                  color: Color(0xFFC99A2E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatAvg(avgNow),
                style: const TextStyle(
                  fontFamily: 'kbo',
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF7E09B),
                  letterSpacing: -1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Act 2 (2.4s ~ 4.8s): AB & HITS
    if (sec < 4.8) {
      final inP = _interval(t, 2.4, 2.9);
      final outP = sec > 4.4 ? 1.0 - _interval(t, 4.4, 4.8) : 1.0;
      final rollP = Curves.easeOutCubic.transform(_interval(t, 2.9, 3.9));
      final abNow = (_resolvedAtBats * rollP).round();
      final hitsNow = (_resolvedHits * rollP).round();

      return Opacity(
        opacity: (inP * outP).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.94 + 0.06 * Curves.easeOutExpo.transform(inP),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SEASON HITTING RECORD',
                style: TextStyle(
                  color: Color(0xFFC99A2E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$abNow타수',
                    style: const TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF7E09B),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$hitsNow안타',
                    style: const TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF7E09B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Act 3 (4.8s ~ 7.0s): Winner Name + Team
    if (sec < 7.0) {
      final inP = Curves.easeOutCubic.transform(_interval(t, 4.8, 5.7));
      final outP = sec > 6.5 ? 1.0 - _interval(t, 6.5, 7.0) : 1.0;

      return Opacity(
        opacity: (_interval(t, 4.8, 5.45) * outP).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 36 * (1 - inP)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.seasonLabel,
                style: const TextStyle(
                  color: Color(0xFFC99A2E),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.winnerName,
                style: const TextStyle(
                  fontFamily: 'kbo',
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (widget.teamName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFF7E09B).withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    widget.teamName!,
                    style: const TextStyle(
                      color: Color(0xFFFFF2C2),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Act 4 (7.0s ~ 9.2s): Solo Center Trophy Climax
    final inP = Curves.easeOutExpo.transform(_interval(t, 7.0, 7.9));
    final outP = sec > 8.7 ? 1.0 - _interval(t, 8.7, 9.2) : 1.0;
    return Opacity(
      opacity: (_interval(t, 7.0, 7.55) * outP).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1.12 - 0.12 * inP,
        child: _buildTrophyPlaque(width: 224, height: 176),
      ),
    );
  }

  Widget _buildTrophyPlaque({required double width, required double height}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: ShaderMask(
            shaderCallback: (rect) => const RadialGradient(
              radius: 0.58,
              colors: [Colors.white, Colors.white70, Colors.transparent],
              stops: [0.55, 0.82, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              'assets/images/batting_king_trophy.jpg',
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.lighten,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFF3C4),
                  Color(0xFFE6C15A),
                  Color(0xFFB8861B),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFFFF5C8).withValues(alpha: 0.75),
              ),
            ),
            child: Text(
              '${widget.titleLabel ?? widget.seasonLabel} · ${widget.winnerName}',
              style: const TextStyle(
                color: Color(0xFF161105),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrandFinale(double t, Color teamColor, String titleText) {
    final finaleP = Curves.easeOutCubic.transform(_interval(t, 9.2, 10.5));
    final avgStr = _formatAvg(_resolvedAvg);

    return Opacity(
      opacity: finaleP,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - finaleP)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 40, bottom: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 44).clamp(0.0, 2000.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 244,
                          height: 186,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFD4AF37).withValues(alpha: 0.22),
                                teamColor.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        _buildTrophyPlaque(width: 224, height: 174),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 수상자 바 (uniform border + ClipRRect로 좌측 팀 악센트 라인 안전 렌더링)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121523),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Container(width: 4, color: teamColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFF7E09B),
                                                    Color(0xFFC99A2E),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '수상자',
                                                style: TextStyle(
                                                  color: Color(0xFF06070B),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                widget.teamName != null
                                                    ? '${widget.winnerName} · ${widget.teamName}'
                                                    : widget.winnerName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        avgStr,
                                        style: const TextStyle(
                                          fontFamily: 'kbo',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFF7E09B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

              // 스탯 슬래브
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10121C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSlabCell('AVG', avgStr, highlight: true),
                    _buildSlabCell(
                      'AB / HITS',
                      '$_resolvedAtBats / $_resolvedHits',
                    ),
                    _buildSlabCell('STREAK', '$_resolvedStreak'),
                    _buildSlabCell('RANK', widget.currentRank, highlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // VIP 상패 보상 3종 카드
              _buildPlaqueCard(
                Icons.star_rounded,
                '영구 칭호: 👑 $titleText',
                '로비·랭킹·명예의 전당 골드 칭호 배지 공식 수여',
              ),
              const SizedBox(height: 7),
              _buildPlaqueCard(
                Icons.emoji_events_rounded,
                '명예의 전당 영구 헌액',
                '${widget.seasonLabel} 공식 아카이브 & 트로피 등록',
              ),
              const SizedBox(height: 7),
              _buildPlaqueCard(
                Icons.style_rounded,
                '디펜딩 특전: 찬스 카드 +1회',
                '다음 시즌 전 경기 비디오 판독/대타 찬스 1회 추가',
              ),
              const SizedBox(height: 12),

              // CTA 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF06070B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '수상 패 수령 및 명예의 전당 등재',
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 저장 & 공유 3분할 다크-골드 액션 바
              Row(
                children: [
                  Expanded(
                    child: _buildExportButton(
                      icon: Icons.image_outlined,
                      label: _isExportingImage ? '저장 중...' : '이미지 저장',
                      onTap: _saveAwardImage,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildExportButton(
                      icon: Icons.videocam_outlined,
                      label: _isExportingVideo ? '생성 중...' : '영상 저장',
                      onTap: _saveAwardVideo,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildExportButton(
                      icon: Icons.ios_share_rounded,
                      label: '외부 공유',
                      onTap: _openShareSheet,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlabCell(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: highlight ? const Color(0xFFF7E09B) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaqueCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF161522), Color(0xFF0D0D14)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF7E09B).withValues(alpha: 0.4),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFF7E09B), size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFF7DE),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFA3AEC2),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10121C).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFF7E09B), size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF7E09B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CeremonyStagePainter extends CustomPainter {
  final Color teamColor;
  final double timelineSec;
  final double ambientPhase;

  _CeremonyStagePainter({
    required this.teamColor,
    required this.timelineSec,
    required this.ambientPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boost = (timelineSec >= 7.0 && timelineSec <= 9.2) ? 0.25 : 0.0;
    final beamAlpha = (0.16 + boost).clamp(0.0, 0.45);

    // 좌/우 샴페인 골드 스포트라이트 빔
    final sway = math.sin(timelineSec * 1.1) * 24;
    final leftBeam = Path()
      ..moveTo(size.width * 0.16, 0)
      ..lineTo(size.width * 0.24, 0)
      ..lineTo(size.width * 0.72 + sway, size.height * 0.85)
      ..lineTo(size.width * 0.15 + sway, size.height * 0.85)
      ..close();
    canvas.drawPath(
      leftBeam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF0BE).withValues(alpha: beamAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final rightBeam = Path()
      ..moveTo(size.width * 0.76, 0)
      ..lineTo(size.width * 0.84, 0)
      ..lineTo(size.width * 0.85 - sway, size.height * 0.85)
      ..lineTo(size.width * 0.28 - sway, size.height * 0.85)
      ..close();
    canvas.drawPath(
      rightBeam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFF0BE).withValues(alpha: beamAlpha),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // 중앙 구단 컬러 림라이트
    final centerGlow = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * 0.34),
      radius: size.width * 0.65,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            teamColor.withValues(alpha: 0.28 + boost * 0.5),
            Colors.transparent,
          ],
        ).createShader(centerGlow),
    );

    // 부유 골드 스테이지 보케
    final bokehPaint = Paint();
    for (int i = 0; i < 18; i++) {
      final seedX = ((i * 73) % 100) / 100.0;
      final seedY = (((i * 41) % 100) / 100.0 - ambientPhase + 1.0) % 1.0;
      final radius = 2.0 + (i % 4) * 1.4;
      bokehPaint.color = const Color(
        0xFFF7E09B,
      ).withValues(alpha: 0.08 + (i % 3) * 0.05);
      canvas.drawCircle(
        Offset(size.width * seedX, size.height * seedY),
        radius,
        bokehPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CeremonyStagePainter oldDelegate) => true;
}
