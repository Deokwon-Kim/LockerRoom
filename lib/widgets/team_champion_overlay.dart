import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/ceremony_video_exporter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class TeamChampionOverlay extends StatefulWidget {
  final String teamName;
  final String seasonLabel;
  final String seasonShortCode;
  final double teamAvg;
  final int teamHits;
  final int teamAtBats;
  final String? teamLogoPath;
  final List<BattingKingEntry> topContributors;
  final VoidCallback onDismiss;

  const TeamChampionOverlay({
    super.key,
    required this.teamName,
    required this.seasonLabel,
    required this.seasonShortCode,
    required this.teamAvg,
    required this.teamHits,
    required this.teamAtBats,
    this.teamLogoPath,
    this.topContributors = const [],
    required this.onDismiss,
  });

  @override
  State<TeamChampionOverlay> createState() => _TeamChampionOverlayState();
}

class _TeamChampionOverlayState extends State<TeamChampionOverlay>
    with SingleTickerProviderStateMixin {
  static const double _totalSec = 11.5;

  late AnimationController _timelineController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey _captureKey = GlobalKey();

  bool _isExportingImage = false;
  bool _isExportingVideo = false;
  double _exportProgress = 0.0;
  double? _manualSeekProgress;

  late final List<_TeamBokehParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(77);
    _particles = List.generate(
      24,
      (_) => _TeamBokehParticle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.05 + rng.nextDouble() * 0.09,
        radius: 2.0 + rng.nextDouble() * 4.5,
        alpha: 0.12 + rng.nextDouble() * 0.25,
      ),
    );

    _timelineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11500),
    )..forward();

    _playCeremonyBgm();
  }

  Future<void> _playCeremonyBgm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(0.95);
      await _audioPlayer.play(AssetSource('audio/batting_king_ceremony.m4a'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _timelineController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  double get _effectiveT => _manualSeekProgress ?? _timelineController.value;

  double _interval(double t, double startSec, double endSec) {
    final s = startSec / _totalSec;
    final e = endSec / _totalSec;
    if (e <= s) return 0.0;
    return ((t - s) / (e - s)).clamp(0.0, 1.0);
  }

  String _formatAvg(double avg) {
    if (avg >= 1.0) return avg.toStringAsFixed(3);
    final str = avg.toStringAsFixed(3);
    return str.startsWith('0.') ? str.substring(1) : str;
  }

  List<_ContributorDisplay> get _resolvedContributors {
    if (widget.topContributors.isNotEmpty) {
      return widget.topContributors
          .take(3)
          .map(
            (e) => _ContributorDisplay(
              name: e.name.isNotEmpty ? e.name : '익명 팬',
              hits: e.totalHits,
              avgStr: e.formattedBattingAverage,
            ),
          )
          .toList();
    }
    return const [
      _ContributorDisplay(name: '콩콩', hits: 42, avgStr: '.893'),
      _ContributorDisplay(name: '베어', hits: 38, avgStr: '.844'),
      _ContributorDisplay(name: '잠실', hits: 35, avgStr: '.814'),
    ];
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  Future<void> _saveAwardImage() async {
    if (_isExportingImage || _isExportingVideo) return;
    setState(() => _isExportingImage = true);
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          _showToast('사진첩 접근 권한이 필요합니다.');
          return;
        }
      }
      final bytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Material(
            color: const Color(0xFF06070B),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: _buildCaptureFrame(1.0),
            ),
          ),
        ),
        pixelRatio: 3.0,
      );
      await Gal.putImageBytes(
        bytes,
        name: 'ILU_team_champion_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showToast('구단 챔피언 이미지가 사진첩에 저장되었습니다.');
    } catch (e) {
      _showToast('이미지 저장 중 오류가 발생했습니다: $e');
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
    String? mp4Path;
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          _showToast('사진첩 접근 권한이 필요합니다.');
          return;
        }
      }
      _timelineController.stop();
      mp4Path = await CeremonyVideoExporter.exportCeremonyMp4(
        boundaryKey: _captureKey,
        totalDuration: const Duration(milliseconds: 11500),
        fps: 24,
        onSeekTimeline: (p) {
          if (mounted) {
            setState(() => _manualSeekProgress = p);
          }
        },
        onEncodingProgress: (p) {
          if (mounted) {
            setState(() => _exportProgress = p);
          }
        },
      );
      await Gal.putVideo(mp4Path);
      _showToast('구단 챔피언 MP4 영상이 사진첩에 저장되었습니다.');
    } catch (e) {
      _showToast('영상 저장에 실패했습니다: $e');
    } finally {
      if (mp4Path != null) {
        try {
          final f = File(mp4Path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _manualSeekProgress = null;
          _isExportingVideo = false;
          _exportProgress = 0.0;
        });
        _timelineController.value = 1.0;
      }
    }
  }

  Future<void> _openShareSheet() async {
    if (_isExportingImage || _isExportingVideo) return;
    final shareText =
        '🏆 ${widget.seasonLabel} 구단 챔피언 ${widget.teamName}! 팀 합산 타율 ${_formatAvg(widget.teamAvg)} (${widget.teamAtBats}타수 ${widget.teamHits}안타)';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121521),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '구단 챔피언 기록 외부 공유',
                  style: TextStyle(
                    fontFamily: 'kbo',
                    color: Color(0xFFF7E09B),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  shareText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildShareOptionTile(
                        icon: Icons.image_outlined,
                        title: '이미지(PNG) 공유',
                        subtitle: '인스타 스토리 · 카톡',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _shareAsImage(shareText);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildShareOptionTile(
                        icon: Icons.movie_creation_outlined,
                        title: '영상(MP4) 공유',
                        subtitle: '11.5초 5막 + BGM',
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _shareAsVideo(shareText);
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF7E09B), size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsImage(String shareText) async {
    setState(() => _isExportingImage = true);
    try {
      final bytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Material(
            color: const Color(0xFF06070B),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: _buildCaptureFrame(1.0),
            ),
          ),
        ),
        pixelRatio: 3.0,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/team_champion_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: shareText);
    } catch (e) {
      _showToast('이미지 공유에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isExportingImage = false);
    }
  }

  Future<void> _shareAsVideo(String shareText) async {
    setState(() {
      _isExportingVideo = true;
      _exportProgress = 0.0;
    });
    String? mp4Path;
    try {
      _timelineController.stop();
      mp4Path = await CeremonyVideoExporter.exportCeremonyMp4(
        boundaryKey: _captureKey,
        totalDuration: const Duration(milliseconds: 11500),
        fps: 24,
        onSeekTimeline: (p) {
          if (mounted) setState(() => _manualSeekProgress = p);
        },
        onEncodingProgress: (p) {
          if (mounted) setState(() => _exportProgress = p);
        },
      );
      await Share.shareXFiles([
        XFile(mp4Path, mimeType: 'video/mp4'),
      ], text: shareText);
    } catch (e) {
      _showToast('영상 공유에 실패했습니다: $e');
    } finally {
      if (mp4Path != null) {
        try {
          final f = File(mp4Path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _manualSeekProgress = null;
          _isExportingVideo = false;
          _exportProgress = 0.0;
        });
        _timelineController.value = 1.0;
      }
    }
  }

  Color _resolveTeamColor(TeamProvider tp) {
    return tp.findTeamByName(widget.teamName)?.color ??
        tp.selectedTeam?.color ??
        const Color(0xFFED1C24);
  }

  String? _resolveTeamLogo(TeamProvider tp) {
    return widget.teamLogoPath ?? tp.findTeamByName(widget.teamName)?.logoPath;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF06070B),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: _captureKey,
              child: AnimatedBuilder(
                animation: _timelineController,
                builder: (context, _) => _buildCaptureFrame(_effectiveT),
              ),
            ),
          ),

          // 우상단 닫기 버튼
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
                        '구단 챔피언 MP4 생성 중...',
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

  Widget _buildCaptureFrame(double t) {
    final teamProvider = context.read<TeamProvider>();
    final teamColor = _resolveTeamColor(teamProvider);
    final logoPath = _resolveTeamLogo(teamProvider);
    final sec = t * _totalSec;

    double flashP = 0.0;
    if (sec >= 7.0 && sec <= 7.3) {
      final fp = (sec - 7.0) / 0.3;
      flashP = fp < 0.3 ? (fp / 0.3) * 0.65 : (1 - (fp - 0.3) / 0.7) * 0.65;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(teamColor, const Color(0xFF06070B), 0.74)!,
            const Color(0xFF070910),
            const Color(0xFF05060A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            right: -40,
            height: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [
                    teamColor.withValues(alpha: 0.38),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TeamBokehPainter(
                  particles: _particles,
                  progress: t,
                  color: teamColor,
                ),
              ),
            ),
          ),

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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: Curves.easeOut.transform(_interval(t, 0.0, 0.7)),
                      child: _buildBroadcastHeader(teamColor),
                    ),
                  ),

                  if (sec < 9.2)
                    Center(child: _buildSoloActs(t, sec, teamColor, logoPath)),

                  if (sec >= 9.2) _buildGrandFinale(t, teamColor, logoPath),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastHeader(Color teamColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: teamColor,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '2026 ILU TEAM CHAMPION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'BROADCAST INTRO',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloActs(
    double t,
    double sec,
    Color teamColor,
    String? logoPath,
  ) {
    // Act 1 (0.0s ~ 2.4s): 구단 합산 타율
    if (sec < 2.4) {
      final inP = Curves.easeOutExpo.transform(_interval(t, 0.0, 0.6));
      final outP = sec > 2.0 ? 1.0 - _interval(t, 2.0, 2.4) : 1.0;
      final rollP = Curves.easeOutCubic.transform(_interval(t, 0.55, 1.55));
      final curAvg = widget.teamAvg * rollP;
      return Opacity(
        opacity: (_interval(t, 0.0, 0.45) * outP).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-68 * (1 - inP), 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TEAM BATTING AVERAGE',
                style: TextStyle(
                  color: Color(0xFFC99A2E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatAvg(curAvg),
                style: const TextStyle(
                  fontFamily: 'kbo',
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF7E09B),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Act 2 (2.4s ~ 4.8s): 구단 합산 타수·안타
    if (sec < 4.8) {
      final inP = _interval(t, 2.4, 2.9);
      final outP = sec > 4.4 ? 1.0 - _interval(t, 4.4, 4.8) : 1.0;
      final rollP = Curves.easeOutCubic.transform(_interval(t, 2.9, 3.9));
      final ab = (widget.teamAtBats * rollP).round();
      final hits = (widget.teamHits * rollP).round();
      return Opacity(
        opacity: (inP * outP).clamp(0.0, 1.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SEASON TEAM RECORD',
              style: TextStyle(
                color: Color(0xFFC99A2E),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$ab',
                  style: const TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF7E09B),
                  ),
                ),
                const Text(
                  '타수  ·  ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$hits',
                  style: const TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF7E09B),
                  ),
                ),
                const Text(
                  '안타',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Act 3 (4.8s ~ 7.0s): 구단 컬러 와이프 배너 + 실제 구단 로고
    if (sec < 7.0) {
      final inP = Curves.easeOutExpo.transform(_interval(t, 4.8, 5.6));
      final outP = sec > 6.5 ? 1.0 - _interval(t, 6.5, 7.0) : 1.0;
      return Opacity(
        opacity: (_interval(t, 4.8, 5.3) * outP).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-54 * (1 - inP), 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(teamColor, Colors.black, 0.35)!,
                    teamColor.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Stack(
                children: [
                  if (logoPath != null)
                    Positioned(
                      right: -12,
                      top: -12,
                      child: Opacity(
                        opacity: 0.14,
                        child: Image.asset(
                          logoPath,
                          width: 118,
                          height: 118,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogoBadge(logoPath, size: 70),
                        const SizedBox(height: 12),
                        const Text(
                          'MONTHLY TEAM CHAMPIONS',
                          style: TextStyle(
                            color: Color(0xFFF7E09B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.teamName,
                          style: const TextStyle(
                            fontFamily: 'kbo',
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          '구단 합산 타율 1위 등극',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Act 4 (7.0s ~ 9.2s): 3D 우승 컵 트로피 + TOP 3 팬 클라이맥스
    final inP = Curves.easeOutExpo.transform(_interval(t, 7.0, 7.85));
    final outP = sec > 8.7 ? 1.0 - _interval(t, 8.7, 9.2) : 1.0;
    final top3 = _resolvedContributors;
    final medals = ['🥇', '🥈', '🥉'];

    return Opacity(
      opacity: (_interval(t, 7.0, 7.5) * outP).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1.12 - 0.12 * inP,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTeamTrophyPlaque(width: 190, height: 162),
            const SizedBox(height: 10),
            Text(
              widget.teamName,
              style: const TextStyle(
                fontFamily: 'kbo',
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              '구단 최다 안타 공헌 TOP 3 팬',
              style: TextStyle(
                color: Color(0xFFF7E09B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: List.generate(top3.length, (i) {
                final c = top3[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D111C).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${medals[i]} ${c.name} · ${c.hits}안타',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoBadge(String? logoPath, {double size = 56}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: logoPath != null
          ? Image.asset(logoPath, fit: BoxFit.contain)
          : Center(
              child: Text(
                widget.teamName.characters.take(2).toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _buildTeamTrophyPlaque({
    required double width,
    required double height,
  }) {
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
              'assets/images/team_champion_trophy.jpg',
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.lighten,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFCBD5E1),
                  Color(0xFF94A3B8),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              '${widget.seasonShortCode} TEAM CHAMPION CUP',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrandFinale(double t, Color teamColor, String? logoPath) {
    final finaleP = Curves.easeOutCubic.transform(_interval(t, 9.2, 10.4));
    final avgStr = _formatAvg(widget.teamAvg);
    final top3 = _resolvedContributors;
    final medals = ['🥇', '🥈', '🥉'];

    return Opacity(
      opacity: finaleP,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - finaleP)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 38, bottom: 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 42).clamp(0.0, 2000.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 상단 구단 로고 + 팀명 + 실사 우승 컵 배너
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(teamColor, Colors.black, 0.25)!,
                            teamColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildLogoBadge(logoPath, size: 58),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.seasonLabel} 구단 챔피언',
                                  style: const TextStyle(
                                    color: Color(0xFFF7E09B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.teamName,
                                  style: const TextStyle(
                                    fontFamily: 'kbo',
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '구단 합산 ${widget.teamAtBats}타수 · ${widget.teamHits}안타',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: ShaderMask(
                                shaderCallback: (rect) => const RadialGradient(
                                  radius: 0.6,
                                  colors: [Colors.white, Colors.transparent],
                                  stops: [0.6, 1.0],
                                ).createShader(rect),
                                blendMode: BlendMode.dstIn,
                                child: Image.asset(
                                  'assets/images/team_champion_trophy.jpg',
                                  fit: BoxFit.cover,
                                  colorBlendMode: BlendMode.lighten,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4-cell 팀 스탯 슬래브
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10121C).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildSlabCell('TEAM AVG', avgStr, highlight: true),
                          _buildSlabCell(
                            'AB / HITS',
                            '${widget.teamAtBats} / ${widget.teamHits}',
                          ),
                          _buildSlabCell('TOP FAN', top3.first.name),
                          _buildSlabCell('RANK', '1위', highlight: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // TOP 3 공헌 팬
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10121C).withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '구단 최다 안타 공헌 TOP 3 팬',
                            style: TextStyle(
                              color: Color(0xFFF7E09B),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: List.generate(top3.length, (i) {
                              final c = top3[i];
                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: i < top3.length - 1 ? 6 : 0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${medals[i]} ${c.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.hits}안타 · ${c.avgStr}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 소속 팬 보상 3종
                    _buildRewardCard(
                      teamColor,
                      Icons.emoji_events_rounded,
                      '우승 구단 뱃지 지급',
                      '${widget.seasonShortCode} 팀 챔피언 공식 뱃지 해금',
                    ),
                    const SizedBox(height: 7),
                    _buildRewardCard(
                      teamColor,
                      Icons.military_tech_rounded,
                      '소속 팬 칭호: ${widget.seasonShortCode} 우승 구단 팬',
                      '다음 시즌 동안 로비 및 프로필 칭호 배지 노출',
                    ),
                    const SizedBox(height: 7),
                    _buildRewardCard(
                      teamColor,
                      Icons.flag_rounded,
                      '다음 시즌 구단 디펜딩 배너',
                      '퀴즈 로비 및 팀 랭킹 상단 챔피언 리본 적용',
                    ),
                    const SizedBox(height: 12),

                    // CTA + 저장/공유 액션 바
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teamColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '구단 우승 축하 확인',
                          style: TextStyle(
                            fontFamily: 'kbo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'kbo',
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: highlight ? const Color(0xFFF7E09B) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(
    Color teamColor,
    IconData icon,
    String title,
    String desc,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: teamColor.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFF7E09B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 10.5),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFF7E09B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorDisplay {
  final String name;
  final int hits;
  final String avgStr;
  const _ContributorDisplay({
    required this.name,
    required this.hits,
    required this.avgStr,
  });
}

class _TeamBokehParticle {
  final double x;
  final double y;
  final double speed;
  final double radius;
  final double alpha;
  const _TeamBokehParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.alpha,
  });
}

class _TeamBokehPainter extends CustomPainter {
  final List<_TeamBokehParticle> particles;
  final double progress;
  final Color color;

  _TeamBokehPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final masterAlpha = (progress / 0.08).clamp(0.0, 1.0);
    if (masterAlpha <= 0) return;

    final hsl = HSLColor.fromColor(color);
    final glowColor = hsl.lightness < 0.45
        ? hsl
              .withLightness(0.60)
              .withSaturation(
                hsl.saturation > 0.15
                    ? hsl.saturation.clamp(0.45, 0.90)
                    : hsl.saturation,
              )
              .toColor()
        : color;

    for (final p in particles) {
      final dy = ((p.y - progress * p.speed * 10) % 1.0);
      final cy = (dy < 0 ? dy + 1.0 : dy) * size.height;
      final cx = p.x * size.width;
      final paint = Paint()
        ..color = glowColor.withValues(alpha: p.alpha * masterAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx, cy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TeamBokehPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
