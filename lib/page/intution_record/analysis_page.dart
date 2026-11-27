import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/stadium_receipt_card.dart';
import 'package:provider/provider.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _selectedCategory = '좌석별';
  final List<String> _categories = ['좌석별', '지출분석', '상대별', '구장별', '요일별', '홈/원정'];

  void _showYearPicker(BuildContext context, IntutionRecordListProvider irp) {
    final years = irp.availableYears;
    if (years.isEmpty) years.add(DateTime.now().year);
    final allYears = [null, ...years];
    int selectedIndex = allYears.indexOf(irp.selectedYear);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: CupertinoPicker(
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
                  year == null ? '전체 시즌' : '$year년',
                  style: const TextStyle(fontSize: 18),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            Text(
              '직관 분석',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Consumer<IntutionRecordListProvider>(
              builder: (context, lp, child) {
                return GestureDetector(
                  onTap: () => _showYearPicker(context, lp),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lp.selectedYear == null
                              ? '전체'
                              : '${lp.selectedYear}년',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: context.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Consumer<IntutionRecordListProvider>(
        builder: (context, lp, child) {
          if (lp.isLoading) {
            return Center(child: CircularProgressIndicator(color: teamColor));
          }

          final records = lp.records;
          if (records.isEmpty) {
            return const Center(
              child: Text(
                '분석할 직관 기록이 없습니다.',
                style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 16),
              ),
            );
          }

          return Column(
            children: [
              _buildSeasonMiniStrip(records, lp.selectedYear, teamColor),
              _buildCategoryTabBar(teamColor),
              Expanded(child: _buildCurrentView(records, teamColor)),
            ],
          );
        },
      ),
    );
  }

  /// 좌석 전체 문자열에서 블럭/구역/열/번 등 상세 위치를 제외한 '좌석 등급명'만 추출
  /// 예: "1루 네이비석 306블럭 3열 39번" -> "1루 네이비석"
  /// 예: "블루석 108블록 5열 12번" -> "블루석"
  static String extractSeatGrade(String rawSeat) {
    var s = rawSeat.trim();
    if (s.isEmpty) return s;

    // 1) 상세 위치 토큰(블럭/블록/구역/섹션/열/번/호/매 및 OCR 변형)부터 끝까지 제거
    // ※ 주의: Dart RegExp의 \b는 한글 뒤에서 매칭되지 않으므로 사용하지 않음
    final detailPattern = RegExp(
      r'(?:^|[\s,\-/]+)(?:제?\s*)?(?:[0-9]+|[A-Za-z]{1,2})\s*(?:블럭|블록|불럭|블력|볼럭|블랙|구역|구억|구여|섹션|열|일|얼|엘|번|빈|변|호|매)(?=\s|$|[0-9가-힣A-Za-z]).*',
      caseSensitive: false,
    );
    final attachedDetailPattern = RegExp(
      r'(?<=[가-힣])(?:[0-9]+|[A-Za-z]{1,2})\s*(?:블럭|블록|불럭|블력|볼럭|블랙|구역|구억|구여|섹션|열|일|얼|엘|번|빈|변|호|매)(?=\s|$|[0-9가-힣A-Za-z]).*',
      caseSensitive: false,
    );

    final withoutAllDetails = s
        .replaceAll(detailPattern, '')
        .replaceAll(attachedDetailPattern, '')
        .trim();

    if (withoutAllDetails.isNotEmpty) {
      s = withoutAllDetails;
    } else {
      // 등급명 없이 "306블럭 3열 39번"처럼 적힌 경우 열/번만 제거하고 "306블럭" 유지
      final withoutRowNum = s
          .replaceAll(
            RegExp(
              r'(?:[\s,\-/]+)(?:[0-9]+|[A-Za-z]{1,2})\s*(?:열|일|얼|엘|번|빈|변|호|매)(?=\s|$|[0-9가-힣A-Za-z]).*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      if (withoutRowNum.isNotEmpty) {
        s = withoutRowNum;
      }
    }

    // 2) "~석/~존/~박스/~라운지/~테라스/~데크/~클럽" 뒤에 남은 숫자나 부가 텍스트가 있으면 등급명까지만 추출
    final gradeSuffixMatch = RegExp(
      r'^(.+?(?:석|존|박스|라운지|테라스|데크|클럽))(?:\s+[0-9A-Za-z\-]+.*)?$',
      caseSensitive: false,
    ).firstMatch(s);
    if (gradeSuffixMatch != null) {
      s = gradeSuffixMatch.group(1)!.trim();
    }

    // 3) "1루네이비석", "1루측 네이비석" -> "1루 네이비석" 형태로 띄어쓰기 정규화
    s = s.replaceFirstMapped(
      RegExp(r'^([13]루)(?:측|쪽)?\s*(?=[가-힣A-Za-z])'),
      (m) => '${m.group(1)} ',
    );

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 띄어쓰기 차이("1루네이비석" vs "1루 네이비석")에 영향받지 않는 그룹핑 키
  static String normalizeSeatGradeKey(String grade) {
    return grade.replaceAll(' ', '').toUpperCase();
  }

  /// 승리 명당 좌석 후보 자격: 최소 1승 이상 & 패배보다 승리가 많거나 같음 (승률 50% 이상)
  static bool isBestSeatCandidate(_Stats s) {
    return s.wins > 0 && s.wins >= s.losses;
  }

  /// 좌석별 순위 정렬 기준:
  /// 1순위: 명당 후보 여부 (승 >= 패 & 1승 이상)
  /// 2순위: 다승 (승리 횟수가 많은 순)
  /// 3순위: 승률 높은 순
  /// 4순위: 패배 적은 순 -> 총 경기 수 많은 순
  static int compareSeatStats(_Stats a, _Stats b) {
    final candA = isBestSeatCandidate(a) ? 1 : 0;
    final candB = isBestSeatCandidate(b) ? 1 : 0;
    if (candA != candB) return candB.compareTo(candA);

    final winCmp = b.wins.compareTo(a.wins);
    if (winCmp != 0) return winCmp;

    final rateA = a.total > 0 ? a.wins / a.total : 0.0;
    final rateB = b.total > 0 ? b.wins / b.total : 0.0;
    final rateCmp = rateB.compareTo(rateA);
    if (rateCmp != 0) return rateCmp;

    final lossCmp = a.losses.compareTo(b.losses);
    if (lossCmp != 0) return lossCmp;

    return b.total.compareTo(a.total);
  }

  Widget _buildSeasonMiniStrip(
    List<Map<String, dynamic>> records,
    int? selectedYear,
    Color teamColor,
  ) {
    final int total = records.length;
    int wins = 0;
    int losses = 0;
    int draws = 0;

    for (final r in records) {
      final my = _parseScore(r['myScore']);
      final opp = _parseScore(r['opponentScore']);
      if (my == null || opp == null) continue;
      if (my > opp) {
        wins++;
      } else if (my < opp) {
        losses++;
      } else {
        draws++;
      }
    }

    final winRate = total > 0 ? (wins / total * 100).toStringAsFixed(0) : '0';
    final seasonTitle = selectedYear != null ? '$selectedYear 직관 ' : '통산 직관 ';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
                children: [
                  TextSpan(text: '🏟️ $seasonTitle'),
                  TextSpan(
                    text: '$total경기',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                    ),
                  ),
                  TextSpan(text: ' · $wins승 $draws무 $losses패'),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '승률 $winRate%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: context.readableColor(teamColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabBar(Color teamColor) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            selectedColor: teamColor,
            checkmarkColor: WHITE,
            backgroundColor: context.cardColor,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? WHITE : context.textSecondary,
            ),
            side: BorderSide(
              color: isSelected ? teamColor : context.borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (val) {
              if (val) setState(() => _selectedCategory = cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildCurrentView(
    List<Map<String, dynamic>> records,
    Color teamColor,
  ) {
    switch (_selectedCategory) {
      case '좌석별':
        return _SeatAnalysis(records: records, teamColor: teamColor);
      case '지출분석':
        return _CostAnalysis(records: records, teamColor: teamColor);
      case '상대별':
        return _OpponentAnalysis(records: records, teamColor: teamColor);
      case '구장별':
        return _StadiumAnalysis(records: records, teamColor: teamColor);
      case '요일별':
        return _DayOfWeekAnalysis(records: records, teamColor: teamColor);
      case '홈/원정':
        return _HomeAwayAnalysis(records: records, teamColor: teamColor);
      default:
        return _SeatAnalysis(records: records, teamColor: teamColor);
    }
  }

  static int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
}

// -----------------------------------------------------------------------------
// [좌석별 분석] 좌석 등급명으로 그룹화 + 탭 시 상세 좌석 드롭다운 표시
// -----------------------------------------------------------------------------
class _SeatDetailItem {
  final String fullSeat;
  final String date;
  final String oppTeam;
  final int? myScore;
  final int? oppScore;

  const _SeatDetailItem({
    required this.fullSeat,
    required this.date,
    required this.oppTeam,
    this.myScore,
    this.oppScore,
  });
}

class _SeatAnalysis extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;

  const _SeatAnalysis({required this.records, required this.teamColor});

  @override
  State<_SeatAnalysis> createState() => _SeatAnalysisState();
}

class _SeatAnalysisState extends State<_SeatAnalysis> {
  final Set<String> _expandedKeys = {};

  @override
  Widget build(BuildContext context) {
    final Map<String, _Stats> seatStats = {};
    final Map<String, String> seatLabels = {};
    final Map<String, List<_SeatDetailItem>> seatDetails = {};

    for (final r in widget.records) {
      final rawSeat = (r['seat'] as String?)?.trim();
      if (rawSeat == null || rawSeat.isEmpty) continue; // 좌석 정보 없는 기록 제외

      final grade = _AnalysisPageState.extractSeatGrade(rawSeat);
      if (grade.isEmpty) continue;
      final key = _AnalysisPageState.normalizeSeatGradeKey(grade);

      seatLabels.putIfAbsent(key, () => grade);
      seatStats.putIfAbsent(key, () => _Stats());
      seatDetails.putIfAbsent(key, () => []);

      final my = _AnalysisPageState._parseScore(r['myScore']);
      final opp = _AnalysisPageState._parseScore(r['opponentScore']);

      seatStats[key]!.total++;

      if (my != null && opp != null) {
        if (my > opp) {
          seatStats[key]!.wins++;
        } else if (my < opp) {
          seatStats[key]!.losses++;
        } else {
          seatStats[key]!.draws++;
        }
      }

      seatDetails[key]!.add(
        _SeatDetailItem(
          fullSeat: rawSeat,
          date: (r['date'] as String?) ?? '',
          oppTeam: (r['oppTeam'] as String?) ?? '',
          myScore: my,
          oppScore: opp,
        ),
      );
    }

    if (seatStats.isEmpty) {
      return const Center(
        child: Text(
          '좌석이 기록된 경기가 없습니다.\n티켓 스캔으로 좌석을 기록해보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
        ),
      );
    }

    // 명당 후보(승 >= 패) & 다승 우선 -> 동률 시 승률 높은 순서대로 정렬
    final sorted = seatStats.entries.toList()
      ..sort((a, b) => _AnalysisPageState.compareSeatStats(a.value, b.value));

    final topEntry = sorted.first;
    final topLabel = seatLabels[topEntry.key] ?? topEntry.key;
    final topStats = topEntry.value;
    final topHasBest = _AnalysisPageState.isBestSeatCandidate(topStats);
    final topWinRate = topStats.total > 0
        ? (topStats.wins / topStats.total * 100).toStringAsFixed(0)
        : '0';

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: sorted.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AnalysisHeroCard(
                teamColor: widget.teamColor,
                eyebrow: topHasBest ? '🏆 내 승리 명당 좌석 1위' : '🪑 가장 자주 찾은 좌석',
                title: topLabel,
                subtitle:
                    '${topStats.total}경기 ${topStats.wins}승 ${topStats.draws}무 ${topStats.losses}패',
                badgeLabel: '승률',
                badgeValue: '$topWinRate%',
              ),
              _AnalysisSectionHeader(
                title: '좌석 등급별 승률',
                trailing: '총 ${sorted.length}개 등급',
              ),
            ],
          );
        }

        final entry = sorted[index - 1];
        final key = entry.key;
        final stats = entry.value;
        final label = seatLabels[key] ?? key;
        final details = List<_SeatDetailItem>.from(seatDetails[key] ?? [])
          ..sort((a, b) => b.date.compareTo(a.date));
        final isBest =
            index == 1 && _AnalysisPageState.isBestSeatCandidate(stats);
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;
        final isExpanded = _expandedKeys.contains(key);

        return _buildExpandableSeatCard(
          keyStr: key,
          title: label,
          badgeText: isBest ? '🥇 승리 요정 명당' : null,
          stats: stats,
          winRate: winRate,
          details: details,
          isExpanded: isExpanded,
        );
      },
    );
  }

  Widget _buildExpandableSeatCard({
    required String keyStr,
    required String title,
    String? badgeText,
    required _Stats stats,
    required double winRate,
    required List<_SeatDetailItem> details,
    required bool isExpanded,
  }) {
    final teamColor = widget.teamColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedKeys.remove(keyStr);
          } else {
            _expandedKeys.add(keyStr);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: context.isDarkMode
              ? Border.all(color: context.borderColor)
              : null,
          boxShadow: [
            BoxShadow(
              color: BLACK.withOpacity(context.isDarkMode ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${stats.total}경기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${winRate.toStringAsFixed(0)}%',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.readableColor(teamColor),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '승률',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
                const Spacer(),
                Text(
                  '${stats.wins}승  ${stats.draws}무  ${stats.losses}패',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (stats.total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (stats.wins > 0)
                        Expanded(
                          flex: stats.wins,
                          child: Container(color: Colors.blue),
                        ),
                      if (stats.draws > 0)
                        Expanded(
                          flex: stats.draws,
                          child: Container(color: GRAYSCALE_LABEL_400),
                        ),
                      if (stats.losses > 0)
                        Expanded(
                          flex: stats.losses,
                          child: Container(color: Colors.redAccent),
                        ),
                    ],
                  ),
                ),
              ),
            if (isExpanded && details.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: GRAYSCALE_LABEL_200),
              const SizedBox(height: 10),
              ...details.map((d) {
                String resultLabel = '무';
                Color resultColor = GRAYSCALE_LABEL_500;
                if (d.myScore != null && d.oppScore != null) {
                  if (d.myScore! > d.oppScore!) {
                    resultLabel = '승';
                    resultColor = Colors.blue;
                  } else if (d.myScore! < d.oppScore!) {
                    resultLabel = '패';
                    resultColor = Colors.redAccent;
                  }
                }
                final metaParts = <String>[
                  if (d.date.isNotEmpty) d.date,
                  if (d.oppTeam.isNotEmpty) 'vs ${d.oppTeam}',
                ];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_seat_outlined,
                        size: 15,
                        color: GRAYSCALE_LABEL_500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.fullSeat,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BLACK,
                              ),
                            ),
                            if (metaParts.isNotEmpty)
                              Text(
                                metaParts.join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          d.myScore != null && d.oppScore != null
                              ? '${d.myScore}:${d.oppScore} $resultLabel'
                              : resultLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: resultColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [지출 분석]
// -----------------------------------------------------------------------------
class _CostAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;

  const _CostAnalysis({required this.records, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###');
    final selectedYear = context
        .watch<IntutionRecordListProvider>()
        .selectedYear;
    int totalCost = 0;
    int costRecordCount = 0;
    int winCount = 0;
    int lossCount = 0;
    final Map<String, int> stadiumCost = {};

    for (final r in records) {
      final ticketPrice = r['ticketPrice'] is int
          ? r['ticketPrice'] as int
          : int.tryParse('${r['ticketPrice']}') ?? 0;
      final foodCost = r['foodCost'] is int
          ? r['foodCost'] as int
          : int.tryParse('${r['foodCost']}') ?? 0;
      final goodsCost = r['goodsCost'] is int
          ? r['goodsCost'] as int
          : int.tryParse('${r['goodsCost']}') ?? 0;
      final gameTotal = ticketPrice + foodCost + goodsCost;
      if (gameTotal > 0) {
        totalCost += gameTotal;
        costRecordCount++;

        final stadium = r['stadium'] ?? '기타 구장';
        stadiumCost[stadium] = (stadiumCost[stadium] ?? 0) + gameTotal;
      }

      final my = _AnalysisPageState._parseScore(r['myScore']) ?? 0;
      final opp = _AnalysisPageState._parseScore(r['opponentScore']) ?? 0;
      if (my > opp) {
        winCount++;
      } else if (my < opp) {
        lossCount++;
      }
    }

    if (costRecordCount == 0) {
      return const Center(
        child: Text(
          '티켓 가격이나 먹거리 비용이 기록된 경기가 없습니다.\n직관 기록 시 티켓·먹거리 비용을 입력해보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
        ),
      );
    }

    final avgCost = totalCost ~/ costRecordCount;
    final costPerWin = winCount > 0 ? (totalCost ~/ winCount) : 0;
    final sortedStadiums = stadiumCost.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final seasonLabel = selectedYear != null ? '$selectedYear년' : '통산';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        _AnalysisHeroCard(
          teamColor: teamColor,
          eyebrow: '💸 $seasonLabel 직관 총 투자금',
          title: '${format.format(totalCost)}원',
          subtitle: '티켓 + 먹거리 + 유니폼·굿즈 · 경기당 평균 ${format.format(avgCost)}원',
          badgeLabel: '1승당 가성비',
          badgeValue: winCount > 0 ? '${format.format(costPerWin)}원' : '첫 승 대기',
        ),
        StadiumReceiptCard(
          records: records,
          selectedYear: selectedYear,
          wins: winCount,
          losses: lossCount,
        ),
        const SizedBox(height: 16),
        Text(
          '🏟️ 구장별 지출 랭킹',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedStadiums.map((entry) {
          final percent = totalCost > 0 ? (entry.value / totalCost) : 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: context.isDarkMode
                  ? Border.all(color: context.borderColor)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      '${format.format(entry.value)}원 (${(percent * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.readableColor(teamColor),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: GRAYSCALE_LABEL_300.withOpacity(0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(teamColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// [리뉴얼 뷰] 상대별 / 구장별 / 요일별 / 홈원정 + 공용 히어로/섹션 위젯
// -----------------------------------------------------------------------------
/// 최소 2경기 이상 치른 항목 중 최고/최저 승률(평균) 항목을 우선 선정하고,
/// 2경기 이상인 항목이 없으면 전체 중 선정한다.
MapEntry<String, _Stats>? _pickWinRateExtreme(
  Map<String, _Stats> statsMap, {
  required bool highest,
  String? excludeKey,
}) {
  final played = statsMap.entries
      .where((e) => e.value.total > 0 && e.key != excludeKey)
      .toList();
  if (played.isEmpty) return null;

  final multiGame = played.where((e) => e.value.total >= 2).toList();
  final candidates = multiGame.isNotEmpty ? multiGame : played;

  candidates.sort((a, b) {
    final rateCmp = highest
        ? b.value.winRate.compareTo(a.value.winRate)
        : a.value.winRate.compareTo(b.value.winRate);
    if (rateCmp != 0) return rateCmp;

    final countCmp = highest
        ? b.value.wins.compareTo(a.value.wins)
        : b.value.losses.compareTo(a.value.losses);
    if (countCmp != 0) return countCmp;

    return b.value.total.compareTo(a.value.total);
  });
  return candidates.first;
}

class _OpponentAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;
  const _OpponentAnalysis({required this.records, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final Map<String, _Stats> statsMap = {};
    for (final r in records) {
      final opp = r['oppTeam'] ?? '기타';
      final my = _AnalysisPageState._parseScore(r['myScore']);
      final oppScore = _AnalysisPageState._parseScore(r['opponentScore']);
      statsMap.putIfAbsent(opp, () => _Stats()).addResult(my, oppScore);
    }
    final sorted = statsMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final best = _pickWinRateExtreme(statsMap, highest: true);
    final worst = _pickWinRateExtreme(
      statsMap,
      highest: false,
      excludeKey: best?.key,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        if (best != null) ...[
          Row(
            children: [
              Expanded(
                child: _AnalysisMiniHeroCard(
                  eyebrow: '🔥 최강 상대',
                  title: best.key,
                  subText:
                      '${best.value.total}전 ${best.value.wins}승 ${best.value.losses}패 (${best.value.winRate.toStringAsFixed(0)}%)',
                  accentColor: teamColor,
                ),
              ),
              if (worst != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _AnalysisMiniHeroCard(
                    eyebrow: '🧊 주의 상대',
                    title: worst.key,
                    subText:
                        '${worst.value.total}전 ${worst.value.wins}승 ${worst.value.losses}패 (${worst.value.winRate.toStringAsFixed(0)}%)',
                    accentColor: ACCENT_CORAL,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
        ],
        _AnalysisSectionHeader(
          title: '상대 팀별 전적',
          trailing: '${sorted.length}개 팀',
        ),
        ...sorted.map((e) {
          return _ModernStatCard(
            title: e.key,
            badgeText: best != null && e.key == best.key ? '강세' : null,
            stats: e.value,
            winRate: e.value.winRate,
            teamColor: teamColor,
          );
        }),
      ],
    );
  }
}

class _StadiumAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;
  const _StadiumAnalysis({required this.records, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final Map<String, _Stats> statsMap = {};
    for (final r in records) {
      final stadium = r['stadium'] ?? '기타 구장';
      final my = _AnalysisPageState._parseScore(r['myScore']);
      final opp = _AnalysisPageState._parseScore(r['opponentScore']);
      statsMap.putIfAbsent(stadium, () => _Stats()).addResult(my, opp);
    }
    final sorted = statsMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final best = _pickWinRateExtreme(statsMap, highest: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        if (best != null)
          _AnalysisHeroCard(
            teamColor: teamColor,
            eyebrow: '🏟️ 최고 승률 구장',
            title: best.key,
            subtitle:
                '${best.value.total}경기 ${best.value.wins}승 ${best.value.draws}무 ${best.value.losses}패',
            badgeLabel: '승률',
            badgeValue: '${best.value.winRate.toStringAsFixed(0)}%',
          ),
        _AnalysisSectionHeader(
          title: '구장별 전적',
          trailing: '방문 ${sorted.length}개 구장',
        ),
        ...sorted.map((e) {
          return _ModernStatCard(
            title: e.key,
            badgeText: best != null && e.key == best.key ? '최고 승률' : null,
            stats: e.value,
            winRate: e.value.winRate,
            teamColor: teamColor,
          );
        }),
      ],
    );
  }
}

class _DayOfWeekAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;
  const _DayOfWeekAnalysis({required this.records, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final days = ['화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final Map<String, _Stats> statsMap = {for (var d in days) d: _Stats()};

    for (final r in records) {
      final dateStr = r['date'] as String?;
      if (dateStr == null) continue;
      final dt = DateTime.tryParse(dateStr.replaceAll('.', '-'));
      if (dt == null || dt.weekday == 1) continue;
      final dayName = days[dt.weekday - 2];

      final my = _AnalysisPageState._parseScore(r['myScore']);
      final opp = _AnalysisPageState._parseScore(r['opponentScore']);
      statsMap[dayName]!.addResult(my, opp);
    }

    final bestDay = _pickWinRateExtreme(statsMap, highest: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        if (bestDay != null)
          _AnalysisHeroCard(
            teamColor: teamColor,
            eyebrow: '📅 내 직관 승리 요일',
            title: '${bestDay.key} 직관',
            subtitle:
                '${bestDay.value.total}경기 ${bestDay.value.wins}승 ${bestDay.value.draws}무 ${bestDay.value.losses}패',
            badgeLabel: '승률',
            badgeValue: '${bestDay.value.winRate.toStringAsFixed(0)}%',
          ),
        const _AnalysisSectionHeader(title: '요일별 승률', trailing: '화~일'),
        ...days.map((d) {
          final stats = statsMap[d]!;
          return _ModernStatCard(
            title: d,
            badgeText: bestDay != null && d == bestDay.key ? '승리 요일' : null,
            stats: stats,
            winRate: stats.winRate,
            teamColor: teamColor,
            showEmpty: true,
          );
        }),
      ],
    );
  }
}

class _HomeAwayAnalysis extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Color teamColor;
  const _HomeAwayAnalysis({required this.records, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    final Map<String, _Stats> statsMap = {'홈 경기': _Stats(), '원정 경기': _Stats()};

    for (final r in records) {
      final isHome = (r['homeTeam'] ?? '') == (r['myTeam'] ?? '');
      final key = isHome ? '홈 경기' : '원정 경기';
      final my = _AnalysisPageState._parseScore(r['myScore']);
      final opp = _AnalysisPageState._parseScore(r['opponentScore']);
      statsMap[key]!.addResult(my, opp);
    }

    final homeStats = statsMap['홈 경기']!;
    final awayStats = statsMap['원정 경기']!;
    final keys = ['홈 경기', '원정 경기'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        _HomeAwayComparisonCard(
          homeStats: homeStats,
          awayStats: awayStats,
          teamColor: teamColor,
        ),
        const _AnalysisSectionHeader(title: '홈 · 원정 상세 전적'),
        ...keys.map((k) {
          final stats = statsMap[k]!;
          String? badge;
          if (homeStats.total > 0 && awayStats.total > 0) {
            if (k == '홈 경기' && homeStats.winRate > awayStats.winRate) {
              badge = '홈 강세';
            } else if (k == '원정 경기' && awayStats.winRate > homeStats.winRate) {
              badge = '원정 강세';
            }
          }
          return _ModernStatCard(
            title: k,
            badgeText: badge,
            stats: stats,
            winRate: stats.winRate,
            teamColor: teamColor,
            showEmpty: true,
          );
        }),
      ],
    );
  }
}

class _AnalysisHeroCard extends StatelessWidget {
  final Color teamColor;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final String badgeValue;

  const _AnalysisHeroCard({
    required this.teamColor,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeValue,
  });

  @override
  Widget build(BuildContext context) {
    final lighter = Color.lerp(teamColor, WHITE, 0.14) ?? teamColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [teamColor, lighter],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: WHITE.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: WHITE,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: WHITE.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: WHITE.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WHITE.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: WHITE.withValues(alpha: 0.88),
                      ),
                    ),
                    Text(
                      badgeValue,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: WHITE,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalysisMiniHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subText;
  final Color accentColor;

  const _AnalysisMiniHeroCard({
    required this.eyebrow,
    required this.title,
    required this.subText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: context.readableColor(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _AnalysisSectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: GRAYSCALE_LABEL_800,
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: GRAYSCALE_LABEL_500,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeAwayComparisonCard extends StatelessWidget {
  final _Stats homeStats;
  final _Stats awayStats;
  final Color teamColor;

  const _HomeAwayComparisonCard({
    required this.homeStats,
    required this.awayStats,
    required this.teamColor,
  });

  @override
  Widget build(BuildContext context) {
    final homeRate = homeStats.winRate;
    final awayRate = awayStats.winRate;
    final totalRate = homeRate + awayRate;
    final int homeFlex = totalRate > 0 ? homeRate.round().clamp(1, 99) : 50;
    final int awayFlex = totalRate > 0 ? awayRate.round().clamp(1, 99) : 50;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏠 홈 vs ✈️ 원정 승률 맞대결',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '총 ${homeStats.total + awayStats.total}경기',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '홈 경기 (${homeStats.total}전)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                  Text(
                    '${homeRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: teamColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '원정 경기 (${awayStats.total}전)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                  Text(
                    '${awayRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: ACCENT_CORAL,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: homeFlex,
                    child: Container(color: teamColor),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: awayFlex,
                    child: Container(color: ACCENT_CORAL),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [현대적 통계 카드]
// -----------------------------------------------------------------------------
class _Stats {
  int total = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  double get winRate => total > 0 ? (wins / total * 100) : 0.0;

  void addResult(int? my, int? opp) {
    total++;
    if (my == null || opp == null) return;
    if (my > opp) {
      wins++;
    } else if (my < opp) {
      losses++;
    } else {
      draws++;
    }
  }
}

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String? badgeText;
  final _Stats stats;
  final double winRate;
  final Color teamColor;
  final bool showEmpty;

  const _ModernStatCard({
    required this.title,
    this.badgeText,
    required this.stats,
    required this.winRate,
    required this.teamColor,
    this.showEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0 && !showEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: context.isDarkMode
            ? Border.all(color: context.borderColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(context.isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${stats.total}경기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${winRate.toStringAsFixed(0)}%',
                style: GoogleFonts.bebasNeue(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: context.readableColor(teamColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '승률',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
              const Spacer(),
              Text(
                '${stats.wins}승  ${stats.draws}무  ${stats.losses}패',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (stats.total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (stats.wins > 0)
                      Expanded(
                        flex: stats.wins,
                        child: Container(color: Colors.blue),
                      ),
                    if (stats.draws > 0)
                      Expanded(
                        flex: stats.draws,
                        child: Container(color: GRAYSCALE_LABEL_400),
                      ),
                    if (stats.losses > 0)
                      Expanded(
                        flex: stats.losses,
                        child: Container(color: Colors.redAccent),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
