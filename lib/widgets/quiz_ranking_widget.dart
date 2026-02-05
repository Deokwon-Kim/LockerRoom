import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/ranking_team_model.dart';
import 'package:lockerroom/model/ranking_user_model.dart';
import 'package:lockerroom/page/quiz/quiz_ranking_page.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/rank_overtake_dialog.dart';
import 'package:provider/provider.dart';

class QuizRankingWidget extends StatefulWidget {
  final int? gainedScore;
  const QuizRankingWidget({super.key, this.gainedScore});

  @override
  State<QuizRankingWidget> createState() => _QuizRankingWidgetState();
}

class _RankingItem {
  final String id;
  final String name;
  final String? profileUrl; // null for team (or logo path for team)
  final bool isTeam;
  int score;
  int rank;
  final bool isMe;
  final Color? color; // for team color or user icon color

  _RankingItem({
    required this.id,
    required this.name,
    this.profileUrl,
    required this.isTeam,
    required this.score,
    required this.rank,
    required this.isMe,
    this.color,
  });
}

class _QuizRankingWidgetState extends State<QuizRankingWidget> {
  List<_RankingItem> _userItems = [];
  List<_RankingItem> _teamItems = [];
  bool _isAnimationStarted = false;
  final double _itemHeight = 50.0;
  final int _maxItemsToShow = 3; // 보여줄 최대 아이템 수 (나 포함 주변)

  // 보여지는 리스트의 최상위 랭크 (고정값, 인덱스 더해서 현재 랭크 표시)
  int _userTopRank = 1;
  int _teamTopRank = 1;

  @override
  void initState() {
    super.initState();
    // 데이터 fetch 및 애니메이션 데이터 준비 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAndPrepareData();
    });
  }

  Future<void> _fetchAndPrepareData() async {
    if (!mounted) return;
    // 방금 끝난 퀴즈 결과가 반영되도록 force: true 로 가져옴
    await context.read<QuizRankingProvider>().fetchRankings(true);
    if (!mounted) return;

    _prepareAnimationData();
  }

  void _prepareAnimationData() {
    final provider = context.read<QuizRankingProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();
    final myTeam = teamProvider.selectedTeam;

    if (widget.gainedScore == null) {
      // 애니메이션 없음 (단순 조회)
      return;
    }

    final gainedScore = widget.gainedScore!;

    // 1. User Items 준비
    if (currentUserId != null) {
      final allUsers = provider.rankings; // 이미 score desc 정렬된 상태(현재)

      // 내 현재 데이터 찾기
      final myUser = allUsers.firstWhere(
        (u) => u.userId == currentUserId,
        orElse: () => RankingUserModel(
          userId: '',
          name: '',
          score: 0,
          rank: 0,
          rankChange: 0,
          completedAt: DateTime.now(),
        ),
      );

      if (myUser.userId.isNotEmpty) {
        // 이전 점수로 복원된 리스트 생성
        List<_RankingItem> tempItems = allUsers.map((u) {
          final isMe = u.userId == currentUserId;
          return _RankingItem(
            id: u.userId,
            name: u.name,
            profileUrl: u.profileUrl,
            isTeam: false,
            score: isMe ? u.score - gainedScore : u.score,
            rank: 0, // 나중에 계산
            isMe: isMe,
            color: Colors.blueAccent,
          );
        }).toList();

        // 점수 내림차순 정렬 (이전 상태)
        tempItems.sort((a, b) => b.score.compareTo(a.score));

        // 랭크 매기기 (이전 랭크)
        for (int i = 0; i < tempItems.length; i++) {
          tempItems[i].rank = i + 1;
        }

        // 내 인덱스 찾기
        final myIndex = tempItems.indexWhere((item) => item.isMe);
        if (myIndex != -1) {
          // 보여줄 범위 설정 (내 위주)
          int startIndex = myIndex - (_maxItemsToShow - 1);
          if (startIndex < 0) startIndex = 0;
          int endIndex = startIndex + _maxItemsToShow;
          if (endIndex > tempItems.length) endIndex = tempItems.length;

          if (endIndex - startIndex < _maxItemsToShow && startIndex > 0) {
            startIndex = endIndex - _maxItemsToShow;
            if (startIndex < 0) startIndex = 0;
          }

          _userItems = tempItems.sublist(startIndex, endIndex);
          // 랭크 표시의 명확한 베이스라인 설정
          _userTopRank = startIndex + 1;
        }
      }
    }

    // 2. Team Items 준비
    if (myTeam != null) {
      final allTeams = provider.teamRankings;

      final myTeamData = allTeams.firstWhere(
        (t) => t.teamName == myTeam.name || t.teamName == myTeam.symplename,
        orElse: () => RankingTeamModel(
          teamName: '',
          totalScore: 0,
          rank: 0,
          rankChange: 0,
        ),
      );

      if (myTeamData.teamName.isNotEmpty) {
        List<_RankingItem> tempItems = allTeams.map((t) {
          final isMe = t.teamName == myTeamData.teamName;
          final teamModel = teamProvider.findTeamByName(t.teamName);
          return _RankingItem(
            id: t.teamName,
            name: t.teamName,
            isTeam: true,
            profileUrl: teamModel?.logoPath,
            score: isMe ? t.totalScore - gainedScore : t.totalScore,
            rank: 0,
            isMe: isMe,
            color: isMe ? myTeam.color : Colors.grey,
          );
        }).toList();

        tempItems.sort((a, b) => b.score.compareTo(a.score));

        for (int i = 0; i < tempItems.length; i++) {
          tempItems[i].rank = i + 1;
        }

        final myIndex = tempItems.indexWhere((item) => item.isMe);
        if (myIndex != -1) {
          int startIndex = myIndex - (_maxItemsToShow - 1);
          if (startIndex < 0) startIndex = 0;
          int endIndex = startIndex + _maxItemsToShow;
          if (endIndex > tempItems.length) endIndex = tempItems.length;

          if (endIndex - startIndex < _maxItemsToShow && startIndex > 0) {
            startIndex = endIndex - _maxItemsToShow;
            if (startIndex < 0) startIndex = 0;
          }

          _teamItems = tempItems.sublist(startIndex, endIndex);
          _teamTopRank = startIndex + 1;
        }
      }
    }

    setState(() {}); // 초기 위치 그리기

    // 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _startAnimation(gainedScore);
      }
    });
  }

  void _startAnimation(int gainedScore) {
    // 1. 애니메이션 시작 전 현재(이전) 상태 캡처
    final myUserId = FirebaseAuth.instance.currentUser?.uid;
    final teamProvider = context.read<TeamProvider>();
    final myTeam = teamProvider.selectedTeam;

    // 이전 상태에서 내 정보와 랭킹 저장
    _RankingItem? oldMyUser;
    _RankingItem? oldMyTeam;

    if (myUserId != null) {
      final idx = _userItems.indexWhere((item) => item.isMe);
      if (idx != -1) oldMyUser = _userItems[idx];
    }
    if (myTeam != null) {
      final idx = _teamItems.indexWhere(
        (item) => item.id == myTeam.name || item.id == myTeam.symplename,
      );
      if (idx != -1) oldMyTeam = _teamItems[idx];
    }

    final int oldUserRank = oldMyUser?.rank ?? 0;
    final int oldTeamRank = oldMyTeam?.rank ?? 0;

    setState(() {
      _isAnimationStarted = true;

      // User 점수 업데이트 및 재정렬
      for (var item in _userItems) {
        if (item.isMe) item.score += gainedScore;
      }
      _userItems.sort((a, b) => b.score.compareTo(a.score));
      // 랭크 재계산 (내부 리스트 기준)
      for (int i = 0; i < _userItems.length; i++) {
        _userItems[i].rank = _userTopRank + i;
      }

      // Team 점수 업데이트 및 재정렬
      for (var item in _teamItems) {
        if (item.isMe) item.score += gainedScore;
      }
      _teamItems.sort((a, b) => b.score.compareTo(a.score));
      // 랭크 재계산
      for (int i = 0; i < _teamItems.length; i++) {
        _teamItems[i].rank = _teamTopRank + i;
      }
    });

    // 2. 애니메이션 후 랭커 정보 확인 및 다이얼로그 트리거
    if (oldMyUser != null) {
      final newUserItem = _userItems.firstWhere((item) => item.isMe);
      if (newUserItem.rank < oldUserRank) {
        _showCelebration(
          targetName: newUserItem.name,
          oldRank: oldUserRank,
          newRank: newUserItem.rank,
          isTeam: false,
        );
      }
    }

    if (oldMyTeam != null) {
      final newTeamItem = _teamItems.firstWhere((item) => item.isMe);
      if (newTeamItem.rank < oldTeamRank) {
        _showCelebration(
          targetName: newTeamItem.name,
          oldRank: oldTeamRank,
          newRank: newTeamItem.rank,
          isTeam: true,
          logoPath: newTeamItem.profileUrl,
        );
      }
    }
  }

  void _showCelebration({
    required String targetName,
    required int oldRank,
    required int newRank,
    required bool isTeam,
    String? logoPath,
  }) {
    // 애니메이션이 어느 정도 진행된 후 다이얼로그 노출
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => RankOvertakeDialog(
            targetName: targetName,
            oldRank: oldRank,
            newRank: newRank,
            isTeam: isTeam,
            logoPath: logoPath,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizRankingProvider>(
      builder: (context, provider, child) {
        if (widget.gainedScore == null ||
            (_userItems.isEmpty && _teamItems.isEmpty)) {
          return _buildSimpleView(context, provider);
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuizRankingPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),

                if (_userItems.isNotEmpty) ...[
                  _buildTag('개인 순위'),
                  SizedBox(
                    height: _userItems.length * _itemHeight,
                    child: Stack(
                      children: _userItems
                          .map((item) => _buildAnimatedItem(item, _userItems))
                          .toList(),
                    ),
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEEEEEE),
                  ),
                ),

                if (_teamItems.isNotEmpty) ...[
                  _buildTag('팀 순위'),
                  SizedBox(
                    height: _teamItems.length * _itemHeight,
                    child: Stack(
                      children: _teamItems
                          .map((item) => _buildAnimatedItem(item, _teamItems))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: GRAYSCALE_LABEL_500,
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(_RankingItem item, List<_RankingItem> list) {
    final index = list.indexOf(item);
    final teamProvider = context.read<TeamProvider>();

    // 현재 표시 랭크 계산 (보여지는 리스트의 최상위 + 현재 인덱스)
    // _userTopRank / _teamTopRank 는 이 윈도우의 시작 등수 (예: 4위부터면 4)
    final int baseRank = (list == _userItems) ? _userTopRank : _teamTopRank;
    final int currentRank = baseRank + index;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      top: index * _itemHeight,
      left: 0,
      right: 0,
      height: _itemHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: item.isMe
              ? teamProvider.selectedTeam?.color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: item.isMe
              ? Border.all(
                  color:
                      teamProvider.selectedTeam?.color.withOpacity(0.5) ??
                      Colors.blueAccent.withOpacity(0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 45, // '100위' 대비 여유 있게 확보
              child: Text(
                '$currentRank위',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.isMe ? Colors.white : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),

            if (item.isTeam) ...[
              if (item.profileUrl != null) ...[
                Image.asset(item.profileUrl!, width: 24, height: 24),
                const SizedBox(width: 8),
              ] else ...[
                Icon(Icons.sports_baseball, size: 20, color: item.color),
                const SizedBox(width: 8),
              ],
            ] else ...[
              Icon(Icons.person, size: 20, color: GRAYSCALE_LABEL_500),
              const SizedBox(width: 8),
            ],

            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: item.isMe ? FontWeight.bold : FontWeight.normal,
                  color: item.isMe ? Colors.white : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(
                begin:
                    item.score -
                    (item.isMe && _isAnimationStarted
                        ? widget.gainedScore!
                        : 0),
                end: item.score,
              ),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Text(
                  '$value점',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.isMe ? Colors.white : Colors.grey,
                    fontSize: 13,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleView(BuildContext context, QuizRankingProvider provider) {
    final teamProvider = context.read<TeamProvider>();
    final myTeam = teamProvider.selectedTeam;
    final teamColor = myTeam?.color ?? BUTTON;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final myRanking = currentUserId != null
        ? provider.getMyRanking(currentUserId)
        : null;
    RankingTeamModel? myTeamRanking;
    if (myTeam != null) {
      try {
        myTeamRanking = provider.teamRankings.firstWhere(
          (t) => t.teamName == myTeam.name || t.teamName == myTeam.symplename,
        );
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QuizRankingPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildRankingRow(
              icon: Icons.person,
              iconColor: Colors.blueAccent,
              label: '개인 순위',
              rank: myRanking?.rank,
              score: myRanking?.score,
              emptyText: '기록 없음',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            ),
            _buildRankingRow(
              icon: Icons.groups,
              iconColor: teamColor,
              logoPath: myTeam?.logoPath, // 팀 로고 추가
              label: myTeam != null ? '${myTeam.name} 순위' : '팀 순위',
              rank: myTeamRanking?.rank,
              score: myTeamRanking?.totalScore,
              emptyText: myTeam == null ? '팀 선택 필요' : '기록 없음',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '🏆 랭킹 리포트',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
            color: GRAYSCALE_LABEL_800,
          ),
        ),
        Icon(Icons.chevron_right, color: GRAYSCALE_LABEL_400, size: 20),
      ],
    );
  }

  Widget _buildRankingRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int? rank,
    required int? score,
    required String emptyText,
    String? logoPath,
  }) {
    return Row(
      children: [
        logoPath != null
            ? SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(logoPath, fit: BoxFit.contain),
              )
            : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: GRAYSCALE_LABEL_600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (rank != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$rank위',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              Text(
                '${score ?? 0}점',
                style: const TextStyle(
                  fontSize: 12,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
            ],
          )
        else
          Text(
            emptyText,
            style: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_400),
          ),
      ],
    );
  }
}
