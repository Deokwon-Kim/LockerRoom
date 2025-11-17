import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
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
          backgroundColor: GRAYSCALE_LABEL_50,
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
              style: TextStyle(
                color: WHITE,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                  ),

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
                    final teamName = selectedTeam.symplename;
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

                    // 날짜별로 그룹화
                    final Map<String, List<ScheduleModel>> schedulesByDate = {};
                    for (final schedule in filterd) {
                      final dateKey =
                          '${schedule.dateTimeKst.year}-'
                          '${schedule.dateTimeKst.month.toString().padLeft(2, '0')}-'
                          '${schedule.dateTimeKst.day.toString().padLeft(2, '0')}';
                      schedulesByDate
                          .putIfAbsent(dateKey, () => [])
                          .add(schedule);
                    }

                    // 날짜순으로 정렬
                    final sortedDates = schedulesByDate.keys.toList()..sort();

                    // 팀 이름 → TeamModel 매핑을 만들어 로고 경로를 찾는다
                    final nameToTeam = {
                      for (final t in context.read<TeamProvider>().getTeam(
                        'team',
                      ))
                        t.symplename: t,
                    };

                    return ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, dateIndex) {
                        final dateKey = sortedDates[dateIndex];
                        final schedulesForDate = schedulesByDate[dateKey]!;

                        // 날짜 파싱
                        final dateParts = dateKey.split('-');
                        final year = int.parse(dateParts[0]);
                        final month = int.parse(dateParts[1]);
                        final day = int.parse(dateParts[2]);
                        final date = DateTime(year, month, day);

                        // 요일 계산
                        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                        final weekday = weekdays[date.weekday - 1];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 날짜 헤더
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10.0,
                                left: 10.0,
                              ),
                              child: Text(
                                '$year년 $month월 $day일 ($weekday)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: GRAYSCALE_LABEL_900,
                                ),
                              ),
                            ),
                            // 해당 날짜의 일정들
                            ...schedulesForDate.map((s) {
                              final scheduleDate = s.dateTimeKst;
                              final timeStr =
                                  '${scheduleDate.hour.toString().padLeft(2, '0')}:${scheduleDate.minute.toString().padLeft(2, '0')}';

                              // 상태/더블헤더 배지 텍스트 구성
                              final List<String> badges = [];
                              final statusUpper = s.status
                                  .toString()
                                  .toUpperCase();
                              if (statusUpper.startsWith('CANCELLED')) {
                                badges.add('경기취소');
                              }
                              final dh = s.doubleHeaderNo?.toString().trim();
                              if (dh != null && dh.isNotEmpty) {
                                badges.add('DH $dh');
                              }
                              final headerLine = '$timeStr  ${s.stadium}';

                              // 경기 전 여부 확인 (SCHEDULED 상태이거나 스코어가 0-0인 경우)
                              final isScheduled =
                                  statusUpper == 'SCHEDULED' ||
                                  (s.homeScore == 0 &&
                                      s.awayScroe == 0 &&
                                      !statusUpper.startsWith('FINAL') &&
                                      !statusUpper.startsWith('IN_PLAY'));

                              final homeTeamModel = nameToTeam[s.homeTeam];
                              final awayTeamModel = nameToTeam[s.awayTeam];

                              // 스코어가 있을 때와 없을 때 완전히 다른 UI 렌더링
                              if (isScheduled) {
                                return _buildScheduledGameCard(
                                  s,
                                  headerLine,
                                  badges,
                                  statusUpper,
                                  homeTeamModel,
                                  awayTeamModel,
                                  selectedTeam.color,
                                );
                              } else {
                                return _buildCompletedGameCard(
                                  s,
                                  headerLine,
                                  badges,
                                  statusUpper,
                                  homeTeamModel,
                                  awayTeamModel,
                                  selectedTeam.color,
                                );
                              }
                            }).toList(),
                          ],
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

  // 스코어가 없을 때 (경기 전) UI
  Widget _buildScheduledGameCard(
    ScheduleModel s,
    String headerLine,
    List<String> badges,
    String statusUpper,
    TeamModel? homeTeamModel,
    TeamModel? awayTeamModel,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: WHITE,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerLine,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      badges.join('  '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusUpper.startsWith('CANCELLED')
                            ? Colors.red
                            : GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = constraints.maxWidth;
                  final double logoSize = availableWidth * 0.20;
                  final double clampedLogo = logoSize.clamp(28.0, 64.0);

                  return Padding(
                    padding: const EdgeInsets.only(left: 60.0, right: 50.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (awayTeamModel != null)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: clampedLogo,
                                height: clampedLogo,
                                child: Image.asset(
                                  awayTeamModel.calenderLogo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.awayTeam,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(width: 20),
                        const Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 20),
                        if (homeTeamModel != null)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: clampedLogo,
                                height: clampedLogo,
                                child: Image.asset(
                                  homeTeamModel.calenderLogo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.homeTeam,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // 스코어가 있을 때 (경기 후) UI
  Widget _buildCompletedGameCard(
    ScheduleModel s,
    String headerLine,
    List<String> badges,
    String statusUpper,
    TeamModel? homeTeamModel,
    TeamModel? awayTeamModel,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: WHITE,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerLine,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      badges.join('  '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusUpper.startsWith('CANCELLED')
                            ? Colors.red
                            : GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = constraints.maxWidth;
                  final double logoSize = availableWidth * 0.18;
                  final double clampedLogo = logoSize.clamp(32.0, 56.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 원정팀
                        if (awayTeamModel != null)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: clampedLogo,
                                      height: clampedLogo,
                                      child: Image.asset(
                                        awayTeamModel.calenderLogo,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.awayTeam,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${s.awayScroe}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    color: GRAYSCALE_LABEL_900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 스코어 구분선
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 32,
                              color: GRAYSCALE_LABEL_500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 홈팀
                        if (homeTeamModel != null)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  '${s.homeScore}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    color: GRAYSCALE_LABEL_900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: clampedLogo,
                                      height: clampedLogo,
                                      child: Image.asset(
                                        homeTeamModel.calenderLogo,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.homeTeam,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
