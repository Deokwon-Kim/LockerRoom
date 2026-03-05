import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:provider/provider.dart';

class SchedulePage extends StatefulWidget {
  final TeamModel teamModel;
  const SchedulePage({super.key, required this.teamModel});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _pendingScrollDate;
  TeamModel? _selectedFilterTeam; // 추가된 필터 팀 상태

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
      _pendingScrollDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _pendingScrollDate = null;
    });
  }

  Future<void> _openMonthPicker(Color teamColor) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2010, 1),
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
            scrolledUnderElevation: 0,
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
              // 팀 필터 버튼 추가
              SizedBox(height: 10),
              SizedBox(
                height: 80, // 필터 버튼 높이 확대
                child: Consumer<TeamProvider>(
                  builder: (context, teamProvider, child) {
                    final allTeams = teamProvider.getTeam('team');

                    // 팀 선택 뷰와 동일한 제외 목록 적용
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
                      'SK와이번스',
                      '넥센히어로즈',
                      '미국',
                      '이스라엘',
                      '멕시코',
                      '인도네시아',
                      '베네수엘라',
                      '파키스탄',
                      '네덜란드',
                      '캐나다',
                    ];

                    final selectableTeams = allTeams
                        .where((t) => !excludedTeamNames.contains(t.name))
                        .toList();

                    // '전체' 옵션을 추가
                    final filterOptions = [
                      TeamModel(
                        name: '전체',
                        symplename: '전체',
                        stadium: '',
                        logoPath: 'assets/images/logo/kbo_logo.png',
                        calenderLogo: 'assets/images/logo/kbo_logo.png',
                        symbolPath: '',
                        youtubeName: '',
                        youtubeUrl: '',
                        channelId: '',
                        color: BUTTON,
                      ),
                      ...selectableTeams,
                    ];

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: filterOptions.length,
                      itemBuilder: (context, index) {
                        final team = filterOptions[index];
                        final isSelected =
                            _selectedFilterTeam?.symplename ==
                                team.symplename ||
                            (_selectedFilterTeam == null &&
                                team.symplename ==
                                    (teamProvider.selectedTeam ??
                                            widget.teamModel)
                                        .symplename);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFilterTeam = team;
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? WHITE
                                        : GRAYSCALE_LABEL_50,
                                    border: Border.all(
                                      color: isSelected
                                          ? (team.symplename == '전체'
                                                ? BUTTON
                                                : team.color)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ClipOval(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: team.calenderLogo.isNotEmpty
                                          ? Image.asset(
                                              team.calenderLogo,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.calendar_month,
                                                    size: 20,
                                                    color: GRAYSCALE_LABEL_400,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.shield,
                                              size: 20,
                                              color: GRAYSCALE_LABEL_400,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  team.symplename,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? GRAYSCALE_LABEL_900
                                        : GRAYSCALE_LABEL_500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: Consumer<ScheduleProvider>(
                  builder: (context, scheduleProvider, child) {
                    // 팀 이름에 어울리는 TeamProvider 객체 맵
                    final nameToTeam = {
                      for (final t in context.read<TeamProvider>().getTeam(
                        'team',
                      ))
                        t.symplename: t,
                    };

                    final teamProvider = Provider.of<TeamProvider>(
                      context,
                      listen: false,
                    );
                    final selectedTeam =
                        teamProvider.selectedTeam ??
                        TeamModel(
                          name: '두산베어스',
                          symplename: '두산',
                          stadium: '잠실',
                          logoPath: '',
                          calenderLogo: '',
                          symbolPath: '',
                          youtubeName: '',
                          youtubeUrl: '',
                          channelId: '',
                          color: BUTTON,
                        );

                    // 필터링에 사용할 팀 결정: 명시적 선택이 없으면 내 응원팀 사용
                    final currentFilterTeam =
                        _selectedFilterTeam ?? selectedTeam;

                    final scheduleProvider = Provider.of<ScheduleProvider>(
                      context,
                    );

                    // 데이터 업데이트 호출 (빌드 시점)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      scheduleProvider.updateDisplayItems(
                        _currentMonth,
                        currentFilterTeam.symplename == '전체'
                            ? null
                            : currentFilterTeam.symplename,
                      );
                    });

                    final items = scheduleProvider.displayItems;

                    if (!scheduleProvider.loaded) {
                      return const Center(
                        child: CircularProgressIndicator(color: BUTTON),
                      );
                    }
                    if (items.isEmpty) {
                      return const Center(child: Text('해당 월 일정이 없습니다.'));
                    }

                    // 스크롤 로직 (인덱스 기반)
                    if (_pendingScrollDate != null) {
                      final targetKey = _dateKey(_pendingScrollDate!);
                      final index = scheduleProvider.getIndexForDate(targetKey);

                      if (index >= 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (_scrollController.hasClients) {
                              // 아이템별 고정 높이가 아니므로 정확한 위치 계산은 어렵지만
                              // 대략적인 위치로 이동 (평균 200px)
                              final scrollTo = index * 200.0;
                              final maxScroll =
                                  _scrollController.position.maxScrollExtent;

                              _scrollController.animateTo(
                                scrollTo.clamp(0.0, maxScroll),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                              _pendingScrollDate = null;
                            }
                          });
                        });
                      } else {
                        _pendingScrollDate = null;
                      }
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        if (item.type == ScheduleItemType.header) {
                          // 날짜 헤더 렌더링
                          final dateParts = item.dateKey!.split('-');
                          final year = int.parse(dateParts[0]);
                          final month = int.parse(dateParts[1]);
                          final day = int.parse(dateParts[2]);
                          final date = DateTime(year, month, day);
                          final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                          final weekday = weekdays[date.weekday - 1];

                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 20.0,
                              left: 16.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              '$year년 $month월 $day일 ($weekday)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: GRAYSCALE_LABEL_900,
                              ),
                            ),
                          );
                        } else {
                          // 경기 카드 렌더링
                          final s = item.game!;
                          final scheduleDate = s.dateTimeKst;
                          final timeStr =
                              '${scheduleDate.hour.toString().padLeft(2, '0')}:${scheduleDate.minute.toString().padLeft(2, '0')}';

                          final List<String> badges = [];
                          final statusUpper = s.status.toUpperCase();
                          if (statusUpper.startsWith('CANCELLED'))
                            badges.add('경기취소');
                          final dh = s.doubleHeaderNo?.toString().trim();
                          if (dh != null && dh.isNotEmpty) badges.add('DH $dh');

                          final headerLine = '$timeStr  ${s.stadium}';
                          final isCancelled =
                              s.status == '우천취소' ||
                              statusUpper.startsWith('CANCELLED');
                          final isInPlay =
                              statusUpper.contains('MS-T') ||
                              statusUpper.contains('SS-T') ||
                              statusUpper.contains('IN_PLAY') ||
                              statusUpper.contains('LIVE') ||
                              statusUpper.contains('진행중');
                          final isCompleted =
                              s.status == '종료' ||
                              statusUpper.startsWith('FINAL') ||
                              statusUpper.contains('종료');

                          final homeTeamModel = nameToTeam[s.homeTeam];
                          final awayTeamModel = nameToTeam[s.awayTeam];

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
                        }
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
                                  '${s.awayScore}',
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
                          '진행중 ${s.inning ?? ""}'.trim(),
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
                                  '${s.awayScore}',
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
