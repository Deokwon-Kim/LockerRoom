import 'dart:math' as Math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class RankOvertakeDialog extends StatefulWidget {
  final String targetName;
  final int oldRank;
  final int newRank;
  final String? logoPath;
  final bool isTeam;

  const RankOvertakeDialog({
    super.key,
    required this.targetName,
    required this.oldRank,
    required this.newRank,
    this.logoPath,
    required this.isTeam,
  });

  @override
  State<RankOvertakeDialog> createState() => _RankOvertakeDialogState();
}

class _RankOvertakeDialogState extends State<RankOvertakeDialog>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _rotateAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamProvier = context.read<TeamProvider>();
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Text(
                  widget.isTeam ? '팀 순위 대역전!' : '순위 수직 상승!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '축하합니다! ${widget.targetName}의\n순위가 올라갔습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: GRAYSCALE_LABEL_600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // 순위 변화 표시
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRankBadge(widget.oldRank, context, isOld: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 32,
                        color: GRAYSCALE_LABEL_300,
                      ),
                    ),
                    _buildRankBadge(widget.newRank, context, isOld: false),
                  ],
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamProvier.selectedTeam?.color,
                      foregroundColor: WHITE,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'kbo',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 상단 트로피/아이콘 애니메이션
          Positioned(
            top: 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: RotationTransition(
                turns: _rotateAnimation,
                child: Center(
                  child: widget.logoPath != null
                      ? Image.asset(widget.logoPath!, height: 80)
                      : const Icon(
                          Icons.emoji_events_rounded,
                          size: 60,
                          color: WHITE,
                        ),
                ),
              ),
            ),
          ),

          // 폭죽 효과
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
            createParticlePath: _drawStar,
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(
    int rank,
    BuildContext context, {
    required bool isOld,
  }) {
    final teamProvider = context.read<TeamProvider>();
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: isOld
                ? GRAYSCALE_LABEL_100
                : teamProvider.selectedTeam?.color,
            shape: BoxShape.circle,
            border: isOld ? null : Border.all(color: WHITE, width: 2),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
                color: isOld ? GRAYSCALE_LABEL_500 : WHITE,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOld ? '이전 순위' : '현재 순위',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isOld
                ? GRAYSCALE_LABEL_400
                : teamProvider.selectedTeam?.color,
          ),
        ),
      ],
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (3.1415926535897932 / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * Math.cos(step),
        halfWidth + externalRadius * Math.sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * Math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * Math.sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }
}

// Math.cos를 쓰기 위한 dart:math import 대신 직접 구현하거나 import 추가 필요
// 하지만 dart:math는 이미 ConfettiWidget 내부 등에서 쓰일 것이므로 별도 import가 권장됨.
