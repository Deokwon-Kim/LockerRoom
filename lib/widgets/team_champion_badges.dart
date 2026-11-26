import 'package:flutter/material.dart';

/// 디펜딩 구단 챔피언 리본 배너 (로비 히어로 카드 · 팀 랭킹 상단 공용)
class DefendingTeamRibbonBanner extends StatelessWidget {
  final String teamName;
  final String seasonChipText;
  final Color teamColor;
  final BorderRadius? borderRadius;

  const DefendingTeamRibbonBanner({
    super.key,
    required this.teamName,
    required this.seasonChipText,
    required this.teamColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: CustomPaint(
        painter: _ChevronRibbonPainter(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0B1020).withValues(alpha: 0.94),
                Color.lerp(
                  teamColor,
                  const Color(0xFF0B1020),
                  0.58,
                )!.withValues(alpha: 0.92),
                const Color(0xFF0B1020).withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFF7E09B).withValues(alpha: 0.55),
              width: 1.1,
            ),
            borderRadius: borderRadius ?? BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF06070B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF7E09B).withValues(alpha: 0.65),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/team_champion_trophy.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'DEFENDING TEAM CHAMPION',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFF7E09B),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      '$teamName · 구단 통합 1위',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3C4), Color(0xFFD4AF37)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  seasonChipText,
                  style: const TextStyle(
                    color: Color(0xFF161105),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 소속 팬 칭호 필 배지 (3D 우승 컵 미니 아이콘 + 다크 골드 테두리)
class TeamFanTitlePill extends StatelessWidget {
  final String label;
  final Color teamColor;

  const TeamFanTitlePill({
    super.key,
    required this.label,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            Color.lerp(teamColor, const Color(0xFF1E293B), 0.72)!,
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF7E09B).withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06070B),
              border: Border.all(
                color: const Color(0xFFF7E09B).withValues(alpha: 0.7),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/team_champion_trophy.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFF3C4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 타격왕 칭호 필 배지 (3D 크리스탈·골드 타격왕 트로피 미니 아이콘 + 골드 필)
class BattingKingTitlePill extends StatelessWidget {
  final String label;
  final double fontSize;

  const BattingKingTitlePill({
    super.key,
    required this.label,
    this.fontSize = 9.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF06070B),
              border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/batting_king_trophy.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 뱃지 보관함 '우승 구단 팬' 전용 골드 쉴드 + 3D 우승 컵 엠블럼
class TeamChampionShieldEmblem extends StatelessWidget {
  final bool isLocked;
  final double size;

  const TeamChampionShieldEmblem({
    super.key,
    required this.isLocked,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GoldShieldPainter(isLocked: isLocked),
          ),
          Opacity(
            opacity: isLocked ? 0.28 : 1.0,
            child: ClipOval(
              child: SizedBox(
                width: size * 0.66,
                height: size * 0.66,
                child: Image.asset(
                  'assets/images/team_champion_trophy.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChevronRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 6;
    for (double x = -size.height; x < size.width + size.height; x += 16) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldShieldPainter extends CustomPainter {
  final bool isLocked;
  const _GoldShieldPainter({required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.21)
      ..lineTo(w * 0.88, h * 0.48)
      ..quadraticBezierTo(w * 0.88, h * 0.77, w * 0.5, h * 0.94)
      ..quadraticBezierTo(w * 0.12, h * 0.77, w * 0.12, h * 0.48)
      ..lineTo(w * 0.12, h * 0.21)
      ..close();

    final fillPaint = Paint()
      ..color = isLocked ? const Color(0xFF1F2937) : const Color(0xFF0B1020)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..shader = LinearGradient(
        colors: isLocked
            ? [Colors.white24, Colors.white12]
            : const [Color(0xFFFFF3C4), Color(0xFFD4AF37), Color(0xFF8B620F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GoldShieldPainter oldDelegate) =>
      oldDelegate.isLocked != isLocked;
}
