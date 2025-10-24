import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/components/theme_tile.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class TeamSelectPage extends StatefulWidget {
  final bool isChanging;
  const TeamSelectPage({super.key, this.isChanging = false});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  void _selectTeam(BuildContext context, String teamName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 상태를 확인할 수 없습니다.')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'team': teamName,
      }, SetOptions(merge: true));

      // Provider 업데이트
      await Provider.of<TeamProvider>(context, listen: false).setTeam(teamName);

      if (widget.isChanging) {
        Navigator.pop(context, teamName);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => BottomTabBar()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팀 저장에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = Provider.of<TeamProvider>(context).getTeam('team');
    final teamState = context.watch<TeamProvider>();
    final selectedTeam = teamState.selectedTeam;

    // 팀 변경 모드일 때 저장된 팀을 초기 선택으로 지정
    if (widget.isChanging && selectedTeam == null && teamState.team != null) {
      final initial = teamState.findTeamByName(teamState.team!);
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<TeamProvider>().selectTeam(initial);
        });
      }
    }

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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 15,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
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
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: selectedTeam == null
                    ? null
                    : () {
                        _selectTeam(context, selectedTeam.name);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedTeam == null ? Colors.grey : BUTTON,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: Icon(widget.isChanging ? Icons.swap_horiz : Icons.check),
                label: Text(
                  widget.isChanging ? '변경하기' : '선택완료',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
