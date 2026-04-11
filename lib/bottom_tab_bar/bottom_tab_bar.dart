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
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
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

      _tabProvider = context.read<TabProvider>();
      _tabProvider.addListener(_handleTabProviderChange);
      _selectedIndex = _tabProvider.selectedIndex;
    });
  }

  void _handleTabProviderChange() {
    if (!mounted) return;
    final index = _tabProvider.selectedIndex;
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
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
                Icon(
                  Icons.notifications_active,
                  color: context.read<TeamProvider>().selectedTeam?.color,
                  size: 28,
                ),
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
                _buildGuideItem('', '더베이스 업데이트 안내 ⚾️'),
                SizedBox(height: 12),
                _buildGuideItem('', '1. 퀴즈 팀랭킹 및 뱃지 & 응원가 듣고 가사 맞추기 추가!'),
                SizedBox(height: 12),
                _buildGuideItem('', '2. 직관 모임 개설 & 실시간 채팅 기능 오픈!'),
                SizedBox(height: 12),
                _buildGuideItem('', '3. 2026 시즌 직관 승률 기록 관리 시작!'),
                SizedBox(height: 12),
                _buildGuideItem('', '새로워진 더베이스를 지금 만나보세요.'),
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
                          activeColor: context
                              .read<TeamProvider>()
                              .selectedTeam
                              ?.color,
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
                    backgroundColor: context
                        .read<TeamProvider>()
                        .selectedTeam
                        ?.color,
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

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WHITE,
          boxShadow: [
            BoxShadow(
              color: GRAYSCALE_LABEL_100.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildScoreBanner(),
            Theme(
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
                selectedFontSize: 11,
                unselectedFontSize: 11,
                iconSize: 25,
                items: [
                  BottomNavigationBarItem(
                    icon: _buildSvgTabIcon(0, AppIcons.home, AppIcons.homeFill),
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
                    icon: _buildSvgTabIcon(2, AppIcons.add, AppIcons.add),
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
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBanner() {
    // 홈 탭(_selectedIndex == 0)일 때만 배너 노출
    if (_selectedIndex != 0) return const SizedBox.shrink();

    return Consumer2<TeamProvider, ScheduleProvider>(
      builder: (context, teamProvider, scheduleProvider, child) {
        final selectedTeam = teamProvider.selectedTeam;
        if (selectedTeam == null || !scheduleProvider.loaded) {
          return const SizedBox.shrink();
        }

        final teamName = selectedTeam.symplename;
        final now = DateTime.now();

        // 1. 관련 게임 필터링 (내 팀의 오늘 경기 / 진행 경기 / 가장 가까운 다음 경기)
        final relatedGames = scheduleProvider.allSchedules.where((s) {
          final isMyTeam = s.homeTeam == teamName || s.awayTeam == teamName;
          if (!isMyTeam) return false;

          // LIVE거나, 오늘 경기거나, 혹은 아직 치러지지 않은 미래의 경기들
          final isToday =
              s.dateTimeKst.year == now.year &&
              s.dateTimeKst.month == now.month &&
              s.dateTimeKst.day == now.day;
          final isFuture = s.dateTimeKst.isAfter(now);

          return isToday || isFuture || s.status == 'LIVE';
        }).toList();

        if (relatedGames.isEmpty) return const SizedBox.shrink();

        // 가장 우선순위 높은 게임 선택 (LIVE -> 가장 가까운 미래)
        relatedGames.sort((a, b) {
          if (a.status == 'LIVE' && b.status != 'LIVE') return -1;
          if (a.status != 'LIVE' && b.status == 'LIVE') return 1;
          return a.dateTimeKst.compareTo(b.dateTimeKst);
        });

        final game = relatedGames.first;
        final isLive = game.status == 'LIVE';
        final isFinal = game.status == 'FINAL';

        // 상태 텍스트
        String statusText = '경기 전';
        if (isLive)
          statusText = game.inning ?? 'LIVE';
        else if (isFinal)
          statusText = '종료';
        else if (game.status == 'PPD')
          statusText = '우천취소';

        // 팀 모델 찾기
        final homeTeam = teamProvider.findTeamByName(game.homeTeam);
        final awayTeam = teamProvider.findTeamByName(game.awayTeam);

        return Padding(
          padding: const EdgeInsets.only(left: 10.0, right: 10.0),
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: selectedTeam.color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  game.stadium,
                  style: const TextStyle(
                    color: WHITE,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D55), Color(0xFF8E5AFF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: WHITE,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    if (awayTeam != null)
                      Image.asset(awayTeam.logoPath, height: 30),
                    const SizedBox(width: 12),
                    if (isLive || isFinal)
                      Text(
                        '${game.awayScore}',
                        style: const TextStyle(
                          color: WHITE,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'kbo',
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: WHITE.withOpacity(0.3),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (isLive || isFinal)
                      Text(
                        '${game.homeScore}',
                        style: const TextStyle(
                          color: WHITE,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'kbo',
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (homeTeam != null)
                      Image.asset(homeTeam.logoPath, height: 30),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
