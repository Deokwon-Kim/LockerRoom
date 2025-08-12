import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final TeamModel teamModel;
  const HomePage({super.key, required this.teamModel});

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? teamModel;
        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: selectedTeam.color,
            leading: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(selectedTeam.symbolPath),
            ),
            title: Text(
              selectedTeam.name,
              style: TextStyle(
                color: WHITE,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(CupertinoIcons.bell, color: WHITE),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SchedulePage(teamModel: teamModel),
                          ),
                        );
                      },
                      child: Text(
                        '전체일정 보기 >',
                        style: TextStyle(color: GRAYSCALE_LABEL_500),
                      ),
                    ),
                  ],
                ),
                FutureBuilder(
                  future: ScheduleService().loadSchedules(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: selectedTeam.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: WHITE),
                        ),
                      );
                    }

                    final schedules = snapshot.data ?? [];
                    final teamName = selectedTeam.name;
                    final now = DateTime.now();

                    // 선택 한 팀의 미래 경기만 필터링 하고 정렬
                    final futureGames =
                        schedules
                            .where(
                              (s) =>
                                  (s.homeTeam == teamName ||
                                      s.awayTeam == teamName) &&
                                  s.dateTimeKst.isAfter(now),
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.dateTimeKst.compareTo(b.dateTimeKst),
                          );

                    final nextGame = futureGames.isNotEmpty
                        ? futureGames.first
                        : null;

                    return Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: selectedTeam.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(selectedTeam.logoPath),
                        ),
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withAlpha(120),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 130.0, left: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '주요 경기 일정',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (nextGame != null) ...[
                                Row(
                                  children: [
                                    Text(
                                      '다음경기:',
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    // Text(
                                    //   '${nextGame.dateTimeKst.month.toString().padLeft(2, '0')}/${nextGame.dateTimeKst.day.toString().padLeft(2, '0')} ${nextGame.dateTimeKst.hour.toString().padLeft(2, '0')}:${nextGame.dateTimeKst.minute.toString().padLeft(2, '0')}',
                                    //   style: TextStyle(
                                    //     color: WHITE,
                                    //     fontSize: 14,
                                    //     fontWeight: FontWeight.w400,
                                    //   ),
                                    // ),
                                    Text(
                                      '${nextGame.homeTeam} vs ${nextGame.awayTeam}',
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
