import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lockerroom/widgets/season_result_overlay.dart';

class SeasonStartOverlay extends StatefulWidget {
  final String seasonLabel;
  final int userScore;
  final int? userRank;
  final int totalUsers;
  final Color? teamColor;
  final VoidCallback onDismiss;

  const SeasonStartOverlay({
    super.key,
    required this.seasonLabel,
    required this.userScore,
    this.userRank,
    required this.totalUsers,
    this.teamColor,
    required this.onDismiss,
  });

  @override
  State<SeasonStartOverlay> createState() => _SeasonStartOverlayState();
}

class _SeasonStartOverlayState extends State<SeasonStartOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rayController;
  late AnimationController _shineController;
  late Animation<double> _titleOpacity;
  late Animation<double> _trophyScale;
  late Animation<double> _statsOpacity;
  late Animation<double> _buttonOpacity;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playStartSound();

    // 전체 애니메이션 시간을 4.5초로 설정
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    );

    _rayController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _shineController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // 1. 타이틀 등장 (0 ~ 0.8초 부근)
    _titleOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.18, curve: Curves.easeIn),
    );

    // 2. 트로피 등장 (0.8 ~ 2.8초 부근)
    _trophyScale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.18, 0.62, curve: Curves.elasticOut),
    );

    // 3. 배너 등장 (2.8 ~ 3.8초 부근)
    _statsOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.62, 0.84, curve: Curves.easeIn),
    );

    // 4. 안내 문구 등장 (3.8 ~ 4.5초 부근)
    _buttonOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.84, 1.0, curve: Curves.easeIn),
    );

    _mainController.forward();
  }

  Future<void> _playStartSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/NewSeason.mp3'));
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rayController.dispose();
    _shineController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _getEmblemPath(String tier) {
    switch (tier) {
      case 'MVP':
        return 'assets/images/quiz/quiz_emblem_mvp.png';
      case 'ALL-STAR':
        return 'assets/images/quiz/quiz_emblem_allstar.png';
      case 'MAJOR':
        return 'assets/images/quiz/quiz_emblem_major.png';
      case 'MINOR':
        return 'assets/images/quiz/quiz_emblem_minor.png';
      default:
        return 'assets/images/quiz/quiz_emblem_prospect.png';
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'MVP':
        return const Color(0xFFB19CD9);
      case 'ALL-STAR':
        return const Color(0xFFFF4D4D);
      case 'MAJOR':
        return const Color(0xFFFFD700);
      case 'MINOR':
        return const Color(0xFFC0C0C0);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = QuizSeasonUtils.getTier(widget.userScore);
    final tierColor = _getTierColor(tier);

    return GestureDetector(
      onTap: () {
        _audioPlayer.stop();
        widget.onDismiss();
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 1. Background Particles
            ...List.generate(12, (index) => _buildFloatingParticle(index)),

            // 2. Unified Premium Gradient Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF030D1E),
                    Color(0xFF0A1322),
                    Color(0xFF050F22),
                  ],
                ),
              ),
            ),

            Positioned.fill(
              child: CustomPaint(
                painter: ResultBackgroundPainter(color: tierColor),
              ),
            ),

            // 2-1. Team-themed Accent Aura (Subtle)
            if (widget.teamColor != null)
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      widget.teamColor!.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 3. Top Title: "새 시즌이 시작되었습니다."
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: const Text(
                      '새 시즌이 시작되었습니다.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFD700), // Gold/Yellow
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Central Emblem
                  ScaleTransition(
                    scale: _trophyScale,
                    child: Container(
                      width: 280,
                      height: 280,
                      child: Stack(
                        children: [
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Tier Aura Glow
                                Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getTierColor(
                                          tier,
                                        ).withOpacity(0.2),
                                        blurRadius: 80,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                Image.asset(
                                  _getEmblemPath(tier),
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                          // Shine Effect
                          AnimatedBuilder(
                            animation: _shineController,
                            builder: (context, child) {
                              return Center(
                                child: ClipOval(
                                  child: Transform.translate(
                                    offset: Offset(
                                      -250 + (_shineController.value * 500),
                                      0,
                                    ),
                                    child: Transform.rotate(
                                      angle: -pi / 4,
                                      child: Container(
                                        width: 60,
                                        height: 350,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0),
                                              Colors.white.withOpacity(0.3),
                                              Colors.white.withOpacity(0),
                                            ],
                                            stops: const [0.4, 0.5, 0.6],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 5. Huge "NEW SEASON" Banner with Accent Lines (Responsive)
                  FadeTransition(
                    opacity: _statsOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Left Accent Line (Blue)
                                Transform.rotate(
                                  angle: -0.2,
                                  child: Container(
                                    width: 20,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withOpacity(
                                            0.8,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // "NEW SEASON" Text
                                const Text(
                                  'NEW SEASON',
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Right Accent Line (Pink)
                                Transform.rotate(
                                  angle: -0.2,
                                  child: Container(
                                    width: 20,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.pinkAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.pinkAccent.withOpacity(
                                            0.8,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Subtitle: "새로운 시즌의 시작"
                            const Text(
                              '새로운 시즌의 시작',
                              style: TextStyle(
                                fontFamily: 'kbo',
                                fontSize: 22,
                                color: Colors.cyanAccent,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 6. Touch to start instruction
                  FadeTransition(
                    opacity: _buttonOpacity,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white54,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '터치하여 시즌을 시작하세요',
                          style: TextStyle(
                            fontFamily: 'kbo',
                            fontSize: 14,
                            color: Colors.white38,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingParticle(int index) {
    final random = Random(index);
    final size = random.nextDouble() * 15 + 10;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: 15 + random.nextInt(10)),
      curve: Curves.linear,
      onEnd: () {},
      builder: (context, value, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final xPos =
            (random.nextDouble() * screenWidth + (value * 100)) % screenWidth;
        final yPos =
            (random.nextDouble() * screenHeight - (value * screenHeight)) %
            screenHeight;

        return Positioned(
          left: xPos,
          top: yPos,
          child: Opacity(
            opacity: 0.1,
            child: Icon(Icons.sports_baseball, size: size, color: WHITE),
          ),
        );
      },
    );
  }
}

class DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const double spacing = 60.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RayPainter extends CustomPainter {
  final Color color;
  RayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = max(size.width, size.height) * 1.2;
    const int raysCount = 18;
    const double rayAngle = 2 * pi / raysCount;

    for (int i = 0; i < raysCount; i++) {
      final double startAngle = i * rayAngle;
      final Path path = Path()
        ..moveTo(centerX, centerY)
        ..arcTo(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
          startAngle - (rayAngle / 4),
          rayAngle / 2,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
