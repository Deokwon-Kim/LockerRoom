import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';

class SeasonResultOverlay extends StatefulWidget {
  final String seasonLabel;
  final int totalScore;
  final String finalRank;
  final VoidCallback onDismiss;

  const SeasonResultOverlay({
    super.key,
    this.seasonLabel = '시즌 종료 결과',
    required this.totalScore,
    required this.finalRank,
    required this.onDismiss,
  });

  @override
  State<SeasonResultOverlay> createState() => _SeasonResultOverlayState();
}

class _SeasonResultOverlayState extends State<SeasonResultOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fade;
  late Animation<double> _emblemScale;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playBackgroundSound();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    );

    _emblemScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.1,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 60,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.1,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 40,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.1, 0.6),
          ),
        );

    _contentOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _mainController.forward();
  }

  Future<void> _playBackgroundSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/sesonReport.mp3'));
    } catch (e) {
      debugPrint('Season report audio play failed: $e');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
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
    final tier = QuizSeasonUtils.getTier(widget.totalScore);
    final tierColor = _getTierColor(tier);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              // Background
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

              // Light Rays / Particles (Subtle)
              Positioned.fill(
                child: CustomPaint(
                  painter: ResultBackgroundPainter(color: tierColor),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 80),
                          // Header Text
                          FadeTransition(
                            opacity: _contentOpacity,
                            child: Column(
                              children: [
                                Text(
                                  widget.seasonLabel,
                                  style: TextStyle(
                                    fontFamily: 'kbo',
                                    fontSize: 18,
                                    color: tierColor.withOpacity(0.8),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '당신의 활약상을 확인하세요',
                                  style: TextStyle(
                                    fontFamily: 'kbo',
                                    fontSize: 14,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Central Emblem Card
                          ScaleTransition(
                            scale: _emblemScale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glow behind emblem
                                Container(
                                  width: 300,
                                  height: 300,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 180,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: tierColor.withOpacity(
                                                0.15,
                                              ),
                                              blurRadius: 80,
                                              spreadRadius: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Image.asset(
                                        _getEmblemPath(tier),
                                        width: 260,
                                        height: 260,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                ),

                                Text(
                                  tier,
                                  style: TextStyle(
                                    fontFamily: 'kbo',
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: tierColor,
                                    letterSpacing: 4,
                                    shadows: [
                                      Shadow(
                                        color: tierColor.withOpacity(0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'FINAL RANKING TIER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white24,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 1),

                          // Information Cards
                          FadeTransition(
                            opacity: _contentOpacity,
                            child: SlideTransition(
                              position: _contentSlide,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  children: [
                                    _buildResultCard(
                                      title: '최종 순위',
                                      value: widget.finalRank,
                                      icon: Icons.stars_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 16),
                                    _buildResultCard(
                                      title: '시즌 점수',
                                      value: widget.totalScore.toString(),
                                      suffix: ' PTS',
                                      icon: Icons.emoji_events_rounded,
                                      color: tierColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Touch to dismiss guide
                          FadeTransition(
                            opacity: _contentOpacity,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  color: Colors.white.withOpacity(0.2),
                                  size: 20,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '터치하여 다음으로 넘어갑니다',
                                  style: TextStyle(
                                    fontFamily: 'kbo',
                                    fontSize: 13,
                                    color: Colors.white24,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    String? suffix,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color.withOpacity(0.6), size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'kbo',
                fontSize: 12,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResultBackgroundPainter extends CustomPainter {
  final Color color;
  ResultBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final Path path = Path();
    path.moveTo(0, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.1);
    path.lineTo(size.width, size.height * 0.9);
    path.lineTo(0, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    // Subtle diagonal lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.01)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 20; i++) {
      canvas.drawLine(
        Offset(0, size.height * 0.05 * i),
        Offset(size.width, (size.height * 0.05 * i) - 100),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
