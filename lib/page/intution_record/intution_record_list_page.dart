import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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

  String _logoForTeam(TeamProvider tp, String nameOrSymple) {
    final bySymple = tp.findTeamByName(nameOrSymple);
    if (bySymple != null) return bySymple.calenderLogo;
    final list = tp.getTeam('team');
    final byFull = list.where((t) => t.name == nameOrSymple).toList();
    return byFull.isNotEmpty
        ? byFull.first.calenderLogo
        : 'assets/images/applogo/app_logo.png';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '나의 직관기록',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
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
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: BACKGROUND_COLOR,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GRAYSCALE_LABEL_300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '총 ${items.length} 경기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '승 $wins',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '패 $losses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '무 $draws',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '승률: ${winRate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (listContext, i) {
                      final d = items[i];
                      final myTeam = (d['myTeam'] ?? '') as String;
                      final oppTeam = (d['oppTeam'] ?? '') as String;
                      final myLogo = _logoForTeam(tp, myTeam);
                      final oppLogo = _logoForTeam(tp, oppTeam);
                      final attendance = _mapToAttendanceModel(d);

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
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: GRAYSCALE_LABEL_100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${d['myScore']}',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_600,
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 20),
                                    Image.asset(myLogo, width: 50, height: 50),
                                    SizedBox(width: 10),
                                    Text(
                                      myTeam,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'VS',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_600,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      oppTeam,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Image.asset(oppLogo, width: 50, height: 50),
                                    SizedBox(width: 20),
                                    Text(
                                      '${d['opponentScore']}',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_600,
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, -10),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${d['date'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: GRAYSCALE_LABEL_500,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${d['stadium'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: GRAYSCALE_LABEL_500,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
}
