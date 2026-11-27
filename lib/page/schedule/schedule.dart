import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
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
  TeamModel? _selectedFilterTeam;

  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      builder: (dialogContext, child) {
        final base = Theme.of(dialogContext);
        final isDark = dialogContext.isDarkMode;
        final accent = dialogContext.readableColor(teamColor);
        return Localizations.override(
          context: dialogContext,
          locale: const Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: dialogContext.cardColor,
                headerBackgroundColor: dialogContext.cardColor,
              ),
              colorScheme:
                  (isDark
                          ? const ColorScheme.dark()
                          : const ColorScheme.light())
                      .copyWith(
                        primary: accent,
                        surface: dialogContext.cardColor,
                        onSurface: dialogContext.textPrimary,
                      ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _currentMonth = DateTime(pickedDate.year, pickedDate.month, 1);
        _pendingScrollDate = pickedDate;
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
        final teamName = selectedTeam.name;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        const headerContentHeight = 60.0;
        const overlapHeight = 22.0;
        final totalHeaderHeight =
            statusBarHeight + headerContentHeight + overlapHeight;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: context.bgColor,
            body: Stack(
              children: [
                // 1. 메인 홈과 동일한 멀티-스톱 팀 컬러 그라데이션 헤더
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: totalHeaderHeight,
                  child: _buildHeroHeaderBackground(selectedTeam.color),
                ),

                // 2. 헤더 콘텐츠 (뒤로가기 + 타이틀 + 시즌 배지)
                Positioned(
                  top: statusBarHeight,
                  left: 0,
                  right: 0,
                  height: headerContentHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: WHITE.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: WHITE,
                              size: 17,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$teamName 경기일정',
                            style: const TextStyle(
                              color: WHITE,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: WHITE.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            '${_currentMonth.year} 시즌',
                            style: const TextStyle(
                              color: WHITE,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. 라운드 시트 본문
                Positioned.fill(
                  top: statusBarHeight + headerContentHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        _buildMonthBar(context, selectedTeam.color),
                        const SizedBox(height: 12),
                        _buildTeamFilterStrip(teamProvider, selectedTeam),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _buildScheduleList(teamProvider, selectedTeam),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeaderBackground(Color teamColor) {
    final hsl = HSLColor.fromColor(teamColor);
    final topHighlight = hsl
        .withLightness((hsl.lightness + 0.14).clamp(0.18, 0.48))
        .withSaturation((hsl.saturation + 0.08).clamp(0.15, 0.9))
        .toColor();
    final midTone = Color.lerp(teamColor, BUTTON, 0.25) ?? teamColor;
    final deepShadow =
        Color.lerp(teamColor, const Color(0xFF0A0F1C), 0.68) ??
        const Color(0xFF0A0F1C);

    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.48, 1.0],
            colors: [topHighlight, midTone, deepShadow],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -55,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      WHITE.withValues(alpha: 0.20),
                      topHighlight.withValues(alpha: 0.08),
                      WHITE.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -24,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      topHighlight.withValues(alpha: 0.22),
                      WHITE.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthBar(BuildContext context, Color teamColor) {
    final accent = context.readableColor(teamColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _prevMonth,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.surfaceAltColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: context.textPrimary,
                  size: 22,
                ),
              ),
            ),
            InkWell(
              onTap: () => _openMonthPicker(teamColor),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_currentMonth.year}년 ${_currentMonth.month.toString().padLeft(2, '0')}월',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.date_range_rounded, size: 17, color: accent),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _nextMonth,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.surfaceAltColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamFilterStrip(
    TeamProvider teamProvider,
    TeamModel selectedTeam,
  ) {
    final allTeams = teamProvider.getTeam('team');
    const excludedTeamNames = <String>[
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

    final filterOptions = [
      TeamModel(
        name: '전체',
        symplename: '전체',
        stadium: '',
        headers: '',
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

    return SizedBox(
      height: 76,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: filterOptions.length,
        itemBuilder: (context, index) {
          final team = filterOptions[index];
          final isSelected =
              _selectedFilterTeam?.symplename == team.symplename ||
              (_selectedFilterTeam == null &&
                  team.symplename == selectedTeam.symplename);
          final ringColor = context.readableColor(
            team.symplename == '전체' ? BUTTON : team.color,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilterTeam = team),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? WHITE : context.surfaceAltColor,
                      border: Border.all(
                        color: isSelected ? ringColor : context.borderColor,
                        width: isSelected ? 2.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ringColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4.5),
                        child: team.calenderLogo.isNotEmpty
                            ? Image.asset(
                                team.calenderLogo,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.calendar_month,
                                  size: 20,
                                  color: context.textMuted,
                                ),
                              )
                            : Icon(
                                Icons.shield,
                                size: 20,
                                color: context.textMuted,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    team.symplename,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected ? ringColor : context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleList(TeamProvider teamProvider, TeamModel selectedTeam) {
    final nameToTeam = {
      for (final t in teamProvider.getTeam('team')) t.symplename: t,
    };
    final currentFilterTeam = _selectedFilterTeam ?? selectedTeam;
    final scheduleProvider = context.watch<ScheduleProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduleProvider.updateDisplayItems(
        _currentMonth,
        currentFilterTeam.symplename == '전체'
            ? null
            : currentFilterTeam.symplename,
      );
    });

    final items = scheduleProvider.displayItems;
    final accent = context.readableColor(selectedTeam.color);

    if (!scheduleProvider.loaded) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 40, color: context.textMuted),
            const SizedBox(height: 8),
            Text(
              '해당 월 일정이 없습니다.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_pendingScrollDate != null) {
      final targetKey = _dateKey(_pendingScrollDate!);
      final index = scheduleProvider.getIndexForDate(targetKey);

      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              final scrollTo = index * 200.0;
              final maxScroll = _scrollController.position.maxScrollExtent;
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
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item.type == ScheduleItemType.header) {
          final dateParts = item.dateKey!.split('-');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          final date = DateTime(year, month, day);
          const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
          final weekday = weekdays[date.weekday - 1];

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$year년 $month월 $day일 ($weekday)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        final s = item.game!;
        return _buildGameCard(
          context: context,
          s: s,
          homeTeamModel: nameToTeam[s.homeTeam],
          awayTeamModel: nameToTeam[s.awayTeam],
          selectedTeam: selectedTeam,
          currentFilterTeam: currentFilterTeam,
        );
      },
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required ScheduleModel s,
    required TeamModel? homeTeamModel,
    required TeamModel? awayTeamModel,
    required TeamModel selectedTeam,
    required TeamModel currentFilterTeam,
  }) {
    final statusUpper = s.status.toUpperCase();
    final isCancelled =
        s.status == '우천취소' ||
        statusUpper.startsWith('CANCELLED') ||
        statusUpper == 'PPD';
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

    final accent = context.readableColor(selectedTeam.color);
    final timeStr =
        '${s.dateTimeKst.hour.toString().padLeft(2, '0')}:${s.dateTimeKst.minute.toString().padLeft(2, '0')}';

    // 상태 배지 텍스트 및 컬러
    late final String statusText;
    late final Color statusColor;
    final focusTeam = currentFilterTeam.symplename == '전체'
        ? selectedTeam.symplename
        : currentFilterTeam.symplename;
    final isAwayWin = s.awayScore > s.homeScore;
    final isHomeWin = s.homeScore > s.awayScore;
    final focusWon =
        isCompleted &&
        ((s.homeTeam == focusTeam && isHomeWin) ||
            (s.awayTeam == focusTeam && isAwayWin));

    if (isCancelled) {
      statusText = s.status == '우천취소' ? '우천취소' : '경기취소';
      statusColor = context.textMuted;
    } else if (isInPlay) {
      statusText = 'LIVE ${s.inning ?? ''}'.trim();
      statusColor = const Color(0xFFEF4444);
    } else if (isCompleted) {
      statusText = focusWon ? '종료 · 승' : '종료';
      statusColor = focusWon ? const Color(0xFF10B981) : context.textSecondary;
    } else {
      statusText = '경기 예정';
      statusColor = accent;
    }

    final showScore = isCompleted || isInPlay;
    final isHomeMatch =
        currentFilterTeam.symplename != '전체' &&
        (s.homeTeam == focusTeam || s.awayTeam == focusTeam);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: BLACK.withValues(alpha: context.isDarkMode ? 0.22 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 시리즈명 + 상태 배지 + 경기 시간
            Row(
              children: [
                if (s.gameType.isNotEmpty) ...[
                  Text(
                    s.gameType,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: context.isDarkMode ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 중앙: 원정팀 - 스코어/VS - 홈팀
            Row(
              children: [
                Expanded(
                  child: _buildTeamColumn(
                    context: context,
                    teamName: s.awayTeam,
                    teamModel: awayTeamModel,
                    isWinner: showScore && isAwayWin,
                    accentColor: accent,
                  ),
                ),
                if (showScore) ...[
                  Text(
                    '${s.awayScore}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isAwayWin
                          ? context.textPrimary
                          : context.textMuted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${s.homeScore}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isHomeWin
                          ? context.textPrimary
                          : context.textMuted,
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceAltColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isCancelled ? '취소' : 'VS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                Expanded(
                  child: _buildTeamColumn(
                    context: context,
                    teamName: s.homeTeam,
                    teamModel: homeTeamModel,
                    isWinner: showScore && isHomeWin,
                    accentColor: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 하단: 구장 + 홈/원정 구분
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.dividerColor, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      s.stadium,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isHomeMatch)
                    Text(
                      s.homeTeam == focusTeam ? '홈 경기' : '원정 경기',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn({
    required BuildContext context,
    required String teamName,
    required TeamModel? teamModel,
    required bool isWinner,
    required Color accentColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.surfaceAltColor,
            border: Border.all(
              color: isWinner ? accentColor : context.borderColor,
              width: isWinner ? 2 : 1.2,
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: teamModel != null && teamModel.calenderLogo.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    teamModel.calenderLogo,
                    fit: BoxFit.contain,
                  ),
                )
              : Icon(Icons.sports_baseball, color: context.textMuted, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          teamName,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isWinner ? FontWeight.w800 : FontWeight.w700,
            color: context.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
