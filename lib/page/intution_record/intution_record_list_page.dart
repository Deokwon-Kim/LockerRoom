import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordListPage extends StatelessWidget {
  const IntutionRecordListPage({super.key});

  // String _logoForTeam(TeamProvider tp, String nameOrSymple) {
  //   final bySymple = tp.findTeamByName(nameOrSymple);
  //   if (bySymple != null) return bySymple.calenderLogo;
  //   final list = tp.getTeam('team');
  //   final byFull = list.where((t) => t.name == nameOrSymple).toList();
  //   return byFull.isNotEmpty
  //       ? byFull.first.calenderLogo
  //       : 'assets/images/applogo/app_logo.png';
  // }

  // Map 데이터를 AttendanceModel로 변환
  AttendanceModel _mapToAttendanceModel(Map<String, dynamic> data) {
    int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

    return AttendanceModel(
      gameId: data['gameId'] ?? '',
      season: data['season'] ?? 0,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      oppTeam: data['oppTeam'],
      myScore: _parseScore(data['myScore']) ?? 0,
      opponentScore: _parseScore(data['opponentScore']) ?? 0,
      imageUrl: data['imageUrl'],
      memo: data['memo'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return '$year년 $month월 $day일';
      }
    } catch (e) {
      // 파싱 실패 시 원본 반환
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '나의 직관기록',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
      body: ChangeNotifierProvider(
        create: (_) => IntutionRecordListProvider()..subscribe(),
        child: Consumer2<IntutionRecordListProvider, TeamProvider>(
          builder: (context, lp, tp, child) {
            if (lp.isLoading) {
              final selectedColor = tp.selectedTeam?.color ?? BUTTON;
              return Center(
                child: CircularProgressIndicator(color: selectedColor),
              );
            }
            final items = lp.records;
            if (items.isEmpty) {
              return const Center(child: Text('직관 기록이 없습니다'));
            }
            int wins = 0;
            int losses = 0;
            int draws = 0;
            int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');
            for (final d in items) {
              final int? my = _parseScore(d['myScore']);
              final int? opp = _parseScore(d['opponentScore']);
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

            // 승률 계산
            final int totalGames = items.length;
            final double winRate = totalGames > 0
                ? (wins / totalGames) * 100
                : 0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.stadium_outlined),
                              SizedBox(height: 5),
                              Text(
                                '총 경기',
                                style: TextStyle(
                                  color: GRAYSCALE_LABEL_500,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${items.length}',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20),
                          Container(
                            width: 0.6,
                            height: 80,
                            color: GRAYSCALE_LABEL_300,
                          ),
                          SizedBox(width: 20),
                          Column(
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                color: Colors.blueAccent,
                              ),
                              SizedBox(height: 5),
                              Text(
                                '승',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '$wins',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.blueAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20),
                          Container(
                            width: 0.6,
                            height: 80,
                            color: GRAYSCALE_LABEL_300,
                          ),
                          SizedBox(width: 20),

                          Column(
                            children: [
                              Icon(
                                Icons.sentiment_dissatisfied_rounded,
                                color: Colors.redAccent,
                              ),
                              SizedBox(height: 5),
                              Text(
                                '패',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '$losses',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20),
                          Container(
                            width: 0.6,
                            height: 80,
                            color: GRAYSCALE_LABEL_300,
                          ),
                          SizedBox(width: 20),
                          Column(
                            children: [
                              Transform.translate(
                                offset: Offset(0, -10),
                                child: Icon(Icons.minimize_outlined),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '무',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '$draws',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20),
                          Container(
                            width: 0.6,
                            height: 80,
                            color: GRAYSCALE_LABEL_300,
                          ),
                          SizedBox(width: 10),
                          Column(
                            children: [
                              Icon(Icons.percent_outlined),
                              SizedBox(height: 5),
                              Text(
                                '승률',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                winRate.toStringAsFixed(1),
                                style: GoogleFonts.robotoMono(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Consumer<IntutionRecordListProvider>(
                  builder: (context, lp, child) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          lp.toggleSortOrder();
                        },
                        child: Row(
                          children: [
                            Consumer<IntutionRecordListProvider>(
                              builder: (context, lp, child) {
                                return InkWell(
                                  onTap: () => _showYearPicker(context, lp),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        lp.selectedYear == null
                                            ? '전체'
                                            : '${lp.selectedYear}년',
                                        style: GoogleFonts.roboto(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      Icon(Icons.keyboard_arrow_down, size: 24),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Spacer(),
                            Icon(
                              lp.isDescending
                                  ? Icons.swap_vert_outlined
                                  : Icons.swap_vert_outlined,
                              size: 24,
                            ),

                            Text(lp.isDescending ? '최신순' : '이전순'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (listContext, i) {
                      final d = items[i];
                      final myTeam = (d['myTeam'] ?? '') as String;
                      final oppTeam = (d['oppTeam'] ?? '') as String;
                      // final myLogo = _logoForTeam(tp, myTeam);
                      // final oppLogo = _logoForTeam(tp, oppTeam);
                      final attendance = _mapToAttendanceModel(d);

                      // 승패 여부 체크 추가
                      final myScore = d['myScore'] as int? ?? 0;
                      final oppScore = d['opponentScore'] as int? ?? 0;
                      final isWin = myScore > oppScore;

                      // 기록 당시 응원했던 팀의 색상 가져오기
                      final recordedTeam = tp.findTeamByName(myTeam);
                      final recordedTeamColor =
                          recordedTeam?.color ?? GRAYSCALE_LABEL_600;

                      final tile = GestureDetector(
                        onTap: () {
                          final gameId = d['gameId'] as String;
                          Navigator.push(
                            listContext,
                            MaterialPageRoute(
                              builder: (context) =>
                                  IntutionRecordDetailPage(gameId: gameId),
                            ),
                          );
                        },
                        child: Card(
                          color: Color(0xffF9F9FA),
                          child: SizedBox(
                            width: double.infinity,
                            height: 460,
                            child: Column(
                              children: [
                                d['imageUrl'] != null &&
                                        d['imageUrl'].toString().isNotEmpty
                                    ? Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadiusGeometry.vertical(
                                                  top: Radius.circular(12),
                                                ),
                                            child: CachedNetworkImage(
                                              imageUrl: d['imageUrl'],
                                              width: double.infinity,
                                              height: 350,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    height: 350,

                                                    color: recordedTeamColor
                                                        .withOpacity(0.3),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color:
                                                                recordedTeamColor,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 10,
                                                          ),
                                                      color: recordedTeamColor,
                                                      child: Image.asset(
                                                        recordedTeam!.logoPath,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                          if (d['memo'] != null &&
                                              d['memo']
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                            Positioned(
                                              bottom: 16,
                                              left: 16,
                                              right: 16,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(
                                                        0.6,
                                                      ),
                                                    ],
                                                  ),
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_note,
                                                      size: 20,
                                                      color: recordedTeamColor,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        d['memo'].toString(),
                                                        style:
                                                            GoogleFonts.nanumPenScript(
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white,
                                                              height: 1.3,
                                                            ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          // Padding(
                                          //   padding: const EdgeInsets.all(8.0),
                                          //   child: Row(
                                          //     mainAxisAlignment:
                                          //         MainAxisAlignment.center,
                                          //     children: [
                                          //       Text(
                                          //         myTeam,
                                          //         style: TextStyle(
                                          //           color: WHITE,
                                          //           fontSize: 25,
                                          //           fontWeight: FontWeight.bold,
                                          //         ),
                                          //       ),
                                          //       SizedBox(width: 50),
                                          //       Text(
                                          //         '$myScore',
                                          //         style: TextStyle(
                                          //           fontSize: 35,
                                          //           fontWeight: FontWeight.bold,
                                          //           color: WHITE,
                                          //         ),
                                          //       ),
                                          //       SizedBox(width: 10),
                                          //       Text(
                                          //         ':',
                                          //         style: TextStyle(
                                          //           color: WHITE,
                                          //           fontWeight: FontWeight.bold,
                                          //           fontSize: 25,
                                          //         ),
                                          //       ),
                                          //       SizedBox(width: 10),
                                          //       Text(
                                          //         '$oppScore',
                                          //         style: TextStyle(
                                          //           fontSize: 35,
                                          //           fontWeight: FontWeight.bold,
                                          //           color: WHITE,
                                          //         ),
                                          //       ),
                                          //       SizedBox(width: 50),
                                          //       Text(
                                          //         oppTeam,
                                          //         style: TextStyle(
                                          //           fontSize: 25,
                                          //           fontWeight: FontWeight.bold,
                                          //           color: WHITE,
                                          //         ),
                                          //       ),
                                          //     ],
                                          //   ),
                                          // ),
                                        ],
                                      )
                                    : Stack(
                                        alignment: Alignment.bottomLeft,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            height: 350,
                                            decoration: BoxDecoration(
                                              color: recordedTeamColor,
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(12),
                                                  ),
                                            ),

                                            child: Image.asset(
                                              recordedTeam!.logoPath,
                                            ),
                                          ),
                                          if (d['memo'] != null &&
                                              d['memo']
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                            Positioned(
                                              bottom: 16,
                                              left: 16,
                                              right: 16,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(
                                                        0.6,
                                                      ),
                                                    ],
                                                  ),
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.1),
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit_note,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        d['memo'].toString(),
                                                        style:
                                                            GoogleFonts.nanumPenScript(
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white,
                                                              height: 1.3,
                                                            ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 13.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.translate(
                                            offset: Offset(20, 0),
                                            child: Text(
                                              '$myScore',
                                              style: GoogleFonts.roboto(
                                                fontSize: 35,
                                                fontWeight: FontWeight.bold,
                                                color: isWin
                                                    ? recordedTeamColor
                                                    : GRAYSCALE_LABEL_500,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 40),
                                          Text(
                                            myTeam,
                                            style: TextStyle(
                                              color: BLACK,
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          SizedBox(width: 10),
                                          Text(
                                            'vs',
                                            style: TextStyle(
                                              color: GRAYSCALE_LABEL_500,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 25,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            oppTeam,
                                            style: TextStyle(
                                              fontSize: 25,
                                              fontWeight: FontWeight.bold,
                                              color: BLACK,
                                            ),
                                          ),
                                          SizedBox(width: 40),
                                          Transform.translate(
                                            offset: Offset(-20, 0),
                                            child: Text(
                                              '$oppScore',
                                              style: GoogleFonts.roboto(
                                                fontSize: 35,
                                                fontWeight: FontWeight.bold,
                                                color: GRAYSCALE_LABEL_500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Transform.translate(
                                        offset: Offset(0, -5),
                                        child: Column(
                                          children: [
                                            Text(
                                              _formatDate(d['date']),
                                              style: GoogleFonts.roboto(
                                                color: GRAYSCALE_LABEL_500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              d['stadium'],
                                              style: TextStyle(
                                                color: GRAYSCALE_LABEL_500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(
                          top: 20.0,
                          left: 16.0,
                          right: 16.0,
                        ),
                        child: Slidable(
                          key: ValueKey(attendance.gameId),
                          endActionPane: ActionPane(
                            motion: ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (slidableContext) async {
                                  if (!listContext.mounted) return;

                                  // 전역 Provider 가져오기
                                  try {
                                    final provider =
                                        Provider.of<IntutionRecordProvider>(
                                          listContext,
                                          listen: false,
                                        );

                                    final success = await provider.deleteRecord(
                                      attendance,
                                    );

                                    if (!listContext.mounted) return;

                                    if (success) {
                                      toastification.show(
                                        context: listContext,
                                        type: ToastificationType.success,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('직관기록이 삭제되었습니다'),
                                      );
                                    } else {
                                      toastification.show(
                                        context: listContext,
                                        type: ToastificationType.error,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('직관기록 삭제에 실패했습니다'),
                                      );
                                    }
                                  } catch (e) {
                                    if (listContext.mounted) {
                                      toastification.show(
                                        context: listContext,
                                        type: ToastificationType.error,
                                        alignment: Alignment.bottomCenter,
                                        autoCloseDuration: Duration(seconds: 2),
                                        title: Text('삭제 중 오류가 발생했습니다'),
                                      );
                                    }
                                  }
                                },
                                backgroundColor: RED_DANGER_TEXT_50,
                                icon: Icons.delete,
                                foregroundColor: WHITE,
                                label: '삭제',
                              ),
                            ],
                          ),
                          child: tile,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
}
