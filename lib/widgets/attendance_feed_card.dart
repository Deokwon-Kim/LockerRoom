import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

/// 피드 게시글(`PostModel.attendanceSummary`)에 첨부되는 직관 인증 요약 카드
class AttendanceFeedCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const AttendanceFeedCard({super.key, required this.summary});

  int _parseInt(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    final gameId = (summary['gameId'] ?? '').toString();
    final ownerId = (summary['ownerId'] ?? '').toString();
    final myTeam = (summary['myTeam'] ?? '').toString();
    final oppTeam = (summary['oppTeam'] ?? '').toString();
    final myScore = _parseInt(summary['myScore']);
    final oppScore = _parseInt(summary['opponentScore']);
    final stadium = (summary['stadium'] ?? '').toString();
    final date = (summary['date'] ?? '').toString();
    final seat = (summary['seat'] ?? '').toString();

    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.findTeamByName(myTeam)?.color ?? BUTTON;

    final String resultLabel;
    final Color resultColor;
    if (myScore > oppScore) {
      resultLabel = '직관 승리 ⚾';
      resultColor = teamColor;
    } else if (myScore < oppScore) {
      resultLabel = '직관 패배';
      resultColor = ACCENT_CORAL;
    } else {
      resultLabel = '무승부';
      resultColor = GRAYSCALE_LABEL_600;
    }

    return GestureDetector(
      onTap: gameId.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IntutionRecordDetailPage(
                    gameId: gameId,
                    ownerUserId: ownerId.isNotEmpty ? ownerId : null,
                  ),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: BACKGROUND_COLOR,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: teamColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: resultColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    resultLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: WHITE,
                    ),
                  ),
                ),
                Text(
                  [
                    if (date.isNotEmpty) date,
                    if (stadium.isNotEmpty) stadium,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$myTeam $myScore : $oppScore $oppTeam',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: GRAYSCALE_LABEL_950,
              ),
            ),
            if (seat.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '🪑 $seat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
