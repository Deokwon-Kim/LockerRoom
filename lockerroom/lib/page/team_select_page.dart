import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/components/theme_tile.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class TeamSelectPage extends StatefulWidget {
  const TeamSelectPage({super.key});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  void _selectTeam(BuildContext context, String teamName) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.uid;

    if (userId != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'team': teamName,
      }, SetOptions(merge: true));
    }

    // Provider 업데이트
    await Provider.of<TeamProvider>(context, listen: false).setTeam(teamName);

    // 메인 페이지로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomTabBar()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = Provider.of<TeamProvider>(context).getTeam('team');
    final selectedTeam = context.watch<TeamProvider>().selectedTeam;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: 50),
          Text(
            '응원하는 팀을 선택해주세요',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            '선택한 팀의 소식을 가장 먼저 받아보세요.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(left: 10, right: 10),
              itemCount: teamProvider.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final team = teamProvider[index];

                return ThemeTile(
                  teamModel: team,
                  isSelected:
                      context.watch<TeamProvider>().selectedTeam == team,
                  onTap: () {
                    context.read<TeamProvider>().selectTeam(team);
                  },
                );
              },
            ),
          ),
          GestureDetector(
            onTap: selectedTeam == null
                ? null
                : () {
                    if (selectedTeam != null) {
                      _selectTeam(context, selectedTeam.name);
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: selectedTeam == null ? Colors.grey : BUTTON,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '선택완료',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
