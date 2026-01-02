import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_ranking_page.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class QuizRankingWidget extends StatefulWidget {
  const QuizRankingWidget({super.key});

  @override
  State<QuizRankingWidget> createState() => _QuizRankingWidgetState();
}

class _QuizRankingWidgetState extends State<QuizRankingWidget> {
  Timer? _timer;
  int _currentTopIndex = 0;

  @override
  void initState() {
    super.initState();
    // 데이터 fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<QuizRankingProvider>().fetchRankings();
    });

    // 3초마다 Top 3 순위 전환
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTopIndex = (_currentTopIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<QuizRankingProvider>(
      builder: (context, provider, child) {
        final teamColor = context.read<TeamProvider>().selectedTeam?.color;
        if (provider.isLoading) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QuizRankingPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WHITE,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: CircularProgressIndicator(color: teamColor)),
            ),
          );
        }

        if (provider.errorMessage != null) {
          return const SizedBox.shrink();
        }

        final myRanking = currentUserId != null
            ? provider.getMyRanking(currentUserId)
            : null;
        final topRankings = provider.rankings.take(3).toList();

        if (topRankings.isEmpty) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => QuizRankingPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 나의 순위 섹션
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '나의 순위',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (myRanking != null)
                  Text(
                    '${myRanking.rank}위 • ${myRanking.score.toStringAsFixed(0)}점',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  )
                else
                  Text(
                    '아직 퀴즈를 풀지 않았습니다',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[300], height: 1),
                const SizedBox(height: 12),
                // Top 3 애니메이션 섹션
                SizedBox(
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final offsetAnimation =
                              Tween<Offset>(
                                begin: const Offset(0.0, 1.0), // 아래에서 시작
                                end: Offset.zero, // 제자리로
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );

                          return SlideTransition(
                            position: offsetAnimation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: _buildTopRankingItem(
                      topRankings[_currentTopIndex % topRankings.length],
                      key: ValueKey<int>(_currentTopIndex),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopRankingItem(dynamic ranking, {Key? key}) {
    return Container(
      key: key,
      child: Row(
        children: [
          Text(
            _getRankEmoji(ranking.rank),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            '${ranking.rank}위',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ranking.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${ranking.score.toStringAsFixed(0)}점',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}
