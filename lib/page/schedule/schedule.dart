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
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateKeys = {};
  DateTime? _pendingScrollDate;
  int _pendingScrollIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _dateKeys.clear();
      _pendingScrollDate = null;
      _pendingScrollIndex = -1;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _dateKeys.clear();
      _pendingScrollDate = null;
      _pendingScrollIndex = -1;
    });
  }

  Future<void> _openMonthPicker(Color teamColor) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime(2026, 12),
      builder: (context, child) {
        final base = Theme.of(context);
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: BACKGROUND_COLOR,
                headerBackgroundColor: BACKGROUND_COLOR,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: teamColor, // 팀 컬러 적용
                surface: BACKGROUND_COLOR,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: teamColor,
                ), // 팀 컬러 적용
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      print('🔍 선택한 날짜: $pickedDate');
      setState(() {
        _currentMonth = DateTime(pickedDate.year, pickedDate.month, 1);
        _pendingScrollDate = pickedDate;
        _dateKeys.clear();
        print('🔍 _pendingScrollDate 설정: $_pendingScrollDate');
      });
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
              icon: Icon(Icons.arrow_back_ios, color: WHITE),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _prevMonth,
                    icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                  ),
                  SizedBox(width: 20),
                  Text(
                    '${_currentMonth.year}년 ${_currentMonth.month.toString().padLeft(2, '0')}월',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => _openMonthPicker(selectedTeam.color),
                    icon: Icon(Icons.date_range_outlined),
                  ),
                  SizedBox(width: 10),
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

                    // 새로운 리스트를 그리기 전에 키를 초기화
                    _dateKeys.clear();

                    // 팀 이름 → TeamModel 매핑을 만들어 로고 경로를 찾는다
                    final nameToTeam = {
                      for (final t in context.read<TeamProvider>().getTeam(
                        'team',
                      ))
                        t.symplename: t,
                    };

                    final sections = sortedDates.map((dateKey) {
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

                      final sectionKey = _dateKeys.putIfAbsent(
                        dateKey,
                        () => GlobalKey(),
                      );

                      return Column(
                        key: sectionKey,
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
                            final statusUpper = s.status.toUpperCase();
                            if (statusUpper.startsWith('CANCELLED')) {
                              badges.add('경기취소');
                            }
                            final dh = s.doubleHeaderNo?.toString().trim();
                            if (dh != null && dh.isNotEmpty) {
                              badges.add('DH $dh');
                            }
                            final headerLine = '$timeStr  ${s.stadium}';

                            // status에 따라 UI 분기
                            final isCancelled =
                                s.status == '우천취소' ||
                                statusUpper.startsWith('CANCELLED');
                            final isInPlay =
                                statusUpper.contains('MS-T') ||
                                statusUpper.contains('SS-T') ||
                                statusUpper.contains('IN_PLAY');
                            final isCompleted =
                                s.status == '종료' ||
                                statusUpper.startsWith('FINAL');

                            final homeTeamModel = nameToTeam[s.homeTeam];
                            final awayTeamModel = nameToTeam[s.awayTeam];

                            // status에 따라 다른 UI 렌더링
                            if (isCancelled) {
                              return _buildCancelledGameCard(
                                s,
                                headerLine,
                                badges,
                                statusUpper,
                                homeTeamModel,
                                awayTeamModel,
                                selectedTeam.color,
                              );
                            } else if (isInPlay) {
                              return _buildInPlayGameCard(
                                s,
                                headerLine,
                                badges,
                                statusUpper,
                                homeTeamModel,
                                awayTeamModel,
                                selectedTeam.color,
                              );
                            } else if (isCompleted) {
                              return _buildCompletedGameCard(
                                s,
                                headerLine,
                                badges,
                                statusUpper,
                                homeTeamModel,
                                awayTeamModel,
                                selectedTeam.color,
                              );
                            } else {
                              // SCHEDULED 상태 (경기 예정)
                              return _buildScheduledGameCard(
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
                    }).toList();

                    // 스크롤할 인덱스 찾기
                    if (_pendingScrollDate != null &&
                        _pendingScrollIndex == -1) {
                      final pendingDate = _pendingScrollDate!;
                      final targetKey = _dateKey(pendingDate);
                      print(
                        '🔍 스크롤 시도: pendingDate=$pendingDate, targetKey=$targetKey',
                      );
                      print('🔍 sortedDates: $sortedDates');

                      final index = sortedDates.indexOf(targetKey);
                      if (index >= 0) {
                        _pendingScrollIndex = index;
                        print('🔍 찾은 인덱스: $index');
                      } else {
                        print('❌ sortedDates에 targetKey가 없습니다');
                        _pendingScrollDate = null;
                      }
                    }

                    // 스크롤 실행
                    if (_pendingScrollIndex >= 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (_scrollController.hasClients) {
                            // 각 섹션의 대략적인 높이 (날짜 헤더 + 경기 카드들)
                            // 평균적으로 날짜당 1-2경기 * 230px(카드 높이) + 헤더 40px 정도
                            final estimatedItemHeight = 260.0;
                            final targetOffset =
                                _pendingScrollIndex * estimatedItemHeight;
                            final maxScroll =
                                _scrollController.position.maxScrollExtent;
                            final scrollTo = targetOffset > maxScroll
                                ? maxScroll
                                : targetOffset;

                            print('✅ 스크롤 실행! offset: $scrollTo');
                            _scrollController.animateTo(
                              scrollTo,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );

                            _pendingScrollDate = null;
                            _pendingScrollIndex = -1;
                          } else {
                            print('❌ ScrollController가 아직 준비되지 않음');
                          }
                        });
                      });
                    }

                    return ListView(
                      controller: _scrollController,
                      children: sections,
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
        height: 200,
        decoration: BoxDecoration(
          color: WHITE,
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 4),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
            ),
            BoxShadow(
              offset: Offset(0, -2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.gameType,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 10),
                  Transform.translate(
                    offset: Offset(0, 1),
                    child: Text(
                      s.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${s.dateTimeKst.hour.toString().padLeft(2, '0')}:${s.dateTimeKst.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 13,
                    ),
                  ),
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
                        const SizedBox(width: 40),
                        const Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                        const SizedBox(width: 40),
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
              Divider(color: GRAYSCALE_LABEL_100),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: GRAYSCALE_LABEL_500, size: 17),
                  Text(
                    s.stadium,
                    style: TextStyle(color: GRAYSCALE_LABEL_600, fontSize: 13),
                  ),
                ],
              ),
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
        height: 200,
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 4),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
            ),
            BoxShadow(
              offset: Offset(0, -2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    child: Text(
                      s.gameType,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: GRAYSCALE_LABEL_500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.all(3),
                    alignment: Alignment.center,
                    width: 40,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_600,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      s.status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: WHITE,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${s.dateTimeKst.hour.toString().padLeft(2, '0')}:${s.dateTimeKst.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 13,
                    ),
                  ),
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                            'VS',
                            style: TextStyle(
                              fontSize: 20,
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
              Divider(color: GRAYSCALE_LABEL_100),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: GRAYSCALE_LABEL_500, size: 17),
                  Text(
                    s.stadium,
                    style: TextStyle(color: GRAYSCALE_LABEL_600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 취소된 경기 UI
  Widget _buildCancelledGameCard(
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
        height: 200,
        decoration: BoxDecoration(
          color: GRAYSCALE_LABEL_50,
          border: Border.all(color: RED_DANGER_BORDER_10, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.gameType,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: RED_DANGER_SURFACE_5,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: RED_DANGER_BORDER_10, width: 1),
                    ),
                    child: Text(
                      s.status,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: RED_DANGER_TEXT_50,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${s.dateTimeKst.hour.toString().padLeft(2, '0')}:${s.dateTimeKst.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 13,
                    ),
                  ),
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
                          Opacity(
                            opacity: 0.5,
                            child: Column(
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
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 30),
                        Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 20,
                            color: GRAYSCALE_LABEL_500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 30),
                        if (homeTeamModel != null)
                          Opacity(
                            opacity: 0.5,
                            child: Column(
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
                                    color: GRAYSCALE_LABEL_500,
                                  ),
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
              Divider(color: GRAYSCALE_LABEL_200),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: GRAYSCALE_LABEL_400, size: 17),
                  Text(
                    s.stadium,
                    style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 경기 중 UI
  Widget _buildInPlayGameCard(
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
        height: 200,
        decoration: BoxDecoration(
          color: WHITE,
          border: Border.all(color: ORANGE_PRIMARY_400, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 4),
              blurRadius: 8,
              color: ORANGE_PRIMARY_400.withOpacity(0.2),
            ),
            BoxShadow(
              offset: Offset(0, -2),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.gameType,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ORANGE_PRIMARY_200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ORANGE_PRIMARY_400, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ORANGE_PRIMARY_500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '경기중',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ORANGE_PRIMARY_700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${s.dateTimeKst.hour.toString().padLeft(2, '0')}:${s.dateTimeKst.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 13,
                    ),
                  ),
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                            'VS',
                            style: TextStyle(
                              fontSize: 20,
                              color: ORANGE_PRIMARY_500,
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
              Divider(color: GRAYSCALE_LABEL_100),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.location_on, color: ORANGE_PRIMARY_500, size: 17),
                  Text(
                    s.stadium,
                    style: TextStyle(
                      color: GRAYSCALE_LABEL_600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
