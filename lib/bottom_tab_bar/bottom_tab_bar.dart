import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/afterMarket/after_market.dart';
import 'package:lockerroom/page/feed/feed_page.dart';
import 'package:lockerroom/page/home/home_page.dart';
import 'package:lockerroom/page/myPage/mypage.dart';
import 'package:lockerroom/page/feed/upload_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BottomTabBar extends StatefulWidget {
  final int initialIndex;
  const BottomTabBar({super.key, this.initialIndex = 0});

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  int _selectedIndex = 0;
  late TeamProvider _teamProvider;
  TeamModel? _previousSelectedTeam;

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
    });
  }

  void _handleTeamProviderChange() {
    final TeamModel? currentTeam = _teamProvider.selectedTeam;
    if (currentTeam != _previousSelectedTeam) {
      _previousSelectedTeam = currentTeam;
      if (mounted) {
        setState(() {
          _selectedIndex = 0; // 팀 변경 시 홈 탭으로 이동
        });
      }
    }
  }

  @override
  void dispose() {
    // Remove listener if it was registered
    try {
      _teamProvider.removeListener(_handleTeamProviderChange);
    } catch (_) {}
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      UploadPage(
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
      AfterMarket(),
      Mypage(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: GRAYSCALE_LABEL_100,
                  spreadRadius: 1,
                  blurRadius: 7,
                  offset: Offset(0, 2),
                ),
              ],
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
                selectedItemColor: teamProvider.selectedTeam?.color,
                unselectedItemColor: GRAYSCALE_LABEL_500,
                backgroundColor: WHITE,
                elevation: 0,
                selectedFontSize: 0,
                unselectedFontSize: 0,
                iconSize: 25,
                items: [
                  BottomNavigationBarItem(
                    icon: _buildSvgTabIcon(0, AppIcons.home, AppIcons.homeFill),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildTabIcon(
                      1,
                      CupertinoIcons.search,
                      CupertinoIcons.search,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildSvgTabIcon(2, AppIcons.add, AppIcons.add),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildTabIcon(
                      3,
                      Icons.storefront_outlined,
                      Icons.storefront_rounded,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildSvgTabIcon(
                      4,
                      AppIcons.person,
                      AppIcons.personFill,
                    ),
                    label: '',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabIcon(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
  ) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Icon(
        isSelected ? selectedIcon : unselectedIcon,
        size: 25,
        color: isSelected
            ? context.watch<TeamProvider>().selectedTeam?.color
            : Colors.grey,
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
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8), // 상하 패딩 조절
      child: SvgIcon(
        assetPath: isSelected ? selectedSvgPath : unselectedSvgPath,
        width: 25,
        height: 25,
        color: isSelected
            ? context.watch<TeamProvider>().selectedTeam?.color
            : Colors.grey,
      ),
    );
  }
}
