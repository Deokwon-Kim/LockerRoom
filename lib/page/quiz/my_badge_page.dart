import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/badge_model.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class MyBadgePage extends StatefulWidget {
  const MyBadgePage({super.key});

  @override
  State<MyBadgePage> createState() => _MyBadgePageState();
}

class _MyBadgePageState extends State<MyBadgePage>
    with TickerProviderStateMixin {
  late AnimationController _stampController;
  late Animation<double> _stampScale;
  late Animation<double> _stampRotation;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();

    _stampController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _stampScale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _stampRotation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentUserId != null) {
        context.read<BadgeProvider>().fetchMyBadges(currentUserId!);
      }
      _checkUnviewedBadges();
    });
  }

  void _checkUnviewedBadges() async {
    final badgeProvider = context.read<BadgeProvider>();
    final unviewedBadges = badgeProvider.unviewedBadges;

    if (unviewedBadges.isNotEmpty) {
      // 순차적으로 애니메이션 재생
      for (int i = 0; i < unviewedBadges.length; i++) {
        if (!mounted) break;

        // 애니메이션 표시
        _showStampAnimation(unviewedBadges[i]);

        // 2초 대기 후 다이얼로그 닫기
        await Future.delayed(Duration(seconds: 2));

        if (mounted) {
          // 가장 최근에 열린 다이얼로그만 닫기
          Navigator.of(context, rootNavigator: false).pop();
        }

        // 다음 애니메이션 전 잠깐 대기
        if (i < unviewedBadges.length - 1) {
          await Future.delayed(Duration(milliseconds: 400));
        }
      }
    }
  }

  void _showStampAnimation(BadgeModel badge) async {
    // 애니메이션 시작
    _stampController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _stampController,
          builder: (context, child) {
            return Transform.scale(
              scale: _stampScale.value,
              child: Transform.rotate(
                angle: _stampRotation.value,
                child: Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badge.icon, size: 80, color: Colors.amber),
                      SizedBox(height: 20),
                      Text(
                        '🎉 ${badge.name} 획득! 🎉',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'kbo',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        badge.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (mounted) {
      // Firestore에 확인 표시
      context.read<BadgeProvider>().markBadgeAsViewed(badge.id);
    }
  }

  @override
  void dispose() {
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          '뱃지 보관함',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Consumer2<BadgeProvider, TeamProvider>(
        builder: (context, badgeProvider, teamProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 요약 카드
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.military_tech,
                        size: 40,
                        color: teamProvider.selectedTeam?.color,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('수집 진행률', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 4),

                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${badgeProvider.unlockedCount}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / ${badgeProvider.badges.length}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  '벳지 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),

                // 뱃지 그리드
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.76, // 실사용을 위해 최적화된 세로 비율
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: badgeProvider.badges.length,
                    itemBuilder: (context, index) {
                      final badge = badgeProvider.badges[index];
                      final teamColor = teamProvider.selectedTeam?.color;
                      return _buildBadgeItem(badge, teamColor);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadgeItem(BadgeModel badge, Color? teamColor) {
    // 프리미엄 디자인 대상 체크 (시즌 MVP 및 Top 3)
    final bool isElite = badge.id == 'season_mvp' || badge.id == 'top3_club';
    final bool showPremium = isElite && !badge.isLocked; // 획득했을 때만 프리미엄 연출

    final bool isMVP = badge.id == 'season_mvp';
    final bool isTop3 = badge.id == 'top3_club';

    // 디자인 테마 설정
    Color glowColor = teamColor ?? Colors.amber;
    List<Color> borderGradient = [Colors.transparent, Colors.transparent];
    Color badgeBgColor = badge.isLocked ? Colors.grey[200]! : Colors.white;

    if (showPremium) {
      if (isMVP) {
        glowColor = const Color(0xFFFFD700); // GOLD
        borderGradient = [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      } else if (isTop3) {
        glowColor = const Color(0xFFB19CD9); // SILVER/VIOLET
        borderGradient = [const Color(0xFFB19CD9), const Color(0xFFE6E6FA)];
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(12),
        border: showPremium
            ? Border.all(color: borderGradient[0].withOpacity(0.6), width: 2)
            : (badge.isLocked
                  ? null
                  : Border.all(color: glowColor.withOpacity(0.4), width: 1.5)),
        boxShadow: badge.isLocked
            ? []
            : [
                BoxShadow(
                  color: glowColor.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // 프리미엄 배경 효과 (획득 시에만)
            if (showPremium)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        glowColor.withOpacity(0.1),
                        Colors.white,
                        Colors.white,
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Column(
                children: [
                  // 아이콘 영역
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badge.isLocked
                          ? Colors.grey[300]
                          : glowColor.withOpacity(0.1),
                      boxShadow: badge.isLocked
                          ? null
                          : [
                              BoxShadow(
                                color: glowColor.withOpacity(0.2),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                    ),
                    child: Icon(
                      badge.icon,
                      size: 26,
                      color: badge.isLocked ? Colors.grey : glowColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 뱃지 이름
                  Text(
                    badge.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: showPremium
                          ? glowColor
                          : (badge.isLocked ? Colors.grey : Colors.black87),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 설명 영역
                  Expanded(
                    child: Center(
                      child: Text(
                        badge.description,
                        style: TextStyle(
                          fontSize: 9,
                          color: showPremium
                              ? glowColor.withOpacity(0.8)
                              : Colors.grey[600],
                          height: 1.1,
                          fontWeight: showPremium
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
