import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/quiz/quiz_ranking_page.dart';
import 'package:lockerroom/page/quiz/quiz_record_page.dart';
import 'package:lockerroom/page/quiz/quiz_start_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';

class QuizTabBar extends StatefulWidget {
  final int initialIndex;
  const QuizTabBar({super.key, this.initialIndex = 0});

  @override
  State<QuizTabBar> createState() => _QuizTabBarState();
}

class _QuizTabBarState extends State<QuizTabBar> {
  int _selectedIndex = 0;
  bool _isBottomBarVisible = true;
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 스크롤 방향 감지
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      final delta = currentPosition - _lastScrollPosition;

      if (delta > 5 && _isBottomBarVisible) {
        setState(() => _isBottomBarVisible = false);
      } else if (delta < -5 && !_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
      }

      _lastScrollPosition = currentPosition;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [QuizStartPage(), QuizRecordPage(), QuizRankingPage()];

    return Scaffold(
      body: Stack(
        children: [
          // 페이지 컨텐츠
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: pages[_selectedIndex],
          ),

          // 플로팅 바텀바
          AnimatedPositioned(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            bottom: _isBottomBarVisible ? 20 : -90,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 200),
              opacity: _isBottomBarVisible ? 1.0 : 0.0,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSvgTabIcon(
                      0,
                      AppIcons.home2,
                      AppIcons.homeFill2,
                      '홈',
                    ),
                    _buildSvgTabIcon(
                      1,
                      AppIcons.person,
                      AppIcons.personFill,
                      '기록',
                    ),
                    _buildNavItem(
                      icon: CupertinoIcons.chart_bar,
                      label: '랭킹',
                      index: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? context.watch<TeamProvider>().selectedTeam?.color
        : GRAYSCALE_LABEL_500;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SVG 아이콘 사용 메서드
  Widget _buildSvgTabIcon(
    int index,
    String unselectedSvgPath,
    String selectedSvgPath,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(
                assetPath: isSelected ? selectedSvgPath : unselectedSvgPath,
                width: 28,
                height: 28,
                color: isSelected
                    ? context.watch<TeamProvider>().selectedTeam?.color
                    : Colors.grey,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? context.watch<TeamProvider>().selectedTeam?.color
                      : GRAYSCALE_LABEL_500,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
