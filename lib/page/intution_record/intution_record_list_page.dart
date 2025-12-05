import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/page/intution_record/_record_card.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
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
          automaticallyImplyLeading: false,
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IntutionRecordUploadPage(),
                  ),
                );
              },
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
}

class _HeaderView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<IntutionRecordListProvider, List<Map<String, dynamic>>>(
      selector: (_, lp) => lp.records,
      builder: (context, records, child) {
        int wins = 0, losses = 0, draws = 0;
        for (final d in records) {
          final my = d['myScore'] ?? '0';
          final opp = d['opponentScore'] ?? 0;
          if (my > opp)
            wins++;
          else if (my < opp)
            losses++;
          else
            draws++;
        }
        final total = records.length;
        final winRate = total == 0 ? 0 : (wins / total * 100).round();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  offset: Offset(2, 3),
                  color: BLACK.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stat('총 경기', '$total', icon: Icons.stadium_outlined),
                  _divider(),
                  _stat(
                    '승',
                    '$wins',
                    color: Colors.blueAccent,
                    icon: Icons.emoji_events_outlined,
                  ),
                  _divider(),
                  _stat(
                    '패',
                    '$losses',
                    color: Colors.redAccent,
                    icon: Icons.sentiment_dissatisfied_rounded,
                  ),
                  _divider(),
                  _stat('무', '$draws', icon: Icons.remove),
                  _divider(),
                  _stat('승률', '$winRate', icon: Icons.percent_outlined),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 70, color: GRAYSCALE_LABEL_300);

  Widget _stat(
    String label,
    String value, {
    Color color = BLACK,
    IconData? icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          if (icon != null) Icon(icon, color: color, size: 22),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
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
