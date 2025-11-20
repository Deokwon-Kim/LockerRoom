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

    // 선택 목록에서 제외할 팀 이름들
    final excludedTeamNames = <String>[
      '일본',
      '체코',
      '대만',
      '쿠바',
      '호주',
      '도미니카',
      '태국',
      '홍콩',
      '중국',
      'LAD',
      'SD',
    ]; // 여기에 제외할 팀 추가

    // 제외할 팀을 제외한 선택 가능한 팀들
    final selectableTeams = teamProvider
        .where((t) => !excludedTeamNames.contains(t.name))
        .toList();

    // 대한민국 팀을 featuredTeam으로 설정
    final featuredTeam = selectableTeams.firstWhere(
      (t) => t.name == "대한민국",
      orElse: () => selectableTeams[0],
    );

    // featuredTeam을 제외한 나머지 팀들
    final otherTeams = selectableTeams.where((t) => t != featuredTeam).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 50),
          const Text(
            '응원하는 팀을 선택해주세요',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            '선택한 팀의 소식을 가장 먼저 받아보세요.',
            style: TextStyle(fontSize: 13, color: Colors.blueGrey),
          ),
          const SizedBox(height: 20),

          // -------------------------------
          // 1) 가로로 긴 대한민국 팀 카드
          // -------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GestureDetector(
              onTap: () =>
                  context.read<TeamProvider>().selectTeam(featuredTeam),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: featuredTeam.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        context.watch<TeamProvider>().selectedTeam ==
                            featuredTeam
                        ? const Color.fromARGB(255, 255, 188, 2)
                        : featuredTeam.color,
                    width: 3,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          featuredTeam.logoPath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    if (context.watch<TeamProvider>().selectedTeam ==
                        featuredTeam)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.check_circle,
                          color: const Color.fromARGB(255, 255, 188, 2),
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // -------------------------------
          // 2) 다른 팀들: 정사각형 Grid
          // -------------------------------
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: otherTeams.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 정사각형 2개씩
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1, // 정사각형
              ),
              itemBuilder: (context, index) {
                final team = otherTeams[index];
                final isSelected =
                    context.watch<TeamProvider>().selectedTeam == team;

                return GestureDetector(
                  onTap: () => context.read<TeamProvider>().selectTeam(team),
                  child: ThemeTile(
                    teamModel: team,
                    isSelected: isSelected,
                    onTap: () => context.read<TeamProvider>().selectTeam(team),
                  ),
                );
              },
            ),
          ),

          // 기존 완료 버튼은 여기 그대로 유지
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: selectedTeam == null
                    ? null
                    : () => _selectTeam(context, selectedTeam.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedTeam == null ? Colors.grey : BUTTON,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
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
