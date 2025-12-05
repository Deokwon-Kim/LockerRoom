import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/afterMarket/after_market.dart';
import 'package:lockerroom/page/feed/feed_page.dart';
import 'package:lockerroom/page/home/home_page.dart';
import 'package:lockerroom/page/myPage/mypage.dart';
import 'package:lockerroom/page/feed/feed_upload_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

      _checkAndShowCheerSongPopup();
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

  // 팝업 표시 여부 확인 및 표시
  Future<void> _checkAndShowCheerSongPopup() async {
    final prefs = await SharedPreferences.getInstance();
    // 키 변경: dontShowCheerSongPopup -> dontShowMainPopup
    final bool dontShowAgain = prefs.getBool('dontShowMainPopup') ?? false;

    if (!dontShowAgain) {
      if (mounted) _showCheerSongGuidePopup();
    }
  }

  void _showCheerSongGuidePopup() {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: WHITE,
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: BUTTON, size: 28),
                SizedBox(width: 8),
                Text(
                  '공지사항',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'kbo',
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGuideItem('', '새로운 기능이 추가되었습니다!'),
                SizedBox(height: 12),
                _buildGuideItem('', '1. 야구 퀴즈 오픈 (KBO 역사·응원가 포함)'),
                SizedBox(height: 12),
                _buildGuideItem('', '2. 직관 기록 분석 페이지 추가'),
                SizedBox(height: 12),
                _buildGuideItem('', '3. 직관 기록 승률 전용 페이지 신설'),
                SizedBox(height: 12),
                _buildGuideItem('', '지금 바로 확인해보세요!'),
                SizedBox(height: 20),
                // 다시 보지 않기 체크박스
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isChecked = !isChecked;
                    });
                  },
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: BUTTON,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (value) {
                            setState(() {
                              isChecked = value ?? false;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '다시 보지 않기',
                        style: TextStyle(
                          color: GRAYSCALE_LABEL_600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isChecked) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('dontShowMainPopup', true);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BUTTON,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 가이드 아이템 빌더
  Widget _buildGuideItem(String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: TextStyle(fontSize: 20)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: GRAYSCALE_LABEL_800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
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
      AfterMarket(),
      Mypage(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(left: 0, right: 0, top: 0),
        decoration: BoxDecoration(
          color: WHITE,
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
                  Icons.sports_baseball_outlined,
                  Icons.sports_baseball,
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _buildSvgTabIcon(2, AppIcons.add, AppIcons.add),
                label: '',
              ),

              BottomNavigationBarItem(
                icon: _buildSvgTabIcon(3, AppIcons.shop, AppIcons.shopFill),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _buildSvgTabIcon(4, AppIcons.person, AppIcons.personFill),
                label: '',
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Icon(
        isSelected ? selectedIcon : unselectedIcon,
        size: 29,
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
        width: 28,
        height: 28,
        color: isSelected
            ? context.watch<TeamProvider>().selectedTeam?.color
            : Colors.grey,
      ),
    );
  }
}
