import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class TeamBattleDialog extends StatelessWidget {
  final VoidCallback onStart;

  const TeamBattleDialog({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Consumer<QuizRankingProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final teamProvider = context.read<TeamProvider>();
            final myTeam = teamProvider.selectedTeam;

            if (myTeam == null) {
              // 팀 선택이 안되어 있으면 다이얼로그 닫고 바로 시작
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                onStart();
              });
              return const SizedBox.shrink();
            }

            // 내 팀 랭킹 정보 찾기
            RankingTeamModel? myTeamRanking;
            try {
              myTeamRanking = provider.teamRankings.firstWhere(
                (t) =>
                    t.teamName == myTeam.name ||
                    t.teamName == myTeam.symplename,
              );
            } catch (_) {}

            if (myTeamRanking == null) {
              // 랭킹 정보 없으면 바로 시작
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                onStart();
              });
              return const SizedBox.shrink();
            }

            // 라이벌 팀 찾기 (바로 위 순위)
            RankingTeamModel? rivalTeamRanking;
            bool isDefending = false; // 1위라서 방어전인지 여부

            if (myTeamRanking.rank == 1) {
              // 1위인 경우 2위를 라이벌로
              if (provider.teamRankings.length > 1) {
                rivalTeamRanking = provider.teamRankings[1];
                isDefending = true;
              }
            } else {
              // 그 외엔 바로 위 순위가 라이벌
              final myIndex = provider.teamRankings.indexOf(myTeamRanking);
              if (myIndex > 0) {
                rivalTeamRanking = provider.teamRankings[myIndex - 1];
              }
            }

            // 라이벌 정보가 없으면 (팀이 하나뿐?)
            if (rivalTeamRanking == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                onStart();
              });
              return const SizedBox.shrink();
            }

            final rivalTeam = teamProvider.findTeamByName(
              rivalTeamRanking.teamName,
            );

            // 메시지 구성
            int scoreDiff =
                (myTeamRanking.totalScore - rivalTeamRanking.totalScore).abs();

            if (scoreDiff > 100) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                onStart();
              });
              return const SizedBox.shrink();
            }

            // 역전/방어 가능 점수 (퀴즈 1회 만점 100점 가정)
            // 1위인 경우: "2위와 X점 차이! 격차를 벌리세요!"
            // 추격자인 경우: "X점만 더 얻으면 역전 가능!"

            String mainTitle = isDefending ? '1위 수성 배틀!' : '순위 역전 찬스!';
            String subTitle = isDefending
                ? '${rivalTeamRanking.teamName}의 추격을 뿌리치세요!'
                : '${rivalTeamRanking.teamName}를 제칠 기회입니다!';
            String desc = isDefending
                ? '이번 퀴즈로 격차를 더 벌려보세요!'
                : '이번 퀴즈에서 ${scoreDiff + 1}점만 획득하면\n순위를 뒤집을 수 있습니다! 🔥'; // +1점이면 역전

            if (!isDefending && scoreDiff > 100) {
              desc = '이번 퀴즈 만점 도전으로\n점수 차를 좁혀보세요! 🏃';
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: GRAYSCALE_LABEL_600,
                  ),
                ),
                const SizedBox(height: 32),

                // VS Layout
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 내 팀
                    _buildTeamInfo(
                      myTeamRanking,
                      myTeam.logoPath,
                      true,
                      context,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'kbo',
                          color: Colors.red.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    // 라이벌 팀
                    _buildTeamInfo(
                      rivalTeamRanking,
                      rivalTeam?.logoPath,
                      false,
                      context,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 설명 박스
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E5FF)),
                  ),
                  child: Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B6Ef5),
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 버튼
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '나중에',
                          style: TextStyle(
                            color: GRAYSCALE_LABEL_600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onStart();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: myTeam.color,
                          foregroundColor: WHITE,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '도전하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTeamInfo(
    RankingTeamModel ranking,
    String? logoPath,
    bool isMe,
    BuildContext context,
  ) {
    final teamProvider = context.read<TeamProvider>();
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: WHITE,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isMe
                ? Border.all(
                    color: teamProvider.selectedTeam?.color ?? BUTTON,
                    width: 2,
                  )
                : null,
          ),
          padding: const EdgeInsets.all(12),
          child: logoPath != null
              ? Image.asset(logoPath)
              : const Icon(Icons.groups, size: 40, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Text(
          ranking.teamName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.black : GRAYSCALE_LABEL_700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isMe
                ? teamProvider.selectedTeam?.color
                : GRAYSCALE_LABEL_200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${ranking.rank}위',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? WHITE : GRAYSCALE_LABEL_600,
            ),
          ),
        ),
      ],
    );
  }
}
