import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:confetti/confetti.dart';
import 'package:screenshot/screenshot.dart';

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
  });

  @override
  State<ChampionOverlay> createState() => _ChampionOverlayState();
}

class _ChampionOverlayState extends State<ChampionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  late Animation<double> _fade;
  late Animation<double> _trophyScale;
  late Animation<Offset> _trophySlide;
  late Animation<double> _identityOpacity;
  late Animation<double> _card1Opacity;
  late Animation<double> _card2Opacity;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _glowIntensity;

  late ConfettiController _confettiController;
  late AudioPlayer _audioPlayer;
  StreamSubscription? _audioSubscription;
  late Animation<double> _trophyFade;

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();
    _playChampionSound();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 4000), // 더 웅장하게 속도 조절
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.2),
    );

    _trophyFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn), // 서서히 밝아짐
    );

    _trophyScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.15,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 60,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.15,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOutCubic)),
            weight: 40,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.0, 0.6), // 더 일찍 시작하고 임팩트 있게
          ),
        );

    // 들어올리는(Lift up) 느낌을 주기 위해 슬라이드 범위를 조금 더 크게 조정
    _trophySlide =
        Tween<Offset>(
          begin: const Offset(0, 0.6), // 아래쪽에서 위로 솟아오름
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutQuart),
          ),
        );

    // 트로피가 충분히 보인 후 정보가 나타나도록 인터벌을 늦춤
    _identityOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.6, 0.8),
    );
    _card1Opacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.7, 0.9),
    );
    _card2Opacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 0.95),
    );

    _buttonSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.8, 1.0, curve: Curves.easeOutQuint),
          ),
        );

    _glowIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.linear),
      ),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    _mainController.forward();

    // 팀 우승 오버레이일 때만 응원가로 분위기를 띄웁니다.
    // 개인 우승 시에는 챔피언 사운드만 재생됩니다.
    if (widget.type == ChampionType.team) {
      _playTeamCheerSong();
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      _confettiController.play();
    });
  }

  Future<void> _playChampionSound() async {
    try {
      // 팀 우승 오버레이에서는 바로 응원가로 시작하길 원하는 유저 피드백 반영
      if (widget.type != ChampionType.team) {
        await _audioPlayer.play(AssetSource('audio/champion.mp3'));
      }
    } catch (e) {
      debugPrint('Audio play failed: $e');
    }
  }

  void _playTeamCheerSong() {
    final teamSongPath = _getTeamSongPath(widget.teamName ?? widget.winnerName);
    if (teamSongPath != null) {
      try {
        _audioPlayer.play(AssetSource(teamSongPath));
      } catch (e) {
        debugPrint('Team cheer song play failed: $e');
      }
    }
  }

  String? _getTeamSongPath(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('lg')) return 'audio/lgTeamSong.m4a';
    if (lowerName.contains('두산')) return 'audio/SeoulBears.m4a';
    if (lowerName.contains('삼성')) return 'audio/SamSungEldorado.m4a';
    if (lowerName.contains('롯데')) return 'audio/lotteTeamSong.m4a';
    if (lowerName.contains('기아')) return 'audio/kiaTeamSong.m4a';
    if (lowerName.contains('한화')) return 'audio/loveEagles.m4a';
    if (lowerName.contains('ssg') ||
        lowerName.contains('landers') ||
        lowerName.contains('sk'))
      return 'audio/landersTeamSong.m4a';
    if (lowerName.contains('키움') ||
        lowerName.contains('heroes') ||
        lowerName.contains('넥센'))
      return 'audio/heroesTeamSong.m4a';
    if (lowerName.contains('nc')) return 'audio/ncTeamSong.m4a';
    if (lowerName.contains('kt')) return 'audio/ktWinningLoud.m4a';
    return null;
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _mainController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _captureAndAction({required bool isFeed}) async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        if (isFeed) {
          widget.onShareFeed?.call(imageBytes);
        } else {
          widget.onShareSNS?.call(imageBytes);
        }
      }
    } catch (e) {
      debugPrint('Screen capture failed: $e');
    }
  }

  void _showShareOptions(BuildContext context) {
    const goldColor = Color(0xFFE9C46A);
    const deepBlue = Color(0xFF030D1E);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: deepBlue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.type == ChampionType.unified
                  ? '통합 우승 소식 전하기'
                  : (widget.type == ChampionType.individual
                        ? '나의 활약 공유하기'
                        : '구단 우승 공유하기'),
              style: const TextStyle(
                fontFamily: 'kbo',
                color: goldColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),
            _buildShareOption(
              icon: Icons.rss_feed_rounded,
              title: '피드에 자랑하기',
              subtitle: widget.type == ChampionType.unified
                  ? '나와 우리 팀의 완벽한 1위를 알립니다'
                  : (widget.type == ChampionType.individual
                        ? '나의 트로피 이미지를 커뮤니티에 공유합니다'
                        : '우승 구단의 영광을 커뮤니티에 공유합니다'),
              onTap: () {
                Navigator.pop(context);
                _captureAndAction(isFeed: true);
              },
              color: goldColor,
            ),
            const SizedBox(height: 16),
            _buildShareOption(
              icon: Icons.share_rounded,
              title: '외부로 공유하기',
              subtitle: '카카오톡, 인스타그램 등으로 전송합니다',
              onTap: () {
                Navigator.pop(context);
                _captureAndAction(isFeed: false);
              },
              color: Colors.white,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'kbo',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFE9C46A);
    const deepBlue = Color(0xFF030D1E);
    const cardBg = Color(0xFF0C1B33);

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fade,
        child: Screenshot(
          controller: _screenshotController,
          child: Stack(
            children: [
              Container(color: deepBlue),
              _buildAnimatedBackground(goldColor),

              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: ParticlePainter(
                  animation: _particleController,
                  color: goldColor,
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: _identityOpacity,
                      child: _buildHeader(goldColor),
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 3. Trophy Section
                            Flexible(
                              flex: 5,
                              child: FadeTransition(
                                opacity: _trophyFade,
                                child: SlideTransition(
                                  position: _trophySlide,
                                  child: ScaleTransition(
                                    scale: _trophyScale,
                                    child: _buildChampionCard(
                                      goldColor,
                                      cardBg,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 45),

                            // 4. Nickname & Identity
                            FadeTransition(
                              opacity: _identityOpacity,
                              child: Column(
                                children: [
                                  Text(
                                    widget.type == ChampionType.unified
                                        ? '${widget.winnerName} & ${widget.teamName}'
                                        : (widget.type == ChampionType.team
                                              ? (widget.teamName ?? '우리 팀')
                                              : widget.winnerName),
                                    style: const TextStyle(
                                      fontFamily: 'kbo',
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome,
                                        color: goldColor,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.type == ChampionType.unified
                                            ? 'DOUBLE CHAMPIONS!'
                                            : (widget.type ==
                                                      ChampionType.individual
                                                  ? 'SEASON CHAMPION'
                                                  : 'OFFICIAL TEAM WINNER'),
                                        style: TextStyle(
                                          fontFamily: 'kbo',
                                          fontSize: 14,
                                          color: goldColor.withOpacity(0.9),
                                          letterSpacing: 2.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.auto_awesome,
                                        color: goldColor,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // 5. Info Cards
                            Flexible(
                              flex: 3,
                              child: Column(
                                children: [
                                  FadeTransition(
                                    opacity: _card1Opacity,
                                    child: _buildInfoCard(
                                      title: widget.type == ChampionType.unified
                                          ? '시즌 총점 & 구단 기여도'
                                          : (widget.type ==
                                                    ChampionType.individual
                                                ? '시즌 총점'
                                                : '구단 통합 점수'),
                                      value:
                                          (widget.rankingUserModel?.score ??
                                                  widget.totalScore)
                                              .toString(),
                                      suffix: '점',
                                      icon: Icons.emoji_events_rounded,
                                      accentColor: goldColor,
                                      cardBg: cardBg,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FadeTransition(
                                    opacity: _card2Opacity,
                                    child: _buildInfoCard(
                                      title: widget.type == ChampionType.unified
                                          ? '통합 순위 (개인 1위 & 팀 1위)'
                                          : (widget.type ==
                                                    ChampionType.individual
                                                ? '현재 순위'
                                                : '구단 최종 순위'),
                                      value: widget.currentRank,
                                      icon: Icons.stars_rounded,
                                      accentColor: Colors.white,
                                      cardBg: cardBg,
                                      isRank: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // 6. Share Button
                            SlideTransition(
                              position: _buttonSlide,
                              child: _buildPrimaryButton(
                                label: widget.type == ChampionType.unified
                                    ? '통합 우승 역사 공유하기'
                                    : (widget.type == ChampionType.individual
                                          ? '나의 승리 공유하기'
                                          : '구단 우승 공유하기'),
                                icon: widget.type == ChampionType.unified
                                    ? Icons.auto_awesome
                                    : Icons.share_rounded,
                                color: goldColor,
                                onPressed: () => _showShareOptions(context),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 50,
                  colors: const [goldColor, Colors.white, Colors.amber],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color goldColor) {
    String label = widget.seasonLabel;
    if (widget.type == ChampionType.team) label = 'TEAM CHAMPION';
    if (widget.type == ChampionType.unified) label = 'UNIFIED CHAMPIONS';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'kbo',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: goldColor,
              letterSpacing: 1.2,
              shadows: [
                Shadow(color: goldColor.withOpacity(0.4), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildChampionCard(Color goldColor, Color cardBg) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: goldColor.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withOpacity(0.15 * _glowIntensity.value),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
              image: const DecorationImage(
                image: AssetImage(
                  'assets/images/quiz/quiz_trophy_champion.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(-400 + (_shimmerController.value * 800), 0),
                    child: Transform.rotate(
                      angle: -pi / 4,
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.type == ChampionType.unified)
            _buildUnifiedLogos(goldColor)
          else
            Positioned(
              bottom: -35,
              child: _buildSingleLogo(
                url: widget.type == ChampionType.team
                    ? widget.teamLogoUrl
                    : widget.avatarUrl,
                isAsset: widget.type == ChampionType.team,
                goldColor: goldColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnifiedLogos(Color goldColor) {
    return Positioned(
      bottom: -40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User Avatar
          _buildSingleLogo(
            url: widget.avatarUrl,
            isAsset: false,
            goldColor: goldColor,
            size: 80,
          ),
          const SizedBox(width: 8),
          // "X" or "V" icon divider
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: Color(0xFFE9C46A), size: 16),
          ),
          const SizedBox(width: 8),
          // Team Logo
          _buildSingleLogo(
            url: widget.teamLogoUrl,
            isAsset: true,
            goldColor: goldColor,
            size: 80,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLogo({
    required String? url,
    required bool isAsset,
    required Color goldColor,
    double size = 75,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: goldColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1322),
          borderRadius: BorderRadius.circular(10),
          image: url != null
              ? DecorationImage(
                  image: isAsset
                      ? AssetImage(url) as ImageProvider
                      : NetworkImage(url),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: url == null
            ? Icon(Icons.person, color: Colors.white24, size: size * 0.45)
            : null,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    String suffix = '',
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    bool isRank = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.08), size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (isRank)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.stars,
                          color: Color(0xFFE9C46A),
                          size: 18,
                        ),
                      ),
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'kbo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          suffix,
                          style: TextStyle(
                            fontSize: 13,
                            color: accentColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'kbo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(Color goldColor) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.5,
              colors: [
                goldColor.withOpacity(0.12 * _glowIntensity.value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  ParticlePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..color = color.withOpacity(0.15);

    for (int i = 0; i < 30; i++) {
      final double x = random.nextDouble() * size.width;
      final double yBase = random.nextDouble() * size.height;
      final double speed = 0.5 + random.nextDouble();
      final double y = (yBase - (animation.value * 200 * speed)) % size.height;
      final double s = 1.0 + random.nextDouble() * 3.0;

      canvas.drawCircle(Offset(x, y), s, paint);
      if (i % 5 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          s * 2.5,
          Paint()
            ..color = color.withOpacity(0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
