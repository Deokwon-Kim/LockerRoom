import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';

class SchedulePage extends StatelessWidget {
  final TeamModel teamModel;
  const SchedulePage({super.key, required this.teamModel});

  @override
  Widget build(BuildContext context) {
    final nameToTeam = {
      for (final t in context.read<TeamProvider>().getTeam('team')) t.name: t,
    };

    // 날짜 정렬 + 월별 헤더 아이템 생성
    final sorted = [...teamSchedules]
      ..sort((a, b) => a.dateTimeKst.compareTo(b.dateTimeKst));
    final List<Map<String, Object>> items = [];
    int? currentMonth, currentYear;

    for (final s in sorted) {
      final y = s.dateTimeKst.year;
    }
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? teamModel;
        final teamName = teamProvider.selectedTeam?.name;
        return Scaffold(
          backgroundColor: WHITE,
          appBar: AppBar(
            backgroundColor: selectedTeam.color,
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(Icons.arrow_back, color: WHITE),
            ),
            title: Text(
              '$teamName 경기일정',
              style: TextStyle(color: WHITE, fontSize: 17),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: Icon(CupertinoIcons.bell, color: WHITE),
              ),
            ],
          ),
          body: FutureBuilder(
            future: ScheduleService().loadSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('일정 로드 실패'));
              }
              final schedules = snapshot.data ?? [];
              final teamName = selectedTeam.name;
              final teamSchedules = schedules
                  .where(
                    (s) => s.homeTeam == teamName || s.awayTeam == teamName,
                  )
                  .toList();

              if (teamSchedules.isEmpty) {
                return const Center(child: Text('해당 팀 일정이 없습니다.'));
              }
              // 팀 이름 → TeamModel 매핑을 만들어 로고 경로를 찾는다
              final nameToTeam = {
                for (final t in context.read<TeamProvider>().getTeam('team'))
                  t.name: t,
              };

              return ListView.separated(
                itemCount: teamSchedules.length,
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final s = teamSchedules[index];
                  final isHome = s.homeTeam == teamName;
                  final opponent = isHome ? s.awayTeam : s.homeTeam;
                  final date = s.dateTimeKst;
                  final timeStr =
                      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  final homeTeamModel = nameToTeam[s.homeTeam];
                  final awayTeamModel = nameToTeam[s.awayTeam];
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: WHITE,
                        border: Border.all(color: selectedTeam.color),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$timeStr · ${s.stadium}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (awayTeamModel != null)
                                  Row(
                                    children: [
                                      Text(
                                        s.awayTeam,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Image.asset(
                                        awayTeamModel.logoPath,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),

                                const SizedBox(width: 12),
                                const Text(
                                  'vs',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (homeTeamModel != null)
                                  Row(
                                    children: [
                                      Image.asset(
                                        homeTeamModel.logoPath,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.contain,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        s.homeTeam,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
