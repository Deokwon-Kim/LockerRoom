import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';

/// ILU("1루") 브랜드 정체성을 담은 직관 베이스 러닝 챌린지 카드
/// 직관 1회 = 1베이스 전진 (4경기 = 1득점 홈인)
class BaseRunningDiamond extends StatelessWidget {
  final int totalGames;
  final bool compact;

  const BaseRunningDiamond({
    super.key,
    required this.totalGames,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final int runs = totalGames ~/ 4;
    final int base = totalGames % 4;
    final bool isHomeIn = totalGames > 0 && base == 0;

    final String badgeText;
    final String statusText;
    final String hintText;
    final int progressSteps;

    if (totalGames == 0) {
      badgeText = '0득점 · 대기 중';
      statusText = '첫 직관 출루 대기 중!';
      hintText = '직관 1회를 기록하면 1루로 진루해요!';
      progressSteps = 0;
    } else if (isHomeIn) {
      badgeText = '$runs득점 · 홈인!';
      statusText = '🎉 $runs득점 홈인 달성!';
      hintText = '총 $totalGames경기 직관 완료! 다음 직관부터 새 이닝이 시작됩니다.';
      progressSteps = 4;
    } else {
      badgeText = '$runs득점 · $base루';
      statusText = '현재 $base루 진출 중!';
      hintText = '앞으로 ${4 - base}경기 더 직관하면 ${runs + 1}득점 달성!';
      progressSteps = base;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GRAYSCALE_LABEL_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⚾ 1루부터 홈까지',
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w800,
                            color: GRAYSCALE_LABEL_950,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showRuleDialog(context),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '직관 1경기 = 1베이스 · 4경기마다 1득점(홈인)!',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ACCENT_CORAL,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: WHITE,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Container(
            padding: EdgeInsets.all(compact ? 10 : 12),
            decoration: BoxDecoration(
              color: BACKGROUND_COLOR,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GRAYSCALE_LABEL_200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 86 : 102,
                  height: compact ? 86 : 102,
                  child: CustomPaint(
                    painter: _DiamondPainter(
                      totalGames: totalGames,
                      base: base,
                      isHomeIn: isHomeIn,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: GRAYSCALE_LABEL_950,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hintText,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: GRAYSCALE_LABEL_600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressSteps / 4,
                                minHeight: 6,
                                backgroundColor: GRAYSCALE_LABEL_200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  ACCENT_CORAL,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progressSteps / 4',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: GRAYSCALE_LABEL_700,
                            ),
                          ),
                        ],
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
  }

  void _showRuleDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WHITE,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '⚾ 1루부터 홈까지 규칙 안내',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '직관 기록을 1경기 추가할 때마다 베이스를 1칸씩 밟습니다.',
              style: TextStyle(
                fontSize: 13,
                color: GRAYSCALE_LABEL_700,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            _RuleLine(step: '1경기', desc: '1루 출루 (1B)'),
            _RuleLine(step: '2경기', desc: '2루 진루 (2B)'),
            _RuleLine(step: '3경기', desc: '3루 진루 (3B)'),
            _RuleLine(step: '4경기', desc: '홈인! 1득점 달성 (H)'),
            SizedBox(height: 10),
            Text(
              '• 4경기를 채워 홈인하면 1득점이 쌓이고, 다음 직관(5경기째)부터 다시 1루에서 새 이닝이 시작됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: GRAYSCALE_LABEL_500,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: BUTTON,
              foregroundColor: WHITE,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String step;
  final String desc;

  const _RuleLine({required this.step, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ACCENT_CORAL.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ACCENT_CORAL,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GRAYSCALE_LABEL_900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  final int totalGames;
  final int base;
  final bool isHomeIn;

  _DiamondPainter({
    required this.totalGames,
    required this.base,
    required this.isHomeIn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double pad = w * 0.14;

    final Offset home = Offset(w / 2, h - pad);
    final Offset first = Offset(w - pad, h / 2);
    final Offset second = Offset(w / 2, pad);
    final Offset third = Offset(pad, h / 2);

    // 1. 기본 베이스패스 (회색 다이아몬드)
    final basePathPaint = Paint()
      ..color = GRAYSCALE_LABEL_200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final outline = Path()
      ..moveTo(second.dx, second.dy)
      ..lineTo(first.dx, first.dy)
      ..lineTo(home.dx, home.dy)
      ..lineTo(third.dx, third.dy)
      ..close();
    canvas.drawPath(outline, basePathPaint);

    // 2. 진행한 베이스패스 (코랄 오렌지)
    if (totalGames > 0) {
      final activePaint = Paint()
        ..color = ACCENT_CORAL
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final activePath = Path()..moveTo(home.dx, home.dy);
      if (base >= 1 || isHomeIn) activePath.lineTo(first.dx, first.dy);
      if (base >= 2 || isHomeIn) activePath.lineTo(second.dx, second.dy);
      if (base >= 3 || isHomeIn) activePath.lineTo(third.dx, third.dy);
      if (isHomeIn) activePath.lineTo(home.dx, home.dy);
      canvas.drawPath(activePath, activePaint);
    }

    final double baseSize = w * 0.13;
    final bool reached1 = totalGames > 0 && (base >= 1 || isHomeIn);
    final bool reached2 = totalGames > 0 && (base >= 2 || isHomeIn);
    final bool reached3 = totalGames > 0 && (base >= 3 || isHomeIn);

    _drawBaseSquare(canvas, first, baseSize, '1B', reached1);
    _drawBaseSquare(canvas, second, baseSize, '2B', reached2);
    _drawBaseSquare(canvas, third, baseSize, '3B', reached3);

    // 홈 플레이트 (딥 네이비 원형 배지)
    final homePaint = Paint()..color = BUTTON;
    canvas.drawCircle(home, baseSize * 0.72, homePaint);
    _drawCenteredText(canvas, 'H', home, baseSize * 0.65);
  }

  void _drawBaseSquare(
    Canvas canvas,
    Offset center,
    double size,
    String label,
    bool active,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.5));
    canvas.drawRRect(
      rrect,
      Paint()..color = active ? ACCENT_CORAL : GRAYSCALE_LABEL_300,
    );
    canvas.restore();
    _drawCenteredText(canvas, label, center, size * 0.56);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: WHITE,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) {
    return oldDelegate.totalGames != totalGames ||
        oldDelegate.base != base ||
        oldDelegate.isHomeIn != isHomeIn;
  }
}
