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
  final NumberFormat _currencyFormat = NumberFormat('#,###');

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
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              '직관 분석',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: BLACK,
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
                      color: WHITE,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GRAYSCALE_LABEL_300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lp.selectedYear == null
                              ? '전체'
                              : '${lp.selectedYear}년',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: BLACK,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
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
              _buildSummaryHeader(records, teamColor),
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

  Widget _buildSummaryHeader(
    List<Map<String, dynamic>> records,
    Color teamColor,
  ) {
    int total = records.length;
    int wins = 0;
    int losses = 0;
    int draws = 0;
    int totalSpent = 0;
    final Map<String, _Stats> seatGradeStats = {};
    final Map<String, String> seatGradeLabels = {};

    for (final r in records) {
      final my = _parseScore(r['myScore']) ?? 0;
      final opp = _parseScore(r['opponentScore']) ?? 0;
      final rawSeat = (r['seat'] as String?)?.trim();

      if (rawSeat != null && rawSeat.isNotEmpty) {
        final grade = extractSeatGrade(rawSeat);
        if (grade.isNotEmpty) {
          final key = normalizeSeatGradeKey(grade);
          seatGradeLabels.putIfAbsent(key, () => grade);
          final st = seatGradeStats.putIfAbsent(key, () => _Stats());
          st.total++;
          if (my > opp) {
            st.wins++;
          } else if (my < opp) {
            st.losses++;
          } else {
            st.draws++;
          }
        }
      }

      if (my > opp) {
        wins++;
      } else if (my < opp) {
        losses++;
      } else {
        draws++;
      }

      final price = r['ticketPrice'] is int
          ? r['ticketPrice'] as int
          : int.tryParse('${r['ticketPrice']}') ?? 0;
      totalSpent += price;
    }

    final winRate = total > 0 ? (wins / total * 100).toStringAsFixed(0) : '0';
    String bestSeat = '-';
    _Stats? bestSeatStat;

    final winningSeats = seatGradeStats.entries
        .where((e) => isBestSeatCandidate(e.value))
        .toList();
    if (winningSeats.isNotEmpty) {
      winningSeats.sort((a, b) => compareSeatStats(a.value, b.value));
      final bestKey = winningSeats.first.key;
      bestSeat = seatGradeLabels[bestKey] ?? bestKey;
      bestSeatStat = winningSeats.first.value;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildKpiItem('총 직관', '$total경기', teamColor)),
              Expanded(
                child: _buildKpiItem(
                  '총 승·무·패',
                  '$wins승 $draws무 $losses패',
                  teamColor,
                ),
              ),
              Expanded(child: _buildKpiItem('직관 승률', '$winRate%', teamColor)),
              Expanded(
                child: _buildKpiItem(
                  '총 티켓비용',
                  totalSpent > 0
                      ? '${_currencyFormat.format(totalSpent)}원'
                      : '-',
                  teamColor,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              const Text(
                '나의 승리 명당 좌석: ',
                style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_600),
              ),
              Expanded(
                child: Text(
                  bestSeat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: teamColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bestSeatStat != null
                    ? '${bestSeatStat.wins}승 ${bestSeatStat.draws}무 ${bestSeatStat.losses}패'
                    : '-',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: GRAYSCALE_LABEL_500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.bebasNeue(
                fontSize: 21,
                color: color,
                fontWeight: FontWeight.bold,
              ),
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
            backgroundColor: WHITE,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? WHITE : GRAYSCALE_LABEL_600,
            ),
            side: BorderSide(
              color: isSelected ? teamColor : GRAYSCALE_LABEL_300,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final key = entry.key;
        final stats = entry.value;
        final label = seatLabels[key] ?? key;
        final details = List<_SeatDetailItem>.from(seatDetails[key] ?? [])
          ..sort((a, b) => b.date.compareTo(a.date));
        final isBest =
            index == 0 && _AnalysisPageState.isBestSeatCandidate(stats);
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
          color: WHITE,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: BLACK.withOpacity(0.04),
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: BLACK,
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: GRAYSCALE_LABEL_600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: GRAYSCALE_LABEL_500,
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
                    color: teamColor,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '승률',
                  style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                ),
                const Spacer(),
                Text(
                  '${stats.wins}승  ${stats.draws}무  ${stats.losses}패',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BLACK,
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
      final gameTotal = ticketPrice + foodCost;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StadiumReceiptCard(
          records: records,
          selectedYear: selectedYear,
          wins: winCount,
          losses: lossCount,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricBox(
                '총 지출액',
                '${format.format(totalCost)}원',
                teamColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricBox(
                '경기당 평균',
                '${format.format(avgCost)}원',
                GRAYSCALE_LABEL_600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WHITE,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GRAYSCALE_LABEL_300),
          ),
          child: Row(
            children: [
              const Icon(Icons.military_tech, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1승을 보기 위해 쓴 비용 (가성비 지수)',
                      style: TextStyle(
                        fontSize: 12,
                        color: GRAYSCALE_LABEL_600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      winCount > 0
                          ? '평균 ${format.format(costPerWin)}원'
                          : '아직 직관 승리가 없습니다 😭',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        color: BLACK,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '🏟️ 구장별 지출 랭킹',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BLACK,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedStadiums.map((entry) {
          final percent = totalCost > 0 ? (entry.value / totalCost) : 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${format.format(entry.value)}원 (${(percent * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: teamColor,
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

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [기존 뷰 비주얼 개선] 상대별 / 구장별 / 요일별 / 홈원정
// -----------------------------------------------------------------------------
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
      statsMap.putIfAbsent(opp, () => _Stats());
      statsMap[opp]!.total++;
      if (my != null && oppScore != null) {
        if (my > oppScore)
          statsMap[opp]!.wins++;
        else if (my < oppScore)
          statsMap[opp]!.losses++;
        else
          statsMap[opp]!.draws++;
      }
    }
    final sorted = statsMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final e = sorted[i];
        final winRate = e.value.total > 0
            ? (e.value.wins / e.value.total * 100)
            : 0.0;
        return _ModernStatCard(
          title: e.key,
          stats: e.value,
          winRate: winRate,
          teamColor: teamColor,
        );
      },
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
      statsMap.putIfAbsent(stadium, () => _Stats());
      statsMap[stadium]!.total++;
      if (my != null && opp != null) {
        if (my > opp)
          statsMap[stadium]!.wins++;
        else if (my < opp)
          statsMap[stadium]!.losses++;
        else
          statsMap[stadium]!.draws++;
      }
    }
    final sorted = statsMap.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final e = sorted[i];
        final winRate = e.value.total > 0
            ? (e.value.wins / e.value.total * 100)
            : 0.0;
        return _ModernStatCard(
          title: e.key,
          stats: e.value,
          winRate: winRate,
          teamColor: teamColor,
        );
      },
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
      statsMap[dayName]!.total++;
      if (my != null && opp != null) {
        if (my > opp)
          statsMap[dayName]!.wins++;
        else if (my < opp)
          statsMap[dayName]!.losses++;
        else
          statsMap[dayName]!.draws++;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final d = days[i];
        final stats = statsMap[d]!;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;
        return _ModernStatCard(
          title: d,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
          showEmpty: true,
        );
      },
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
      statsMap[key]!.total++;
      if (my != null && opp != null) {
        if (my > opp)
          statsMap[key]!.wins++;
        else if (my < opp)
          statsMap[key]!.losses++;
        else
          statsMap[key]!.draws++;
      }
    }

    final keys = ['홈 경기', '원정 경기'];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2,
      itemBuilder: (context, i) {
        final k = keys[i];
        final stats = statsMap[k]!;
        final winRate = stats.total > 0
            ? (stats.wins / stats.total * 100)
            : 0.0;
        return _ModernStatCard(
          title: k,
          stats: stats,
          winRate: winRate,
          teamColor: teamColor,
          showEmpty: true,
        );
      },
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
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(0.04),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: BLACK,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: GRAYSCALE_LABEL_600,
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
                  color: teamColor,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '승률',
                style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
              ),
              const Spacer(),
              Text(
                '${stats.wins}승  ${stats.draws}무  ${stats.losses}패',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BLACK,
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
