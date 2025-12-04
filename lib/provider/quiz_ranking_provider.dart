import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/ranking_user_model.dart';

class QuizRankingProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RankingUserModel> _rankings = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'all';

  List<RankingUserModel> get rankings => _rankings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;

  // 카테고리 변경
  void setCategory(String category) {
    _selectedCategory = category;
    fetchRankings();
  }

  // 순위 데이터 가져오기
  Future<void> fetchRankings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      Query query = _firestore.collection('quiz_results');

      // 카테고리 필터
      if (_selectedCategory != 'all') {
        query = query.where('category', isEqualTo: _selectedCategory);
      }

      // 점수 높은 순으로 정렬
      query = query
          .orderBy('score', descending: true)
          .orderBy('completedAt', descending: true)
          .limit(100);

      final snapshot = await query.get();

      // 사용자별 총 점수 합산
      final Map<String, Map<String, dynamic>> userTotalScores = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;
        final score = data['score'] as int;
        final completedAt = data['completedAt'] as Timestamp;

        if (!userTotalScores.containsKey(userId)) {
          // 처음 발견한 사용자
          userTotalScores[userId] = {
            'totalScore': score,
            'completedAt': completedAt,
          };
        } else {
          // 이미 있는 사용자 - 점수 합산
          userTotalScores[userId]!['totalScore'] =
              (userTotalScores[userId]!['totalScore'] as int) + score;

          // 최근 completedAt 유지
          final currentCompletedAt =
              userTotalScores[userId]!['completedAt'] as Timestamp;
          if (completedAt.compareTo(currentCompletedAt) > 0) {
            userTotalScores[userId]!['completedAt'] = completedAt;
          }
        }
      }

      // 사용자 정보 가져오기
      final List<RankingUserModel> tempRankings = [];

      for (var entry in userTotalScores.entries) {
        final userId = entry.key;
        final scoreData = entry.value;

        try {
          // 사용자 정보 가져오기
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          final userData = userDoc.data();

          tempRankings.add(
            RankingUserModel(
              rank: 0,
              userId: userId,
              name: userData?['userNickName'] ?? '익명',
              score: scoreData['totalScore'] as int,
              rankChange: 0,
              profileUrl: userData?['profileImage'],
              completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
            ),
          );
        } catch (e) {
          print('사용자 정보 가져오기 실패 ($userId): $e');
          // 사용자 정보를 못 가져와도 순위는 표시
          tempRankings.add(
            RankingUserModel(
              rank: 0,
              userId: userId,
              name: '익명',
              score: scoreData['totalScore'] as int,
              rankChange: 0,
              profileUrl: null,
              completedAt: (scoreData['completedAt'] as Timestamp).toDate(),
            ),
          );
        }
      }
      // 점수 순으로 정렬
      tempRankings.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;
        // 동점일 경우 최근 기록 우선
        return b.completedAt.compareTo(a.completedAt);
      });

      // 순위 부여 및 점수 차이 계산
      _rankings = tempRankings.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;

        // 바로 위 순위와의 점수 차이 계산
        int scoreDiff = 0;
        if (index > 0) {
          // 2위 이하인 경우, 바로 위 순위와의 점수 차이
          scoreDiff = user.score - tempRankings[index - 1].score; // 음수로 나옴
        }

        return user.copyWith(
          rank: index + 1,
          rankChange: scoreDiff, // rankChange 필드를 점수 차이로 재활용
        );
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '순위를 불러오는데 실패했습니다: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // 내 순위 찾기
  RankingUserModel? getMyRanking(String currentUserId) {
    try {
      return _rankings.firstWhere((user) => user.userId == currentUserId);
    } catch (e) {
      return null;
    }
  }
}
