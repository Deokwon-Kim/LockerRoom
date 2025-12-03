import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:provider/provider.dart';

class QuizRankingPage extends StatefulWidget {
  const QuizRankingPage({super.key});

  @override
  State<QuizRankingPage> createState() => _QuizRankingPageState();
}

class _QuizRankingPageState extends State<QuizRankingPage> {
  @override
  void initState() {
    super.initState();
    // 페이지 로드 시 순위 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizRankingProvider>().fetchRankings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.grey[100],
        title: Text(
          '퀴즈 랭킹',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              context.read<QuizRankingProvider>().fetchRankings();
            },
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Consumer<QuizRankingProvider>(
        builder: (context, qrp, child) {
          if (qrp.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: BUTTON),
            );
          }

          if (qrp.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    qrp.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => qrp.fetchRankings(),
                    child: Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (qrp.rankings.isEmpty) {
            return Center(child: Text('아직 퀴즈 기록이 없습니다.'));
          }

          final topThree = qrp.rankings.take(3).toList();
          final restRankings = qrp.rankings.skip(3).toList();
          final myRanking = currentUserId != null
              ? qrp.getMyRanking(currentUserId)
              : null;

          return RefreshIndicator(
            onRefresh: () => qrp.fetchRankings(),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 내 순위 표시 (항상 표시)
                  if (myRanking != null) _buildMyRankingCard(myRanking),

                  // Top 3 포디움
                  if (topThree.length >= 3)
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: _buildPodium(topThree),
                    )
                  else
                    _buildIncompletedPodium(topThree),

                  SizedBox(height: 30),

                  // 4위 이하 순위
                  if (restRankings.isNotEmpty)
                    _buildRankingList(restRankings, currentUserId),

                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 내 순위 카드 (상단 고정)
  Widget _buildMyRankingCard(RankingUserModel myRanking) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.white, size: 32),
          SizedBox(width: 12),
          Text(
            '내 순위',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Text(
            '${myRanking.rank}위',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${myRanking.score}점',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Top 3 포디움
  Widget _buildPodium(List<RankingUserModel> topThree) {
    final first = topThree.firstWhere((user) => user.rank == 1);
    final second = topThree.firstWhere((user) => user.rank == 2);
    final third = topThree.firstWhere((user) => user.rank == 3);

    return Container(
      height: 380,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2위 (왼쪽)
          _buildPodiumBar(second, Colors.grey.shade400, 180),
          SizedBox(width: 10),
          // 1위 (가운데 )
          _buildPodiumBar(first, Colors.amber, 230),
          SizedBox(width: 10),
          // 3위 (오른쪽)
          _buildPodiumBar(third, Colors.brown.shade300, 160),
        ],
      ),
    );
  }

  // 포디움이 완성되지 않은 경우 (참가자 3명 미만)
  Widget _buildIncompletedPodium(List<RankingUserModel> rankings) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: rankings.map((user) {
          return _buildRankingListItem(user, null);
        }).toList(),
      ),
    );
  }

  Widget _buildPodiumBar(RankingUserModel user, Color color, double height) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 프로필 사진
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: user.profileUrl != null
                  ? NetworkImage(user.profileUrl!)
                  : null,
              backgroundColor: Colors.grey.shade300,
              child: user.profileUrl == null
                  ? Icon(Icons.person, size: 35, color: Colors.grey.shade600)
                  : null,
            ),
          ),
          SizedBox(height: 8),
          // 닉네임
          Text(
            user.name,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          // 점수
          Text(
            '${user.score}점',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          SizedBox(height: 8),
          // 포디움 막대
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    user.rank == 1 ? Icons.emoji_events : Icons.military_tech,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${user.rank}위',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(
    List<RankingUserModel> rankings,
    String? currentUserId,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: rankings.length,
        itemBuilder: (context, index) {
          final user = rankings[index];
          return _buildRankingListItem(
            user,
            currentUserId,
            isCard: false,
            isLast: index == rankings.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildRankingListItem(
    RankingUserModel user,
    String? currentUserId, {
    bool isCard = true,
    bool isLast = false,
  }) {
    final isMe = currentUserId != null && user.userId == currentUserId;

    final rowContent = Row(
      children: [
        // 순위
        SizedBox(
          width: 40,
          child: Text(
            '${user.rank}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.blue.shade700 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: 12),
        // 프로필 사진
        CircleAvatar(
          radius: 25,
          backgroundImage: user.profileUrl != null
              ? NetworkImage(user.profileUrl!)
              : null,
          backgroundColor: Colors.grey.shade300,
          child: user.profileUrl == null
              ? Icon(Icons.person, color: Colors.grey.shade600)
              : null,
        ),
        SizedBox(width: 12),
        // 닉네임
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isMe ? Colors.blue.shade700 : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isMe)
                Text(
                  '나',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        // 점수
        Text(
          '${user.score}점',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 12),
        // 순위 변동 화살표
        _buildRankChangeIndicator(user.rankChange),
      ],
    );

    if (isCard) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isMe
              ? Border.all(color: Colors.blue.shade300, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: rowContent,
      );
    } else {
      return Container(
        color: isMe ? Colors.blue.shade50 : Colors.transparent,
        child: Column(
          children: [
            Padding(padding: EdgeInsets.all(16), child: rowContent),
            if (!isLast)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          ],
        ),
      );
    }
  }

  Widget _buildRankChangeIndicator(int scoreDiff) {
    // 1위인 경우 (scoreDiff = 0)
    if (scoreDiff == 0) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'TOP',
          style: TextStyle(
            color: Colors.amber.shade700,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 2위 이하 - 점수 차이 표시
    final displayDiff = scoreDiff.abs();

    // 점수 차이에 따른 색상 결정
    Color diffColor;
    if (displayDiff <= 50) {
      diffColor = Colors.orange; // 50점 이하: 주황색 (근접)
    } else if (displayDiff <= 100) {
      diffColor = Colors.deepOrange; // 100점 이하: 진한 주황색
    } else {
      diffColor = Colors.red; // 100점 초과: 빨간색 (큰 차이)
    }

    return Row(
      children: [
        Icon(Icons.remove, color: diffColor, size: 16),
        Text(
          '$displayDiff',
          style: TextStyle(
            color: diffColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
