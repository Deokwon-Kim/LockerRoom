import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';

class SeasonStartOverlay extends StatefulWidget {
  final String seasonLabel;
  final int userScore;
  final int? userRank;
  final int totalUsers;
  final VoidCallback onDismiss;

  const SeasonStartOverlay({
    super.key,
    required this.seasonLabel,
    required this.userScore,
    this.userRank,
    required this.totalUsers,
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rayController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  String _getTrophyPath(String tier) {
    switch (tier) {
      case 'MVP':
        return 'assets/images/quiz/quiz_trophy_mvp.png';
      case 'ALL-STAR':
        return 'assets/images/quiz/quiz_trophy_allstar.png';
      case 'MAJOR':
        return 'assets/images/quiz/quiz_trophy_major.png';
      case 'MINOR':
        return 'assets/images/quiz/quiz_trophy_minor.png';
      default:
        return 'assets/images/quiz/quiz_trophy_prospect.png';
    }
  }



  @override
  Widget build(BuildContext context) {
    final tier = QuizSeasonUtils.getTier(widget.userScore);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Background Particles
          ...List.generate(12, (index) => _buildFloatingParticle(index)),

          // 2. Background Blur / Dim
          Container(
            color: Colors.black.withOpacity(0.92),
          ),

          // 3. Sunburst Rays
          // (Rays removed)

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Season Label
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Text(
                    widget.seasonLabel,
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 18,
                      color: WHITE.withOpacity(0.6),
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: const Text(
                    '새로운 시즌',
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: WHITE,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Trophy with Shine Sweep
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        // Main Trophy
                        Center(
                          child: Image.asset(
                            _getTrophyPath(tier),
                            fit: BoxFit.contain,
                          ),
                        ),
                        // Shine Sweep
                        AnimatedBuilder(
                          animation: _shineController,
                          builder: (context, child) {
                            return Center(
                              child: ClipOval(
                                child: Transform.translate(
                                  offset: Offset(-250 + (_shineController.value * 500), 0),
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

                const SizedBox(height: 40),

                // User Info Stats
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    decoration: BoxDecoration(
                      color: WHITE.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: WHITE.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '현재 점수: ${widget.userScore}점',
                          style: const TextStyle(
                            fontFamily: 'kbo',
                            fontSize: 20,
                            color: WHITE,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.userRank != null)
                          Text(
                            '현재 순위: ${widget.userRank}위 / ${widget.totalUsers}명',
                            style: TextStyle(
                              fontFamily: 'kbo',
                              fontSize: 14,
                              color: WHITE.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Challenge Button
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WHITE,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 70,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      '리그 도전하기',
                      style: TextStyle(
                        fontFamily: 'kbo',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        final xPos = (random.nextDouble() * screenWidth + (value * 100)) % screenWidth;
        final yPos = (random.nextDouble() * screenHeight - (value * screenHeight)) % screenHeight;

        return Positioned(
          left: xPos,
          top: yPos,
          child: Opacity(
            opacity: 0.1,
            child: Icon(
              Icons.sports_baseball,
              size: size,
              color: WHITE,
            ),
          ),
        );
      },
    );
  }
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
