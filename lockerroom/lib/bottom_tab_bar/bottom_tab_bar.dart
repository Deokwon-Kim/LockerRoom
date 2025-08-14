import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/home/after_market.dart';
import 'package:lockerroom/page/home/feed_page.dart';
import 'package:lockerroom/page/home/home_page.dart';
import 'package:lockerroom/page/home/mypage.dart';
import 'package:lockerroom/page/home/upload_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/provider/bottom_tab_bar_provider.dart';
import 'package:lockerroom/widgets/svg_icon.dart';
import 'package:provider/provider.dart';

class BottomTabBar extends StatefulWidget {
  const BottomTabBar({super.key});

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  String? _lastAppliedFavoriteTeam;

  void _onItemTapped(int index) {
    context.read<BottomTabBarProvider>().setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BottomTabBarProvider>(
      builder: (context, tabProvider, child) {
        Widget body;
        switch (tabProvider.selectedIndex) {
          case 0:
            body = Consumer2<TeamProvider, UserProvider>(
              builder: (context, teamProvider, userProvider, _) {
                final fav = userProvider.favoriteTeam;
                if (fav != null &&
                    teamProvider.selectedTeam?.name != fav &&
                    _lastAppliedFavoriteTeam != fav) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.read<TeamProvider>().selectTeamByName(fav);
                    _lastAppliedFavoriteTeam = fav;
                  });
                }
                return HomePage(
                  teamModel:
                      teamProvider.selectedTeam ??
                      teamProvider.getTeam('team')[0],
                );
              },
            );
            break;
          case 1:
            body = const FeedPage();
            break;
          case 2:
            body = const UploadPage();
            break;
          case 3:
            body = const AfterMarket();
            break;
          case 4:
          default:
            body = const Mypage();
            break;
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70, // 바텀바 전체 높이 조절
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
                    currentIndex: tabProvider.selectedIndex,
                    onTap: _onItemTapped,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: BUTTON,
                    unselectedItemColor: GRAYSCALE_LABEL_500,
                    backgroundColor: WHITE,
                    elevation: 0,
                    selectedFontSize: 0,
                    unselectedFontSize: 0,
                    iconSize: 25,
                    items: [
                      BottomNavigationBarItem(
                        icon: _buildSvgTabIcon(
                          0,
                          AppIcons.home,
                          AppIcons.homeFill,
                          tabProvider.selectedIndex,
                        ),
                        label: '',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildTabIcon(
                          1,
                          CupertinoIcons.search,
                          CupertinoIcons.search,
                          tabProvider.selectedIndex,
                        ),
                        label: '',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildSvgTabIcon(
                          2,
                          AppIcons.add,
                          AppIcons.add,
                          tabProvider.selectedIndex,
                        ),
                        label: '',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildTabIcon(
                          3,
                          Icons.storefront_outlined,
                          Icons.storefront_rounded,
                          tabProvider.selectedIndex,
                        ),
                        label: '',
                      ),
                      BottomNavigationBarItem(
                        icon: _buildSvgTabIcon(
                          4,
                          AppIcons.person,
                          AppIcons.personFill,
                          tabProvider.selectedIndex,
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
      },
    );
  }

  Widget _buildTabIcon(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    int selectedIndex,
  ) {
    bool isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8), // 상하 패딩 조절
      child: Icon(
        isSelected ? selectedIcon : unselectedIcon,
        size: 25,
        color: isSelected ? BUTTON : Colors.grey,
      ),
    );
  }

  // SVG 아이콘을 사용하는 새로운 메서드
  Widget _buildSvgTabIcon(
    int index,
    String unselectedSvgPath,
    String selectedSvgPath,
    int selectedIndex,
  ) {
    bool isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8), // 상하 패딩 조절
      child: SvgIcon(
        assetPath: isSelected ? selectedSvgPath : unselectedSvgPath,
        width: 25,
        height: 25,
        color: isSelected ? BUTTON : Colors.grey,
      ),
    );
  }
}
