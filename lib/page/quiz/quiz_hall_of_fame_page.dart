import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:provider/provider.dart';

class QuizHallOfFamePage extends StatefulWidget {
  const QuizHallOfFamePage({super.key});

  @override
  State<QuizHallOfFamePage> createState() => _QuizHallOfFamePageState();
}

class _QuizHallOfFamePageState extends State<QuizHallOfFamePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final qrp = context.read<QuizRankingProvider>();
      qrp.setAllTimeMode(true);
    });
  }

  @override
  void dispose() {
    // 페이지를 나갈 때 다시 시즌 모드로 복구 (선택 사항)
    // context.read<QuizRankingProvider>().setAllTimeMode(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // 다크한 프리미엄 컬러
      appBar: AppBar(
        title: const Text(
          '명예의 전당',
          style: TextStyle(fontFamily: 'kbo', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () =>
                context.read<QuizRankingProvider>().fetchRankings(true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<QuizRankingProvider>(
        builder: (context, qrp, child) {
          if (qrp.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          if (qrp.rankings.isEmpty) {
            return const Center(
              child: Text('기록이 없습니다.', style: TextStyle(color: Colors.white70)),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade700, Colors.amber.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'HALL OF FAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'kbo',
                      ),
                    ),
                    Text(
                      '모든 시즌의 통합 최강자 리스트입니다',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: qrp.rankings.length,
                  itemBuilder: (context, index) {
                    final user = qrp.rankings[index];
                    final isMe = user.userId == currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: isMe
                            ? Border.all(color: Colors.amber, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          _buildRankIndicator(user.rank),
                          const SizedBox(width: 15),
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: user.profileUrl != null
                                ? NetworkImage(user.profileUrl!)
                                : null,
                            backgroundColor: Colors.grey.shade800,
                            child: user.profileUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (user.teamName != null)
                                  Text(
                                    user.teamName!,
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${user.score} pts',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRankIndicator(int rank) {
    if (rank <= 3) {
      Color color = rank == 1
          ? Colors.amber
          : (rank == 2 ? Colors.grey.shade300 : Colors.brown.shade300);
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 32,
      child: Center(
        child: Text('$rank', style: const TextStyle(color: Colors.white60)),
      ),
    );
  }
}
