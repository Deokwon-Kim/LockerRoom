import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';

class SchedulePage extends StatefulWidget {
  final TeamModel teamModel;
  const SchedulePage({super.key, required this.teamModel});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? widget.teamModel;
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
          ),
          body: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '${_currentMonth.year}년 ${_currentMonth.month.toString().padLeft(2, '0')}월',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder(
                  future: ScheduleService().loadSchedules(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: BUTTON),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('일정 로드 실패'));
                    }
                    final schedules = snapshot.data ?? [];
                    final teamName = selectedTeam.name;
                    final teamSchedules = schedules
                        .where(
                          (s) =>
                              s.homeTeam == teamName || s.awayTeam == teamName,
                        )
                        .toList();

                    // 현재 월 필터
                    final filterd = teamSchedules
                        .where(
                          (s) =>
                              s.dateTimeKst.year == _currentMonth.year &&
                              s.dateTimeKst.month == _currentMonth.month,
                        )
                        .toList();

                    if (filterd.isEmpty) {
                      return const Center(child: Text('해당 월 일정이 없습니다.'));
                    }
                    // 팀 이름 → TeamModel 매핑을 만들어 로고 경로를 찾는다
                    final nameToTeam = {
                      for (final t in context.read<TeamProvider>().getTeam(
                        'team',
                      ))
                        t.name: t,
                    };

                    return ListView.builder(
                      itemCount: filterd.length,
                      itemBuilder: (context, index) {
                        final s = filterd[index];
                        final date = s.dateTimeKst;
                        final timeStr =
                            '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
