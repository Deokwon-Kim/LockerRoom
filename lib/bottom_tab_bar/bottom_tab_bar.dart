import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/feed/feed_page.dart';
import 'package:lockerroom/page/home/home_page.dart';
import 'package:lockerroom/page/meetup/meetup_page.dart';
import 'package:lockerroom/page/myPage/mypage.dart';
import 'package:lockerroom/page/feed/feed_upload_page.dart';
import 'package:lockerroom/provider/tab_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/utils/version_check.dart';
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BottomTabBar extends StatefulWidget {
  final int initialIndex;
  const BottomTabBar({super.key, this.initialIndex = 0});

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  int _selectedIndex = 0;
  late TeamProvider _teamProvider;
  late TabProvider _tabProvider;
  TeamModel? _previousSelectedTeam;

  final List<String> _screenNames = [
    '홈_메인',
    '피드_목록',
    '피드_업로드',
    '모임_목록',
    '마이페이지',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Delay provider access until after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _teamProvider = context.read<TeamProvider>();
      _previousSelectedTeam = _teamProvider.selectedTeam;
      _teamProvider.addListener(_handleTeamProviderChange);

      _tabProvider = context.read<TabProvider>();
      _tabProvider.addListener(_handleTabProviderChange);
      _selectedIndex = _tabProvider.selectedIndex;

      // 초기 앱 진입 탭 추적
      FirebaseAnalytics.instance.logScreenView(
        screenName: _screenNames[_selectedIndex],
        screenClass: 'BottomTabBar',
      );
      VersionCheck.checkVersion(context);
    });
  }

  void _handleTabProviderChange() {
    if (!mounted) return;
    final index = _tabProvider.selectedIndex;
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      // 프로바이더를 통한 탭 변경 시도 추적
      FirebaseAnalytics.instance.logScreenView(
        screenName: _screenNames[index],
        screenClass: 'BottomTabBar',
      );
    }
  }

  void _handleTeamProviderChange() {
    final TeamModel? currentTeam = _teamProvider.selectedTeam;
    if (currentTeam != _previousSelectedTeam) {
      _previousSelectedTeam = currentTeam;
      if (mounted) {
        setState(() {
          _selectedIndex = 0; // 팀 변경 시 홈 탭으로 이동
        });
        FirebaseAnalytics.instance.logScreenView(
          screenName: '홈_메인',
          screenClass: 'BottomTabBar',
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      _teamProvider.removeListener(_handleTeamProviderChange);
    } catch (_) {}
    try {
      _tabProvider.removeListener(_handleTabProviderChange);
    } catch (_) {}
    super.dispose();
  }

  void _onItemTapped(int index) {
    context.read<TabProvider>().setSelectedIndex(index);
    setState(() {
      _selectedIndex = index;
    });

    // 애널리틱스 탭 추적 추가
    FirebaseAnalytics.instance.logScreenView(
      screenName: _screenNames[index],
      screenClass: 'BottomTabBar',
    );

    if (index == 4) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<TeamProvider>().loadTeam(user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    final pages = [
      Consumer<TeamProvider>(
        builder: (context, teamProvider, _) => HomePage(
          teamModel:
              teamProvider.selectedTeam ?? teamProvider.getTeam('team')[0],
          onTabTab: (i) => setState(() => _selectedIndex = i),
          selectedTeam:
              teamProvider.selectedTeam ?? teamProvider.getTeam('team')[0],
        ),
      ),
      FeedPage(),
      FeedUploadPage(
        onUploaded: () {
          // UI 상태 충돌을 방지하기 위해 지연 실행
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _selectedIndex = 1; // 업로드 후 Feed 탭으로 이동
              });
            }
          });
        },
      ),
      MeetupPage(),
      Mypage(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ];

    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final activeTabColor =
        (context.isDarkMode && teamColor.computeLuminance() < 0.22)
        ? ACCENT_CORAL
        : teamColor;

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // _buildScoreBanner(),
            CustomPaint(
              painter: ConvexTabBarPainter(
                backgroundColor: context.cardColor,
                shadowColor: (context.isDarkMode ? BLACK : GRAYSCALE_LABEL_100)
                    .withValues(alpha: 0.5),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: activeTabColor,
                  unselectedItemColor: GRAYSCALE_LABEL_500,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  iconSize: 25,
                  items: [
                    BottomNavigationBarItem(
                      icon: _buildSvgTabIcon(
                        0,
                        AppIcons.home,
                        AppIcons.homeFill,
                      ),
                      label: '홈',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildTabIcon(
                        1,
                        Icons.sports_baseball_outlined,
                        Icons.sports_baseball,
                      ),
                      label: '피드',
                    ),
                    BottomNavigationBarItem(
                      icon: Transform.translate(
                        offset: const Offset(0, -6),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Icon(
                            Icons.add_circle,
                            size: 40,
                            color: teamProvider.selectedTeam?.color,
                          ),
                        ),
                      ),
                      label: '업로드',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildTabIcon(3, Icons.group_outlined, Icons.group),
                      label: '직관모임',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildSvgTabIcon(
                        4,
                        AppIcons.person,
                        AppIcons.personFill,
                      ),
                      label: '내정보',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabIcon(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
  ) {
    bool isSelected = _selectedIndex == index;
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final activeColor =
        (context.isDarkMode && teamColor.computeLuminance() < 0.22)
        ? ACCENT_CORAL
        : teamColor;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Icon(
        isSelected ? selectedIcon : unselectedIcon,
        size: 29,
        color: isSelected ? activeColor : Colors.grey,
      ),
    );
  }

  // SVG 아이콘 사용 메서드
  Widget _buildSvgTabIcon(
    int index,
    String unselectedSvgPath,
    String selectedSvgPath,
  ) {
    bool isSelected = _selectedIndex == index;
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final activeColor =
        (context.isDarkMode && teamColor.computeLuminance() < 0.22)
        ? ACCENT_CORAL
        : teamColor;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8), // 상하 패딩 조절
      child: SvgIcon(
        assetPath: isSelected ? selectedSvgPath : unselectedSvgPath,
        width: 28,
        height: 28,
        color: isSelected ? activeColor : Colors.grey,
      ),
    );
  }
}

class ConvexTabBarPainter extends CustomPainter {
  final Color backgroundColor;
  final Color shadowColor;

  ConvexTabBarPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    const bumpWidth = 76.0;
    const bumpHeight = 13.0;
    final left = cx - bumpWidth / 2;
    final right = cx + bumpWidth / 2;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(left, 0);
    path.cubicTo(
      left + bumpWidth * 0.25,
      0,
      cx - bumpWidth * 0.22,
      -bumpHeight,
      cx,
      -bumpHeight,
    );
    path.cubicTo(
      cx + bumpWidth * 0.22,
      -bumpHeight,
      right - bumpWidth * 0.25,
      0,
      right,
      0,
    );
    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // 상단 그림자
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.save();
    canvas.translate(0, -2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 본체 배경
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant ConvexTabBarPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.shadowColor != shadowColor;
}
