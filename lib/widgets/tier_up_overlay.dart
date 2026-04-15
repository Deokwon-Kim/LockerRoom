import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lockerroom/widgets/season_result_overlay.dart';

class TierUpOverlay extends StatefulWidget {
  final String oldTier;
  final String newTier;
  final VoidCallback onDismiss;

  const TierUpOverlay({
    super.key,
    required this.oldTier,
    required this.newTier,
    required this.onDismiss,
  });

  @override
  State<TierUpOverlay> createState() => _TierUpOverlayState();
}

class _TierUpOverlayState extends State<TierUpOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _impactController;
  late AnimationController _particleController;
  late AnimationController _shineController;

  late Animation<double> _oldTrophyScale;
  late Animation<double> _oldTrophyOpacity;
  late Animation<double> _newTrophyScale;
  late Animation<double> _newTrophyOpacity;

  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _bgIntensity;
  late Animation<double> _shakeAnimation;

  late ConfettiController _confettiController;
  final Random _random = Random();
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playRankupSound();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _impactController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _shineController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // 1. Background Pulse (Sync with transformation)
    _bgIntensity =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInCirc)),
            weight: 20,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 0.3,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 80,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.3, 1.0),
          ),
        );

    // 2. Old Trophy Animation (Fades in, then shrinks/fades out)
    _oldTrophyOpacity =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.0, 0.4),
          ),
        );

    _oldTrophyScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.5,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 0.0,
            ).chain(CurveTween(curve: Curves.easeInBack)),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.0, 0.4),
          ),
        );

    // 3. New Trophy Animation (Bursts after old trophy vanishes)
    _newTrophyOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.42, 0.6, curve: Curves.easeIn),
    );

    _newTrophyScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.0,
              end: 1.5,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 40,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.5,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.elasticOut)),
            weight: 60,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.42, 0.9),
          ),
        );

    // 4. Screen Shake (Impact when new trophy lands)
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 10.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 60),
    ]).animate(_impactController);

    // 5. Texts
    _textOpacity = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _mainController,
            curve: const Interval(0.65, 1.0, curve: Curves.easeOutBack),
          ),
        );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    );

    _startFinalSequence();
  }

  void _startFinalSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mainController.forward();

    // Impact Timing (Matches new trophy peak)
    // 0.42 * 3500ms = ~1470ms from start. We already delayed 300ms.
    // So 1470ms - 300ms = ~1170ms into controller movement.
    // Peek of scale is around 0.6 of controller.
    await Future.delayed(const Duration(milliseconds: 1800));
    _impactController.forward();
    _confettiController.play();
  }

  void _playRankupSound() async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _audioPlayer.play(AssetSource('audio/RankUp.mp3'));
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _mainController.dispose();
    _impactController.dispose();
    _particleController.dispose();
    _shineController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _getEmblemPath(String tier) {
    switch (tier) {
      case 'LEGEND':
        return 'assets/images/quiz/quiz_emblem_legend.png';
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
      case 'LEGEND':
        return const Color(0xFFFFD700); // Radiant Gold
      case 'MVP':
        return const Color(0xFFB19CD9); // Diamond Purple
      case 'ALL-STAR':
        return const Color(0xFFFF4D4D); // Platinum Red
      case 'MAJOR':
        return const Color(0xFFFFD700); // Gold
      case 'MINOR':
        return const Color(0xFFC0C0C0); // Silver
      default:
        return const Color(0xFFCD7F32); // Bronze
    }
  }

  @override
  Widget build(BuildContext context) {
    final newColor = _getTierColor(widget.newTier);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _shakeAnimation.value * (_random.nextDouble() - 0.5),
                _shakeAnimation.value,
              ),
              child: Stack(
                children: [
                  // 1. Unified Premium Deep Navy Gradient Background
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
                      painter: ResultBackgroundPainter(color: newColor),
                    ),
                  ),

                  // Fog / Dust
                  ...List.generate(
                    3,
                    (index) => _buildFogLayer(index, newColor),
                  ),

                  // Particles
                  CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: SparklePainter(
                      animation: _particleController,
                      color: newColor,
                    ),
                  ),

                  _buildImpactGlow(newColor),

                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      numberOfParticles: 35,
                      colors: [newColor, Colors.white, Colors.amber],
                    ),
                  ),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: _textOpacity,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Text(
                              '승격',
                              style: TextStyle(
                                fontSize: widget.newTier == 'LEGEND' ? 60 : 50,
                                color: WHITE,
                                fontWeight: FontWeight.bold,
                                shadows: widget.newTier == 'LEGEND'
                                    ? [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.8),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        // Trophy Transformation Stack
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // OLD EMBLEM (Fades out)
                            ScaleTransition(
                              scale: _oldTrophyScale,
                              child: FadeTransition(
                                opacity: _oldTrophyOpacity,
                                child: Opacity(
                                  opacity: 0.6,
                                  child: Image.asset(
                                    _getEmblemPath(widget.oldTier),
                                    width: 280,
                                    height: 280,
                                  ),
                                ),
                              ),
                            ),
                            // NEW EMBLEM (Bursts in)
                            ScaleTransition(
                              scale: _newTrophyScale,
                              child: FadeTransition(
                                opacity: _newTrophyOpacity,
                                child: Container(
                                  width: 320,
                                  height: 320,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Tier Aura Glow
                                      Container(
                                        width: 220,
                                        height: 220,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (widget.newTier == 'LEGEND'
                                                          ? Colors.amber
                                                          : newColor)
                                                      .withOpacity(0.4),
                                              blurRadius: 100,
                                              spreadRadius: 30,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Image.asset(
                                        _getEmblemPath(widget.newTier),
                                        fit: BoxFit.contain,
                                      ),
                                      _buildShineSweep(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FadeTransition(
                          opacity: _textOpacity,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              children: [
                                Text(
                                  widget.newTier,
                                  style: TextStyle(
                                    fontFamily: 'kbo',
                                    fontSize: widget.newTier == 'LEGEND'
                                        ? 42
                                        : 28,
                                    fontWeight: FontWeight.bold,
                                    color: _getTierColor(widget.newTier),
                                    letterSpacing: 5,
                                    shadows: widget.newTier == 'LEGEND'
                                        ? [
                                            const Shadow(
                                              color: Colors.black,
                                              blurRadius: 10,
                                              offset: Offset(2, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),

                        // Touch to continue guide
                        FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: WHITE.withOpacity(0.3),
                                size: 24,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '터치하여 계속하세요',
                                style: TextStyle(
                                  fontFamily: 'kbo',
                                  fontSize: 14,
                                  color: WHITE.withOpacity(0.3),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildFogLayer(int index, Color color) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final double op = 0.04 + (index * 0.01);
        final double scale = 1.0 + (index * 0.6) + (_bgIntensity.value * 0.4);
        return Positioned.fill(
          child: Opacity(
            opacity: op,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [color.withOpacity(0.4), Colors.transparent],
                    center: Alignment(0, index == 0 ? -0.3 : 0.3),
                    radius: 1.4,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImpactGlow(Color color) {
    return AnimatedBuilder(
      animation: _bgIntensity,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 700 * _bgIntensity.value,
            height: 700 * _bgIntensity.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.4 * _bgIntensity.value),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShineSweep() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        return ClipOval(
          child: Transform.translate(
            offset: Offset(-400 + (_shineController.value * 800), 0),
            child: Transform.rotate(
              angle: -pi / 3,
              child: Container(
                width: 90,
                height: 500,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0),
                    ],
                    stops: const [0.45, 0.5, 0.55],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// class EpicTitle extends StatelessWidget {
//   final String text;
//   final Color color;
//   const EpicTitle({super.key, required this.text, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         Text(
//           text,
//           style: TextStyle(
//             fontFamily: 'kbo',
//             fontSize: 56,
//             fontWeight: FontWeight.w900,
//             letterSpacing: 8,
//             color: color.withOpacity(0.15),
//           ),
//         ),
//         Text(
//           text,
//           style: TextStyle(
//             fontFamily: 'kbo',
//             fontSize: 54,
//             fontWeight: FontWeight.w900,
//             letterSpacing: 8,
//             foreground: Paint()
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = 10
//               ..color = color.withOpacity(0.4),
//           ),
//         ),
//         ShaderMask(
//           shaderCallback: (bounds) => LinearGradient(
//             colors: [Colors.white, color.withOpacity(0.8), Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ).createShader(bounds),
//           child: Text(
//             text,
//             style: const TextStyle(
//               fontFamily: 'kbo',
//               fontSize: 52,
//               fontWeight: FontWeight.w900,
//               color: Colors.white,
//               letterSpacing: 8,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

class SparklePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  SparklePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Random random = Random(42);
    final Paint paint = Paint()..color = color.withOpacity(0.25);

    for (int i = 0; i < 60; i++) {
      final double startX = random.nextDouble() * size.width;
      final double startY = random.nextDouble() * size.height;
      final double speed = 0.4 + random.nextDouble();
      final double yPos =
          (startY - (animation.value * 250 * speed)) % size.height;
      final double s = 1.2 + random.nextDouble() * 2.5;

      canvas.drawCircle(Offset(startX, yPos), s, paint);
      if (i % 6 == 0) {
        canvas.drawCircle(
          Offset(startX, yPos),
          s * 2,
          Paint()..color = Colors.white.withOpacity(0.1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
