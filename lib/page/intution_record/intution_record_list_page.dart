import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/page/intution_record/_record_card.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/page/intution_record/ticker_camera_scan_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:provider/provider.dart';

class IntutionRecordListPage extends StatelessWidget {
  const IntutionRecordListPage({super.key});

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
          title: Text(
            '나의 직관기록',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              onPressed: () => _showAddOptionsSheet(context),
              // onPressed: () {
              //   // Navigator.push(
              //   //   context,
              //   //   MaterialPageRoute(
              //   //     builder: (context) => IntutionRecordUploadPage(),
              //   //   ),
              //   // );
              // },
              icon: Icon(Icons.add, size: 30),
            ),
          ],
        ),
        body: Column(
          children: [
            // ------------------ 통계 + 필터 영역 ------------------
            _HeaderView(),
            SizedBox(height: 10),
            _FilterBar(),

            // ------------------ 리스트 ------------------
            Expanded(
              child:
                  Selector<
                    IntutionRecordListProvider,
                    List<Map<String, dynamic>>
                  >(
                    selector: (_, lp) => lp.records,
                    builder: (context, records, child) {
                      if (records.isEmpty) {
                        return Center(child: Text('직관 기록이 없습니다'));
                      }

                      return ListView.builder(
                        physics: ClampingScrollPhysics(),
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
                    // const Text(
                    //   '⚾ 직관 전적',
                    //   style: TextStyle(
                    //     fontSize: 14,
                    //     fontWeight: FontWeight.bold,
                    //     color: BLACK,
                    //   ),
                    // ),
                    // if (total > 0)
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 8,
                    //       vertical: 3,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: winMargin >= 0
                    //           ? teamColor.withOpacity(0.12)
                    //           : GRAYSCALE_LABEL_200,
                    //       borderRadius: BorderRadius.circular(10),
                    //     ),
                    //     child: Text(
                    //       marginText,
                    //       style: TextStyle(
                    //         fontSize: 11,
                    //         fontWeight: FontWeight.bold,
                    //         color: winMargin >= 0
                    //             ? teamColor
                    //             : GRAYSCALE_LABEL_700,
                    //       ),
                    //     ),
                    //   ),
                  ],
                ),
                const SizedBox(height: 10),
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

// FilterBar - 정렬/연도 필터
class _FilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Consumer<IntutionRecordListProvider>(
        builder: (context, lp, child) {
          return Row(
            children: [
              InkWell(
                onTap: () => _showYearPicker(context, lp),
                child: Row(
                  children: [
                    Text(
                      lp.selectedYear == null ? '전체' : '${lp.selectedYear}년',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
              Spacer(),
              GestureDetector(
                onTap: lp.toggleSortOrder,
                child: Row(
                  children: [
                    Icon(Icons.swap_vert),
                    Text(lp.isDescending ? '최신순' : '이전순'),
                  ],
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
