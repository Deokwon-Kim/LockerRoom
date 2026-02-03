import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class TeamBattleDialog extends StatefulWidget {
  final VoidCallback onStart;

  const TeamBattleDialog({super.key, required this.onStart});

  @override
  State<TeamBattleDialog> createState() => _TeamBattleDialogState();
}

class _TeamBattleDialogState extends State<TeamBattleDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _myTeamSlideAnimation;
  late Animation<Offset> _rivalTeamSlideAnimation;
  late Animation<double> _vsScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 내 팀은 왼쪽에서 (700ms)
    _myTeamSlideAnimation =
        Tween<Offset>(begin: const Offset(-1.5, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
          ),
        );

    // 라이벌 팀은 오른쪽에서 (700ms)
    _rivalTeamSlideAnimation =
        Tween<Offset>(begin: const Offset(1.5, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
          ),
        );

    // VS 텍스트는 팀들이 부딪히기 직전/직후에 팡! (600ms~1000ms)
    _vsScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                widget.onStart();
              });
              return const SizedBox.shrink();
            }

            RankingTeamModel? myTeamRanking;
            try {
              myTeamRanking = provider.teamRankings.firstWhere(
                (t) =>
                    t.teamName == myTeam.name ||
                    t.teamName == myTeam.symplename,
              );
            } catch (_) {}

            if (myTeamRanking == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                widget.onStart();
              });
              return const SizedBox.shrink();
            }

            RankingTeamModel? rivalTeamRanking;
            bool isDefending = false;

            if (myTeamRanking.rank == 1) {
              if (provider.teamRankings.length > 1) {
                rivalTeamRanking = provider.teamRankings[1];
                isDefending = true;
              }
            } else {
              final myIndex = provider.teamRankings.indexOf(myTeamRanking);
              if (myIndex > 0) {
                rivalTeamRanking = provider.teamRankings[myIndex - 1];
              }
            }

            if (rivalTeamRanking == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                widget.onStart();
              });
              return const SizedBox.shrink();
            }

            final rivalTeam = teamProvider.findTeamByName(
              rivalTeamRanking.teamName,
            );

            int scoreDiff =
                (myTeamRanking.totalScore - rivalTeamRanking.totalScore).abs();

            if (scoreDiff > 100) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                widget.onStart();
              });
              return const SizedBox.shrink();
            }

            String mainTitle = isDefending ? '1위 수성을 위한 배틀!' : '순위 역전 찬스!';
            String subTitle = isDefending
                ? '${rivalTeamRanking.teamName}의 추격을 뿌리치세요!'
                : '${rivalTeamRanking.teamName}를 제칠 기회입니다!';
            String desc = isDefending
                ? '이번 퀴즈로 격차를 더 벌려보세요!'
                : '이번 퀴즈에서 ${scoreDiff + 1}점만 획득하면\n순위를 뒤집을 수 있습니다! 🔥';

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
                    fontSize: 15,
                    color: GRAYSCALE_LABEL_600,
                  ),
                ),
                const SizedBox(height: 32),

                // VS Layout with Animation
                Container(
                  height: 140, // 애니메이션 공간 확보
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 내 팀 (Left Slide)
                      SlideTransition(
                        position: _myTeamSlideAnimation,
                        child: Align(
                          alignment: const Alignment(-0.8, 0.0),
                          child: _buildTeamInfo(
                            myTeamRanking,
                            myTeam.logoPath,
                            true,
                            context,
                          ),
                        ),
                      ),

                      // 라이벌 팀 (Right Slide)
                      SlideTransition(
                        position: _rivalTeamSlideAnimation,
                        child: Align(
                          alignment: const Alignment(0.8, 0.0),
                          child: _buildTeamInfo(
                            rivalTeamRanking,
                            rivalTeam?.logoPath,
                            false,
                            context,
                          ),
                        ),
                      ),

                      // VS Text (Scale)
                      ScaleTransition(
                        scale: _vsScaleAnimation,
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'kbo',
                            color: Colors.red.shade600,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 설명 박스
                Container(
                  width: double.infinity,
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
                          widget.onStart();
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
      mainAxisSize: MainAxisSize.min,
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
                    width: 3,
                  )
                : Border.all(color: GRAYSCALE_LABEL_100, width: 1),
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
            fontSize: 15,
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
