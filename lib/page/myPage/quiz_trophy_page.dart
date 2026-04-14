import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_trophy_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class QuizTrophyPage extends StatefulWidget {
  final String userId;
  const QuizTrophyPage({super.key, required this.userId});

  @override
  State<QuizTrophyPage> createState() => _QuizTrophyPageState();
}

class _QuizTrophyPageState extends State<QuizTrophyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchTrophies(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Consumer<QuizRankingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.trophies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.trophies.isEmpty) {
          return _buildEmptyState(teamColor);
        }

        return Container(
          color: GRAYSCALE_LABEL_50,
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: provider.trophies.length,
            itemBuilder: (context, index) {
              return _buildTrophyCard(provider.trophies[index], teamColor);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color teamColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: GRAYSCALE_LABEL_300,
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 획득한 트로피가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GRAYSCALE_LABEL_600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이번 시즌 1위에 도전해보세요! 🔥',
            style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_500),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyCard(QuizTrophyModel trophy, Color teamColor) {
    final isIndividual = trophy.type == TrophyType.individual;
    final trophyAsset = isIndividual
        ? 'assets/images/quiz/quiz_trophy_champion.png'
        : 'assets/images/quiz/quiz_trophy_teamChampion.png';

    return GestureDetector(
      onTap: () => _showTrophyDetail(trophy),
      child: Container(
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 배경 빛 효과
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: teamColor.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset(trophyAsset),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: teamColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    trophy.seasonLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: teamColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isIndividual ? '개인 우승' : '구단 우승',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_700,
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

  void _showTrophyDetail(QuizTrophyModel trophy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                trophy.type == TrophyType.individual
                    ? 'assets/images/quiz/quiz_trophy_champion.png'
                    : 'assets/images/quiz/quiz_trophy_teamChampion.png',
                height: 140,
              ),
              const SizedBox(height: 16),
              Text(
                '${trophy.seasonLabel} ${trophy.type == TrophyType.individual ? "개인" : "팀"} 챔피언',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '획득일: ${DateFormat('yyyy년 MM월 dd일').format(trophy.earnedAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('최종 점수', '${trophy.score}P'),
                  _buildStatItem('참여 부문', '종합'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
