import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class WinRatePage extends StatelessWidget {
  const WinRatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userNickName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        title: Row(
          children: [
            Text(
              '승률',
              style: TextStyle(
                fontSize: 24,
                color: BLACK,
                fontWeight: FontWeight.bold,
              ),
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
          ],
        ),
        centerTitle: false,
      ),
      body: Consumer2<IntutionRecordListProvider, TeamProvider>(
        builder: (context, lp, tp, child) {
          if (lp.isLoading) {
            final selectedColor = tp.selectedTeam?.color ?? BUTTON;
            return Center(
              child: CircularProgressIndicator(color: selectedColor),
            );
          }
          final items = lp.records;
          final teamColor = tp.selectedTeam?.color ?? BUTTON;

          // 승리한 경기 수 계산
          int wins = 0;
          int losses = 0;
          int draws = 0;
          int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

          for (final item in items) {
            final int? my = _parseScore(item['myScore']);
            final int? opp = _parseScore(item['opponentScore']);
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
          final double winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Hero Section (Win Rate & Logo)
                  Container(
                    width: double.infinity,
                    height: 320,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: BLACK.withOpacity(0.05),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Logo (Watermark)
                        if (tp.selectedTeam != null)
                          Opacity(
                            opacity: 0.1,
                            child: Transform.scale(
                              scale: 1.5,
                              child: Image.asset(
                                tp.selectedTeam!.logoPath,
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '승률',
                              style: TextStyle(
                                color: GRAYSCALE_LABEL_500,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  winRate.toStringAsFixed(0),
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 140,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                    color: teamColor,
                                    shadows: [
                                      Shadow(
                                        color: teamColor.withOpacity(0.3),
                                        offset: Offset(0, 10),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Text(
                                    '%',
                                    style: GoogleFonts.blackHanSans(
                                      fontSize: 40,
                                      color: teamColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              userNickName,
                              style: TextStyle(
                                color: teamColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // 2. Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: '경기 수',
                          value: '$totalGames',
                          color: BLACK,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          label: '승',
                          value: '$wins',
                          color: BUTTON,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: '무',
                          value: '$draws',
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          label: '패',
                          value: '$losses',
                          color: Colors.redAccent,
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
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: GRAYSCALE_LABEL_500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 42,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
