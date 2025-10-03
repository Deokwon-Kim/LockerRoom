import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class IntutionRecordListPage extends StatelessWidget {
  const IntutionRecordListPage({super.key});

  String _logoForTeam(TeamProvider tp, String nameOrSymple) {
    final bySymple = tp.findTeamByName(nameOrSymple);
    if (bySymple != null) return bySymple.logoPath;
    final list = tp.getTeam('team');
    final byFull = list.where((t) => t.name == nameOrSymple).toList();
    return byFull.isNotEmpty
        ? byFull.first.logoPath
        : 'assets/images/applogo/app_logo.png';
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
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '패 $losses',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '무 $draws',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade800,
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
                    itemBuilder: (context, i) {
                      final d = items[i];
                      final myTeam = (d['myTeam'] ?? '') as String;
                      final oppTeam = (d['oppTeam'] ?? '') as String;
                      final myLogo = _logoForTeam(tp, myTeam);
                      final oppLogo = _logoForTeam(tp, oppTeam);

                      return Padding(
                        padding: const EdgeInsets.only(
                          top: 20.0,
                          left: 16.0,
                          right: 16.0,
                        ),
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
