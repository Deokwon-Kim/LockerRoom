import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/home/after_market.dart';
import 'package:lockerroom/page/home/feed_page.dart';
import 'package:lockerroom/page/home/home_page.dart';
import 'package:lockerroom/page/home/mypage.dart';
import 'package:lockerroom/page/home/upload_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class BottomTabBar extends StatefulWidget {
  const BottomTabBar({super.key});

  @override
  State<BottomTabBar> createState() => _BottomTabBarState();
}

class _BottomTabBarState extends State<BottomTabBar> {
  final List<Widget> _pages = [
    Consumer<TeamProvider>(
      builder: (context, teamProvider, _) => HomePage(
        teamModel: teamProvider.selectedTeam ?? teamProvider.getTeam('team')[0],
      ),
    ),
    FeedPage(),
    UploadPage(),
    AfterMarket(),
    Mypage(),
  ];
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
                selectedItemColor: BUTTON,
                unselectedItemColor: GRAYSCALE_LABEL_500,
                backgroundColor: WHITE,
                items: [
                  BottomNavigationBarItem(
                    icon: _buildTabIcon(0, Icons.home_outlined, Icons.home),
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
                    icon: _buildTabIcon(
                      2,
                      CupertinoIcons.add_circled,
                      CupertinoIcons.add_circled_solid,
                    ),
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
                    icon: _buildTabIcon(4, Icons.person_outline, Icons.person),
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
      padding: const EdgeInsets.only(top: 5),
      child: Icon(
        isSelected ? selectedIcon : unselectedIcon,
        size: 28,
        color: isSelected ? BUTTON : Colors.grey,
      ),
    );
  }
}
