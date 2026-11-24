import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/page/intution_record/_record_card.dart';
import 'package:lockerroom/page/intution_record/_ticket_stub_tile.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/page/intution_record/ticker_camera_scan_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordListPage extends StatefulWidget {
  const IntutionRecordListPage({super.key});

  @override
  State<IntutionRecordListPage> createState() => _IntutionRecordListPageState();
}

class _IntutionRecordListPageState extends State<IntutionRecordListPage> {
  bool _isTicketGridMode = true;

  // Timestamp → DateTime 변환 헬퍼
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // imageUrls 처리: 기존 단일 imageUrl과 새로운 imageUrls 모두 지원
  List<String> _parseImageUrls(Map<String, dynamic> data) {
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      return List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      // 기존 데이터 호환성: 단일 imageUrl을 리스트로 변환
      return [data['imageUrl'].toString()];
    }
    return [];
  }

  AttendanceModel _toAttendance(Map<String, dynamic> data) {
    return AttendanceModel(
      gameId: data['gameId'],
      season: data['season'],
      date: data['date'],
      time: data['time'],
      stadium: data['stadium'],
      homeTeam: data['homeTeam'],
      awayTeam: data['awayTeam'],
      myTeam: data['myTeam'],
      oppTeam: data['oppTeam'],
      myScore: data['myScore'],
      opponentScore: data['opponentScore'],
      imageUrls: _parseImageUrls(data),
      memo: data['memo'],
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      ticketPrice: data['ticketPrice'] is int
          ? data['ticketPrice'] as int
          : int.tryParse('${data['ticketPrice']}'),
      seat: data['seat'] as String?,
      seatType: data['seatType'] as String?,
      foodCost: data['foodCost'] is int
          ? data['foodCost'] as int
          : int.tryParse('${data['foodCost']}'),
      foodItems: data['foodItems'] is List
          ? List<String>.from(data['foodItems'])
          : const [],
      foodPrices: data['foodPrices'] is Map
          ? (data['foodPrices'] as Map).map(
              (k, v) => MapEntry(
                k.toString(),
                v is int ? v : int.tryParse('$v') ?? 0,
              ),
            )
          : const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()..load()),
        ChangeNotifierProvider(
          create: (_) => IntutionRecordListProvider()..subscribe(),
        ),
      ],
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        appBar: AppBar(
          backgroundColor: BACKGROUND_COLOR,
          title: const Text(
            '나의 직관기록',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: GRAYSCALE_LABEL_950,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              onPressed: () => _showAddOptionsSheet(context),
              icon: const Icon(
                Icons.add_rounded,
                size: 28,
                color: GRAYSCALE_LABEL_900,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _HeaderView(),
            const SizedBox(height: 6),
            _FilterBar(
              isTicketGridMode: _isTicketGridMode,
              onToggleViewMode: () {
                setState(() {
                  _isTicketGridMode = !_isTicketGridMode;
                });
              },
            ),
            const SizedBox(height: 6),

            // ------------------ 리스트 / 4열 티켓 그리드 ------------------
            Expanded(
              child:
                  Selector<
                    IntutionRecordListProvider,
                    List<Map<String, dynamic>>
                  >(
                    selector: (_, lp) => lp.records,
                    builder: (context, records, child) {
                      if (records.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: GRAYSCALE_LABEL_100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.sports_baseball_outlined,
                                    size: 30,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '아직 직관 기록이 없어요',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: GRAYSCALE_LABEL_900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '첫 직관의 순간을 기록해보세요!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAddOptionsSheet(context),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text(
                                    '기록 추가하기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: BUTTON,
                                    foregroundColor: WHITE,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (_isTicketGridMode) {
                        final isDescending = context
                            .select<IntutionRecordListProvider, bool>(
                              (lp) => lp.isDescending,
                            );
                        return GridView.builder(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: records.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.53,
                              ),
                          itemBuilder: (context, i) {
                            final d = records[i];
                            final attendance = _toAttendance(d);
                            final myTeam = d['myTeam'] ?? '';
                            final oppTeam = d['oppTeam'] ?? '';
                            final myScore = d['myScore'] ?? 0;
                            final oppScore = d['opponentScore'] ?? 0;
                            final isWin = myScore > oppScore;
                            final ticketNumber = isDescending
                                ? (records.length - i)
                                : (i + 1);

                            final tp = Provider.of<TeamProvider>(
                              context,
                              listen: false,
                            );
                            final team = tp.findTeamByName(myTeam);
                            final color = team?.color ?? GRAYSCALE_LABEL_500;

                            return TicketStubTile(
                              data: d,
                              attendance: attendance,
                              recordedTeam: team,
                              recordedTeamColor: color,
                              ticketNumber: ticketNumber,
                              isWin: isWin,
                              myScore: myScore,
                              oppScore: oppScore,
                              myTeam: myTeam,
                              oppTeam: oppTeam,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) =>
                                      VerticalTicketPreviewDialog(
                                        data: d,
                                        attendance: attendance,
                                        recordedTeam: team,
                                        recordedTeamColor: color,
                                        ticketNumber: ticketNumber,
                                        isWin: isWin,
                                        myScore: myScore,
                                        oppScore: oppScore,
                                        myTeam: myTeam,
                                        oppTeam: oppTeam,
                                        onOpenDetail: () {
                                          Navigator.pop(dialogContext);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  IntutionRecordDetailPage(
                                                    gameId: d['gameId'],
                                                  ),
                                            ),
                                          );
                                        },
                                        onDelete: () async {
                                          final confirmed =
                                              await showDeleteAttendanceConfirmDialog(
                                                dialogContext,
                                              );
                                          if (!confirmed || !context.mounted) {
                                            return;
                                          }
                                          Navigator.pop(dialogContext);
                                          final ok = await context
                                              .read<IntutionRecordProvider>()
                                              .deleteRecord(attendance);
                                          if (!context.mounted) return;
                                          toastification.show(
                                            context: context,
                                            type: ok
                                                ? ToastificationType.success
                                                : ToastificationType.error,
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                            title: Text(
                                              ok
                                                  ? '직관기록이 삭제되었습니다'
                                                  : '직관기록 삭제에 실패했습니다',
                                            ),
                                          );
                                        },
                                      ),
                                );
                              },
                            );
                          },
                        );
                      }

                      return ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: records.length,
                        itemBuilder: (context, i) {
                          final d = records[i];
                          final attendance = _toAttendance(d);
                          final myTeam = d['myTeam'] ?? '';
                          final oppTeam = d['oppTeam'] ?? '';
                          final myScore = d['myScore'] ?? 0;
                          final oppScore = d['opponentScore'] ?? 0;
                          final isWin = myScore > oppScore;

                          final tp = Provider.of<TeamProvider>(
                            context,
                            listen: false,
                          );
                          final team = tp.findTeamByName(myTeam);
                          final color = team?.color ?? GRAYSCALE_LABEL_500;

                          return RecordCard(
                            data: d,
                            attendance: attendance,
                            recordedTeam: team,
                            recordedTeamColor: color,
                            isWin: isWin,
                            myScore: myScore,
                            oppScore: oppScore,
                            myTeam: myTeam,
                            oppTeam: oppTeam,
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptionsSheet(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    showModalBottomSheet(
      context: context,
      backgroundColor: WHITE,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상단 드래그 핸들
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GRAYSCALE_LABEL_300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '직관 기록 추가',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: BLACK,
                  ),
                ),
                const SizedBox(height: 16),

                // 옵션 1: 스마트 티켓 스캔
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: teamColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_outlined,
                      color: teamColor,
                    ),
                  ),
                  title: const Text(
                    '스마트 티켓 스캔',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    '티켓 사진으로 날짜, 경기, 좌석, 가격 자동 입력',
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_600),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GRAYSCALE_LABEL_400,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext); // 옵션 시트 닫기

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (ctx) => TicketScanProvider(
                            scheduleProvider: ctx.read<ScheduleProvider>(),
                          ),
                          child: const TickerCameraScanPage(),
                        ),
                      ),
                    );
                  },
                ),

                const Divider(height: 16),

                // 옵션 2: 직접 입력하기
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_note_outlined, color: BLACK),
                  ),
                  title: const Text(
                    '직접 입력하기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    '경기 일정과 직관 내용을 직접 입력',
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_600),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GRAYSCALE_LABEL_400,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext); // 옵션 시트 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IntutionRecordUploadPage(),
                      ),
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

class _HeaderView extends StatelessWidget {
  int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Selector<IntutionRecordListProvider, List<Map<String, dynamic>>>(
      selector: (_, lp) => lp.records,
      builder: (context, records, child) {
        int wins = 0, losses = 0, draws = 0;
        for (final d in records) {
          final my = _parseScore(d['myScore']);
          final opp = _parseScore(d['opponentScore']);
          if (my != null && opp != null) {
            if (my > opp) {
              wins++;
            } else if (my < opp) {
              losses++;
            } else {
              draws++;
            }
          }
        }
        final total = records.length;
        final winRate = total == 0 ? 0 : (wins / total * 100).round();
        final int winMargin = wins - losses;
        final String marginText = winMargin > 0
            ? '승패 마진 +$winMargin'
            : (winMargin < 0 ? '승패 마진 $winMargin' : '승패 동률');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: BLACK.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚾ 직관 전적',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_950,
                      ),
                    ),
                    if (total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: winMargin >= 0
                              ? teamColor.withValues(alpha: 0.12)
                              : GRAYSCALE_LABEL_100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          marginText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: winMargin >= 0
                                ? teamColor
                                : GRAYSCALE_LABEL_700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat('경기 수', '$total', color: BLACK),
                    _divider(),
                    _stat('승', '$wins', color: BUTTON),
                    _divider(),
                    _stat('패', '$losses', color: Colors.redAccent),
                    _divider(),
                    _stat('무', '$draws', color: GRAYSCALE_LABEL_600),
                    _divider(),
                    _stat('승률', '$winRate%', color: teamColor),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (wins > 0)
                            Expanded(
                              flex: wins,
                              child: Container(color: BUTTON),
                            ),
                          if (draws > 0)
                            Expanded(
                              flex: draws,
                              child: Container(color: GRAYSCALE_LABEL_400),
                            ),
                          if (losses > 0)
                            Expanded(
                              flex: losses,
                              child: Container(color: Colors.redAccent),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 28, color: GRAYSCALE_LABEL_200);

  Widget _stat(String label, String value, {Color color = BLACK}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: GRAYSCALE_LABEL_500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// FilterBar - 정렬/연도 필터 + 티켓/카드 뷰 전환
class _FilterBar extends StatelessWidget {
  final bool isTicketGridMode;
  final VoidCallback onToggleViewMode;

  const _FilterBar({
    required this.isTicketGridMode,
    required this.onToggleViewMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Consumer<IntutionRecordListProvider>(
        builder: (context, lp, child) {
          return Row(
            children: [
              Material(
                color: WHITE,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _showYearPicker(context, lp),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: GRAYSCALE_LABEL_600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lp.selectedYear == null
                              ? '전체'
                              : '${lp.selectedYear}년',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GRAYSCALE_LABEL_900,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Material(
                color: WHITE,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onToggleViewMode,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTicketGridMode
                              ? Icons.view_agenda_outlined
                              : Icons.grid_view_rounded,
                          size: 15,
                          color: GRAYSCALE_LABEL_700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isTicketGridMode ? '카드형' : '티켓형',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GRAYSCALE_LABEL_800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: WHITE,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: lp.toggleSortOrder,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: GRAYSCALE_LABEL_600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lp.isDescending ? '최신순' : '이전순',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GRAYSCALE_LABEL_800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
