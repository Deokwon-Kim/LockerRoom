import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _selectedCategory = '상대별';
  final List<String> _category = ['상대별', '구장별', '요일별', '홈/원정'];

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WHITE,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '분석 기준 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: BLACK,
                ),
              ),
              SizedBox(height: 16),
              ..._category.map((category) {
                final isSelected = category == _selectedCategory;
                return ListTile(
                  title: Text(
                    category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? (context.read<TeamProvider>().selectedTeam?.color ??
                                BUTTON)
                          : BLACK,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color:
                              context
                                  .read<TeamProvider>()
                                  .selectedTeam
                                  ?.color ??
                              BUTTON,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showYearPicker(BuildContext context, IntutionRecordListProvider irp) {
    final years = irp.availableYears;

    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }

    // 전체선택 옵션
    final allYears = [null, ...years];

    int selectedIndex = allYears.indexOf(irp.selectedYear);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              // 상단 버튼
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground.resolveFrom(
                    context,
                  ),
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    irp.setYear(allYears[index]);
                  },
                  children: allYears.map((year) {
                    return Center(
                      child: Text(
                        year == null ? '전체' : '$year년',
                        style: TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              '분석',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 12),
            Consumer<IntutionRecordListProvider>(
              builder: (context, lp, child) {
                return GestureDetector(
                  onTap: () => _showYearPicker(context, lp),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GRAYSCALE_LABEL_300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lp.selectedYear == null ? '전체' : '${lp.selectedYear}',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showCategoryPicker(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GRAYSCALE_LABEL_300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCategory,
                      style: GoogleFonts.blackHanSans(
                        fontSize: 18,
                        color: GRAYSCALE_LABEL_600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: GRAYSCALE_LABEL_600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Consumer2<IntutionRecordListProvider, TeamProvider>(
        builder: (context, lp, tp, child) {
          if (lp.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: tp.selectedTeam?.color ?? BUTTON,
              ),
            );
          }

          final records = lp.records;
          if (records.isEmpty) {
            return Center(
              child: Text(
                '분석할 기록이 없습니다.',
                style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 16),
              ),
            );
          }
          return _buildAnalysisView(records, tp.selectedTeam?.color);
        },
      ),
    );
  }

  Widget _buildAnalysisView(
    List<Map<String, dynamic>> records,
    Color? teamColor,
  ) {
    switch (_selectedCategory) {
      case '상대별':
        return _OpponentAnalysis(records: records, teamColor: teamColor);
      case '구장별':
        return _StadiumAnalysis(records: records, teamColor: teamColor);
      case '요일별':
        return _DayOfWeekAnalysis(records: records, teamColor: teamColor);
      case '홈/원정':
        return _HomeAwayAnalysis(records: records, teamColor: teamColor);
      default:
        return _OpponentAnalysis(records: records, teamColor: teamColor);
    }
  }
}

// 상대별 분석
class _OpponentAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color? teamColor;

  const _OpponentAnalysis({required this.records, this.teamColor});

  @override
  Widget build(BuildContext context) {
    // 상대팀별로 그룹화
    final Map<String, _Stats> opponentStats = {};

    for (final record in records) {
      final opponent = record['oppTeam'] ?? '알수없음';
      final myScore = _parseScore(record['myScore']);
      final oppScore = _parseScore(record['opponentScore']);

      if (!opponentStats.containsKey(opponent)) {
        opponentStats[opponent] = _Stats();
      }

      opponentStats[opponent]!.total++;
      if (myScore != null && oppScore != null) {
        if (myScore > oppScore) {
          opponentStats[opponent]!.wins++;
        } else if (myScore < oppScore) {
          opponentStats[opponent]!.losses++;
        } else {
          opponentStats[opponent]!.draws++;
        }
      }
    }

    // 경기 수 많은 순으로 정렬
    final sortedOpponents = opponentStats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedOpponents.length,
      itemBuilder: (context, index) {
        final entry = sortedOpponents[index];
        final opponent = entry.key;
        final stats = entry.value;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;

        return _StatCard(
          title: opponent,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
        );
      },
    );
  }

  int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
}

// 구장별 분석
class _StadiumAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color? teamColor;

  const _StadiumAnalysis({required this.records, this.teamColor});

  @override
  Widget build(BuildContext context) {
    // 구장별로 그룹화
    final Map<String, _Stats> stadiumStats = {};

    for (final record in records) {
      final stadium = record['stadium'] ?? '알수없음';
      final myScore = _parseScore(record['myScore']);
      final oppScore = _parseScore(record['opponentScore']);

      if (!stadiumStats.containsKey(stadium)) {
        stadiumStats[stadium] = _Stats();
      }

      stadiumStats[stadium]!.total++;
      if (myScore != null && oppScore != null) {
        if (myScore > oppScore) {
          stadiumStats[stadium]!.wins++;
        } else if (myScore < oppScore) {
          stadiumStats[stadium]!.losses++;
        } else {
          stadiumStats[stadium]!.draws++;
        }
      }
    }

    // 경기 수 많은 순으로 정렬
    final sortedStadiums = stadiumStats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedStadiums.length,
      itemBuilder: (context, index) {
        final entry = sortedStadiums[index];
        final stadium = entry.key;
        final stats = entry.value;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;

        return _StatCard(
          title: stadium,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
        );
      },
    );
  }

  int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
}

// 요일별 분석
class _DayOfWeekAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color? teamColor;
  const _DayOfWeekAnalysis({required this.records, this.teamColor});

  @override
  Widget build(BuildContext context) {
    // 요일별로 그룹화
    final Map<String, _Stats> dayStats = {
      '월요일': _Stats(),
      '화요일': _Stats(),
      '수요일': _Stats(),
      '목요일': _Stats(),
      '금요일': _Stats(),
      '토요일': _Stats(),
      '일요일': _Stats(),
    };

    final dayNames = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

    for (final record in records) {
      final date = record['date'];
      if (date == null) continue;

      DateTime? dateTime;

      // Timestamp 타입 처리
      if (date is Timestamp) {
        dateTime = date.toDate();
      }
      // DateTime 타입 처리
      else if (date is DateTime) {
        dateTime = date;
      }
      // String 타입 처리 (예: "2024-12-04" 또는 "2024.12.04")
      else if (date is String) {
        try {
          // 점(.)을 하이픈(-)으로 변환하여 파싱
          final normalizedDate = date.replaceAll('.', '-');
          dateTime = DateTime.parse(normalizedDate);
        } catch (e) {
          print('날짜 파싱 실패: $date, 에러: $e');
          continue;
        }
      }

      if (dateTime == null) {
        print('날짜를 처리할 수 없습니다: $date (타입: ${date.runtimeType})');
        continue;
      }

      final dayOfWeek = dayNames[dateTime.weekday - 1];
      final myScore = _parseScore(record['myScore']);
      final oppScore = _parseScore(record['opponentScore']);

      dayStats[dayOfWeek]!.total++;
      if (myScore != null && oppScore != null) {
        if (myScore > oppScore) {
          dayStats[dayOfWeek]!.wins++;
        } else if (myScore < oppScore) {
          dayStats[dayOfWeek]!.losses++;
        } else {
          dayStats[dayOfWeek]!.draws++;
        }
      }
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: dayNames.length,
      itemBuilder: (context, index) {
        final day = dayNames[index];
        final stats = dayStats[day]!;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;

        return _StatCard(
          title: day,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
          showEmptyCard: true,
        );
      },
    );
  }

  int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
}

// 홈/원정분석
class _HomeAwayAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color? teamColor;
  const _HomeAwayAnalysis({required this.records, this.teamColor});

  @override
  Widget build(BuildContext context) {
    // 홈 /원정별로 그룹화
    final Map<String, _Stats> homeAwayStats = {'홈': _Stats(), '원정': _Stats()};

    for (final record in records) {
      // homeTeam과 myTeam을 비교해서 홈/원정 판단
      final homeTeam = record['homeTeam'] ?? '';
      final myTeam = record['myTeam'] ?? '';
      final isHome = homeTeam == myTeam;
      final key = isHome ? '홈' : '원정';
      final myScore = _parseScore(record['myScore']);
      final oppScore = _parseScore(record['opponentScore']);

      homeAwayStats[key]!.total++;
      if (myScore != null && oppScore != null) {
        if (myScore > oppScore) {
          homeAwayStats[key]!.wins++;
        } else if (myScore < oppScore) {
          homeAwayStats[key]!.losses++;
        } else {
          homeAwayStats[key]!.draws++;
        }
      }
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (context, index) {
        final key = index == 0 ? '홈' : '원정';
        final stats = homeAwayStats[key]!;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;

        return _StatCard(
          title: key,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
          showEmptyCard: true,
          isLarge: true, // 홈/ 원정은 큰 카드로 표시
        );
      },
    );
  }

  int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
}

// 통계 데이터 클래스
class _Stats {
  int total = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;
}

// 통계 카드 위젯
class _StatCard extends StatelessWidget {
  final String title;
  final _Stats stats;
  final double winRate;
  final Color? teamColor;
  final bool showEmptyCard;
  final bool isLarge;
  const _StatCard({
    required this.title,
    required this.stats,
    required this.winRate,
    this.teamColor,
    this.showEmptyCard = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();

    // title(팀 이름)로 해당 팀의 색상 찾기
    final titleTeam = teamProvider.findTeamByName(title);
    final titleColor = titleTeam?.color ?? teamColor ?? BLACK;

    // 경기가 없으면 표시 안함 (showEmptyCard가 true가 아닌 경우)
    if (stats.total == 0 && !showEmptyCard) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isLarge ? 24 : 16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.blackHanSans(
                  fontSize: isLarge ? 24 : 20,
                  color: titleColor,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (teamColor ?? BUTTON).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stats.total}경기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: teamColor ?? BUTTON,
                  ),
                ),
              ),
            ],
          ),
          if (stats.total > 0) ...[
            SizedBox(height: 16),
            // 승률 바
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '승률',
                        style: TextStyle(
                          fontSize: 12,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${winRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.bebasNeue(
                          fontSize: isLarge ? 36 : 28,
                          color: teamColor ?? BUTTON,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // 승무패 상세
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('승', stats.wins, Colors.blue),
                _buildStatItem('무', stats.draws, GRAYSCALE_LABEL_600),
                _buildStatItem('패', stats.losses, Colors.red),
              ],
            ),
          ] else ...[
            SizedBox(height: 8),
            Text(
              '기록 없음',
              style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500)),
        SizedBox(height: 4),
        Text(
          '$value',
          style: GoogleFonts.bebasNeue(
            fontSize: 24,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
