import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class MyBadgePage extends StatefulWidget {
  const MyBadgePage({super.key});

  @override
  State<MyBadgePage> createState() => _MyBadgePageState();
}

class _MyBadgePageState extends State<MyBadgePage> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BadgeProvider>().fetchMyBadges('current');
    });
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
                      childAspectRatio: 0.70,
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

  Widget _buildBadgeItem(badge, teamColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.isLocked ? Colors.grey[200] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: badge.isLocked
            ? null
            : Border.all(color: teamColor ?? Colors.amber, width: 2),
        boxShadow: badge.isLocked
            ? []
            : [
                BoxShadow(
                  color: teamColor ?? Colors.amber.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.isLocked ? Colors.grey[300] : Colors.amber[50],
            ),
            child: Icon(
              badge.icon,
              size: 32,
              color: badge.isLocked ? Colors.grey : teamColor ?? Colors.amber,
            ),
          ),
          SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: badge.isLocked ? Colors.grey : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          // 설명은 작게
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              badge.description,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
