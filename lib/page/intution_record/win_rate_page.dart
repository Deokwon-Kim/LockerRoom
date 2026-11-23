import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/main.dart';
import 'package:lockerroom/page/intution_record/intuition_recap_page.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/page/quiz/quiz_result_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class WinRatePage extends StatefulWidget {
  const WinRatePage({super.key});

  @override
  State<WinRatePage> createState() => _WinRatePageState();
}

class _WinRatePageState extends State<WinRatePage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;
  bool _showAllOpponents = false;
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
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              '나의 직관',
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

          // 승리한 경기 수, 득실점, 연승, 베스트 매치, 구장 도장깨기 계산
          int wins = 0;
          int losses = 0;
          int draws = 0;
          int totalMyRuns = 0;
          int totalOppRuns = 0;
          int scoredGamesCount = 0;
          int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

          // 날짜 오름차순 정렬 (연승 및 최근 흐름 계산용)
          final sortedChronological = List<Map<String, dynamic>>.from(items)
            ..sort((a, b) {
              final da = (a['date'] as String?) ?? '';
              final db = (b['date'] as String?) ?? '';
              final cmp = da.compareTo(db);
              if (cmp != 0) return cmp;
              final ta = (a['time'] as String?) ?? '';
              final tb = (b['time'] as String?) ?? '';
              return ta.compareTo(tb);
            });

          int maxWinStreak = 0;
          int runningWinStreak = 0;
          Map<String, dynamic>? bestMatch;
          int bestMatchMargin = -999;
          int bestMatchMyScore = -1;

          final Map<String, int> stadiumVisits = {};
          final Map<String, _OpponentStat> oppStats = {};

          for (final item in sortedChronological) {
            final int? my = _parseScore(item['myScore']);
            final int? opp = _parseScore(item['opponentScore']);
            final String rawStadium =
                (item['stadium'] as String?)?.trim() ?? '';
            if (rawStadium.isNotEmpty) {
              final normStadium = _normalizeKboStadium(rawStadium);
              if (normStadium != null) {
                stadiumVisits[normStadium] =
                    (stadiumVisits[normStadium] ?? 0) + 1;
              }
            }

            final String rawOpp = (item['oppTeam'] as String?)?.trim() ?? '';
            final oppTeamModel = rawOpp.isNotEmpty
                ? tp.findTeamByName(rawOpp)
                : null;
            final String oppKey = oppTeamModel?.symplename ?? rawOpp;

            if (my != null && opp != null) {
              totalMyRuns += my;
              totalOppRuns += opp;
              scoredGamesCount++;

              if (oppKey.isNotEmpty) {
                final stat = oppStats.putIfAbsent(
                  oppKey,
                  () => _OpponentStat(
                    name: oppKey,
                    color: oppTeamModel?.color ?? GRAYSCALE_LABEL_600,
                  ),
                );
                if (my > opp) {
                  stat.wins++;
                } else if (my < opp) {
                  stat.losses++;
                } else {
                  stat.draws++;
                }
              }

              if (my > opp) {
                wins++;
                runningWinStreak++;
                if (runningWinStreak > maxWinStreak) {
                  maxWinStreak = runningWinStreak;
                }
                final margin = my - opp;
                if (margin > bestMatchMargin ||
                    (margin == bestMatchMargin && my > bestMatchMyScore)) {
                  bestMatchMargin = margin;
                  bestMatchMyScore = my;
                  bestMatch = item;
                }
              } else if (my < opp) {
                losses++;
                runningWinStreak = 0;
              } else {
                draws++;
                runningWinStreak = 0;
              }
            }
          }

          // 현재 연승/연패 계산 (가장 최근 경기부터 역순 확인)
          int currentWinStreak = 0;
          int currentLossStreak = 0;
          String currentStreakText = '기록 없음';
          if (sortedChronological.isNotEmpty) {
            for (int i = sortedChronological.length - 1; i >= 0; i--) {
              final r = sortedChronological[i];
              final my = _parseScore(r['myScore']);
              final opp = _parseScore(r['opponentScore']);
              if (my == null || opp == null) continue;
              if (my > opp) {
                if (currentLossStreak > 0) break;
                currentWinStreak++;
              } else if (my < opp) {
                if (currentWinStreak > 0) break;
                currentLossStreak++;
              } else {
                break;
              }
            }
            if (currentWinStreak > 0) {
              currentStreakText = '🔥 ${currentWinStreak}연승 중';
            } else if (currentLossStreak > 0) {
              currentStreakText = '${currentLossStreak}연패 중';
            } else {
              currentStreakText = '직전 경기 무승부';
            }
          }

          // 최근 5경기 (오래된 순 -> 최신 순으로 최대 5개)
          final recentGames = sortedChronological.length > 5
              ? sortedChronological.sublist(sortedChronological.length - 5)
              : sortedChronological;

          // 승률 계산
          final int totalGames = items.length;
          final double winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0;
          final String fairyTitle = _getFairyTitle(
            totalGames: totalGames,
            winRate: winRate,
            currentWinStreak: currentWinStreak,
          );

          final double avgMyRuns = scoredGamesCount > 0
              ? totalMyRuns / scoredGamesCount
              : 0.0;
          final double avgOppRuns = scoredGamesCount > 0
              ? totalOppRuns / scoredGamesCount
              : 0.0;
          final double avgMargin = avgMyRuns - avgOppRuns;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Hero Section (Win Rate & Logo + 승리요정 칭호 뱃지)
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      width: double.infinity,
                      height: 340,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: teamColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  fairyTitle,
                                  style: TextStyle(
                                    color: teamColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '승률',
                                style: TextStyle(
                                  color: GRAYSCALE_LABEL_500,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    winRate.toStringAsFixed(0),
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 132,
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
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Text(
                                      '%',
                                      style: GoogleFonts.blackHanSans(
                                        fontSize: 38,
                                        color: teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Padding(
                                padding: _isCapturing
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.only(left: 25.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      userNickName,
                                      style: TextStyle(
                                        color: teamColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (!_isCapturing)
                                      IconButton(
                                        onPressed: () {
                                          _showShareBottomSheet();
                                        },
                                        icon: Icon(
                                          CupertinoIcons.share,
                                          size: 15,
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
                  ),

                  SizedBox(height: 20),

                  if (totalGames > 0) ...[
                    _buildRecapBannerCard(
                      context: context,
                      records: items,
                      selectedYear: lp.selectedYear,
                      teamColor: teamColor,
                      userNickName: userNickName,
                      totalGames: totalGames,
                      visitedStadiumCount: stadiumVisits.length,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. 직관 전적 카드 (컴팩트 4열 + 승무패 비율 바)
                  _buildRecordOverviewCard(
                    totalGames: totalGames,
                    wins: wins,
                    losses: losses,
                    draws: draws,
                    teamColor: teamColor,
                  ),
                  if (totalGames > 0) ...[
                    const SizedBox(height: 16),

                    // 3. 최근 직관 흐름 & 최다 연승 기록 카드
                    _buildStreakAndRecentFormCard(
                      teamColor: teamColor,
                      currentStreakText: currentStreakText,
                      currentWinStreak: currentWinStreak,
                      maxWinStreak: maxWinStreak,
                      recentGames: recentGames,
                      parseScore: _parseScore,
                    ),

                    const SizedBox(height: 16),

                    // 4. 직관 공·수 화력 & 최고의 직관 경기 카드
                    _buildFirepowerAndBestMatchCard(
                      context: context,
                      teamColor: teamColor,
                      avgMyRuns: avgMyRuns,
                      avgOppRuns: avgOppRuns,
                      avgMargin: avgMargin,
                      bestMatch: bestMatch,
                      parseScore: _parseScore,
                    ),

                    const SizedBox(height: 16),

                    // 5. KBO 구장 도장깨기 카드
                    _buildStadiumStampCard(
                      teamColor: teamColor,
                      stadiumVisits: stadiumVisits,
                    ),

                    if (oppStats.isNotEmpty) ...[
                      const SizedBox(height: 16),

                      // 6. 상대팀별 직관 상성 리포트 카드
                      _buildOpponentMatchupCard(
                        teamColor: teamColor,
                        oppStats: oppStats.values.toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _resolveDarkAccent(Color raw) {
    if (raw.toARGB32() == KIWOOM.toARGB32()) {
      return raw;
    }
    final hsl = HSLColor.fromColor(raw);
    if (hsl.saturation < 0.12 && hsl.lightness < 0.22) {
      return const Color(0xFFFF4D4D);
    }
    if (hsl.lightness < 0.22) {
      return hsl
          .withLightness(0.56)
          .withSaturation((hsl.saturation * 1.1).clamp(0.45, 0.95))
          .toColor();
    }
    return raw;
  }

  Widget _buildRecapBannerCard({
    required BuildContext context,
    required List<Map<String, dynamic>> records,
    required int? selectedYear,
    required Color teamColor,
    required String userNickName,
    required int totalGames,
    required int visitedStadiumCount,
  }) {
    final yearText = selectedYear == null ? '전체 시즌' : '${selectedYear}년';
    final brightAccent = _resolveDarkAccent(teamColor);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IntuitionRecapPage(
              records: records,
              selectedYear: selectedYear,
              teamColor: teamColor,
              userNickName: userNickName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14161D), Color(0xFF1E222D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: brightAccent.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: brightAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brightAccent.withValues(alpha: 0.45)),
              ),
              child: Icon(
                Icons.route_rounded,
                color: brightAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: brightAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$yearText 리캡',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ANIMATION',
                        style: TextStyle(
                          color: Color(0xFF8B92A5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '내 직관 여정 애니메이션 보기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalGames경기 · $visitedStadiumCount개 구장 이동 경로 한눈에 보기',
                    style: const TextStyle(
                      color: Color(0xFFA0A6B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: brightAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentMatchupCard({
    required Color teamColor,
    required List<_OpponentStat> oppStats,
  }) {
    final sorted = List<_OpponentStat>.from(oppStats)
      ..sort((a, b) {
        final cmpTotal = b.total.compareTo(a.total);
        if (cmpTotal != 0) return cmpTotal;
        return b.winRate.compareTo(a.winRate);
      });

    // 킬러 상대 (최소 2경기 이상 & 승 > 패 중 다승 우선 -> 승률 순)
    // 천적 상대 (최소 2경기 이상 & 패 > 승 중 다패 우선 -> 낮은 승률 순)
    _OpponentStat? killerTarget;
    for (final s in sorted) {
      if (s.total >= 2 && s.wins > s.losses) {
        if (killerTarget == null ||
            s.wins > killerTarget.wins ||
            (s.wins == killerTarget.wins && s.winRate > killerTarget.winRate)) {
          killerTarget = s;
        }
      }
    }

    _OpponentStat? nemesisTarget;
    for (final s in sorted) {
      if (s.total >= 2 && s.losses > s.wins) {
        if (nemesisTarget == null ||
            s.losses > nemesisTarget.losses ||
            (s.losses == nemesisTarget.losses &&
                s.winRate < nemesisTarget.winRate)) {
          nemesisTarget = s;
        }
      }
    }

    final displayList = _showAllOpponents || sorted.length <= 4
        ? sorted
        : sorted.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GRAYSCALE_LABEL_200.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: BLACK.withValues(alpha: 0.04),
            blurRadius: 14,
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
                '⚔️ 상대팀별 직관 상성',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_950,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: teamColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${sorted.length}개 구단 맞대결',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: teamColor,
                  ),
                ),
              ),
            ],
          ),
          if (killerTarget != null || nemesisTarget != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (killerTarget != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: teamColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔥 내 승요 먹잇감',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: teamColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'vs ${killerTarget.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: GRAYSCALE_LABEL_950,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (killerTarget != null && nemesisTarget != null)
                  const SizedBox(width: 8),
                if (nemesisTarget != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: RED_DANGER_TEXT_50.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: RED_DANGER_TEXT_50.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '😭 주의할 천적',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: RED_DANGER_TEXT_50,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'vs ${nemesisTarget.name}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: GRAYSCALE_LABEL_950,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ...displayList.map((stat) {
            final rate = stat.winRate;
            final isStrong = rate >= 50;
            final barColor = isStrong ? teamColor : GRAYSCALE_LABEL_400;
            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: stat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stat.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: GRAYSCALE_LABEL_900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${stat.wins}승 ${stat.draws > 0 ? '${stat.draws}무 ' : ''}${stat.losses}패',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${rate.round()}%',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            color: isStrong ? teamColor : GRAYSCALE_LABEL_700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (rate / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: GRAYSCALE_LABEL_100,
                      color: barColor,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sorted.length > 4)
            Center(
              child: InkWell(
                onTap: () =>
                    setState(() => _showAllOpponents = !_showAllOpponents),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Text(
                    _showAllOpponents
                        ? '접기 ▲'
                        : '전체 상대팀 보기 (${sorted.length}팀) ▼',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: teamColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const List<String> _kboMainStadiums = [
    '잠실',
    '고척',
    '문학',
    '수원',
    '대전',
    '대구',
    '광주',
    '사직',
    '창원',
  ];

  String? _normalizeKboStadium(String stadium) {
    if (stadium.contains('잠실')) return '잠실';
    if (stadium.contains('고척')) return '고척';
    if (stadium.contains('문학') ||
        stadium.contains('인천') ||
        stadium.contains('랜더스')) {
      return '문학';
    }
    if (stadium.contains('수원') || stadium.contains('위즈')) return '수원';
    if (stadium.contains('대전') ||
        stadium.contains('이글스') ||
        stadium.contains('볼파크')) {
      return '대전';
    }
    if (stadium.contains('대구') || stadium.contains('라이온즈')) return '대구';
    if (stadium.contains('광주') || stadium.contains('챔피언스')) return '광주';
    if (stadium.contains('사직') || stadium.contains('부산')) return '사직';
    if (stadium.contains('창원') ||
        stadium.contains('마산') ||
        stadium.contains('NC')) {
      return '창원';
    }
    return null;
  }

  String _getFairyTitle({
    required int totalGames,
    required double winRate,
    required int currentWinStreak,
  }) {
    if (totalGames == 0) return '⚾ 설레는 첫 직관 대기 중';
    if (currentWinStreak >= 3) return '🔥 ${currentWinStreak}연승 폭주 승리요정';
    if (totalGames >= 3 && winRate >= 70) return '🧚 확신의 승리요정';
    if (totalGames >= 1 && winRate == 100) return '✨ 백전백승 승리요정';
    if (totalGames >= 5 && winRate >= 55) return '⚾ 든든한 승리 수호신';
    if (totalGames >= 10 && winRate >= 50) return '🏟️ 야구장 출근도장 승요';
    if (winRate >= 50) return '🍀 기운 좋은 직관러';
    return '🕯️ 반등을 노리는 직관러';
  }

  Widget _buildStreakAndRecentFormCard({
    required Color teamColor,
    required String currentStreakText,
    required int currentWinStreak,
    required int maxWinStreak,
    required List<Map<String, dynamic>> recentGames,
    required int? Function(dynamic) parseScore,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
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
                '🔥 최근 직관 흐름',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BLACK,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: currentWinStreak > 0
                      ? teamColor.withOpacity(0.12)
                      : GRAYSCALE_LABEL_200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentStreakText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentWinStreak > 0
                        ? teamColor
                        : GRAYSCALE_LABEL_700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: recentGames.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final g = entry.value;
                    final isLatest = idx == recentGames.length - 1;
                    final my = parseScore(g['myScore']);
                    final opp = parseScore(g['opponentScore']);
                    final oppTeam = (g['oppTeam'] as String?) ?? '';

                    String label = '무';
                    Color badgeColor = GRAYSCALE_LABEL_500;
                    if (my != null && opp != null) {
                      if (my > opp) {
                        label = '승';
                        badgeColor = BUTTON;
                      } else if (my < opp) {
                        label = '패';
                        badgeColor = Colors.redAccent;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isLatest
                                  ? badgeColor
                                  : badgeColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: isLatest
                                  ? Border.all(
                                      color: badgeColor.withOpacity(0.4),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isLatest ? WHITE : badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            oppTeam.isNotEmpty ? oppTeam : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isLatest
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isLatest ? BLACK : GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '최다 연승',
                    style: TextStyle(
                      fontSize: 11,
                      color: GRAYSCALE_LABEL_500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${maxWinStreak}연승',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: teamColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFirepowerAndBestMatchCard({
    required BuildContext context,
    required Color teamColor,
    required double avgMyRuns,
    required double avgOppRuns,
    required double avgMargin,
    required Map<String, dynamic>? bestMatch,
    required int? Function(dynamic) parseScore,
  }) {
    final marginPrefix = avgMargin > 0 ? '+' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
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
          const Text(
            '⚡ 직관 공·수 화력',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: BLACK,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  label: '평균 득점',
                  value: '${avgMyRuns.toStringAsFixed(1)}점',
                  color: BUTTON,
                ),
              ),
              Container(width: 1, height: 36, color: GRAYSCALE_LABEL_200),
              Expanded(
                child: _buildMiniMetric(
                  label: '평균 실점',
                  value: '${avgOppRuns.toStringAsFixed(1)}점',
                  color: Colors.redAccent,
                ),
              ),
              Container(width: 1, height: 36, color: GRAYSCALE_LABEL_200),
              Expanded(
                child: _buildMiniMetric(
                  label: '평균 득실 마진',
                  value: '$marginPrefix${avgMargin.toStringAsFixed(1)}',
                  color: avgMargin >= 0 ? teamColor : GRAYSCALE_LABEL_600,
                ),
              ),
            ],
          ),
          if (bestMatch != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: GRAYSCALE_LABEL_200),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final gameId = bestMatch['gameId'] as String?;
                if (gameId != null && gameId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IntutionRecordDetailPage(gameId: gameId),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: BACKGROUND_COLOR,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.orange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '최고의 직관 승리 경기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bestMatch['date'] ?? ''} · vs ${bestMatch['oppTeam'] ?? ''}${bestMatch['stadium'] != null ? ' (${bestMatch['stadium']})' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: BLACK,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BUTTON.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${parseScore(bestMatch['myScore']) ?? 0} : ${parseScore(bestMatch['opponentScore']) ?? 0} 승',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: BUTTON,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: GRAYSCALE_LABEL_400,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: GRAYSCALE_LABEL_500,
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
          ),
        ),
      ],
    );
  }

  Widget _buildStadiumStampCard({
    required Color teamColor,
    required Map<String, int> stadiumVisits,
  }) {
    final visitedCount = _kboMainStadiums
        .where((s) => (stadiumVisits[s] ?? 0) > 0)
        .length;
    final progress = visitedCount / _kboMainStadiums.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
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
                '🏟️ KBO 구장 도장깨기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BLACK,
                ),
              ),
              Text(
                '$visitedCount / ${_kboMainStadiums.length} 구장',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: teamColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: GRAYSCALE_LABEL_200,
              valueColor: AlwaysStoppedAnimation<Color>(teamColor),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
            ),
            itemCount: _kboMainStadiums.length,
            itemBuilder: (context, index) {
              final stadium = _kboMainStadiums[index];
              final count = stadiumVisits[stadium] ?? 0;
              final visited = count > 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: visited
                      ? teamColor.withOpacity(0.1)
                      : BACKGROUND_COLOR,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: visited ? teamColor : GRAYSCALE_LABEL_200,
                    width: visited ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      visited ? Icons.verified_rounded : Icons.stadium_outlined,
                      size: 15,
                      color: visited ? teamColor : GRAYSCALE_LABEL_400,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        visited ? '$stadium (${count}회)' : stadium,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: visited
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: visited ? BLACK : GRAYSCALE_LABEL_400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordOverviewCard({
    required int totalGames,
    required int wins,
    required int losses,
    required int draws,
    required Color teamColor,
  }) {
    final int winMargin = wins - losses;
    final String marginText = winMargin > 0
        ? '승패 마진 +$winMargin'
        : (winMargin < 0 ? '승패 마진 $winMargin' : '승패 동률');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BLACK,
                ),
              ),
              if (totalGames > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: winMargin >= 0
                        ? teamColor.withOpacity(0.12)
                        : GRAYSCALE_LABEL_200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    marginText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: winMargin >= 0 ? teamColor : GRAYSCALE_LABEL_700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRecordColumnItem(
                  label: '경기 수',
                  value: '$totalGames',
                  color: BLACK,
                ),
              ),
              Container(width: 1, height: 36, color: GRAYSCALE_LABEL_200),
              Expanded(
                child: _buildRecordColumnItem(
                  label: '승',
                  value: '$wins',
                  color: BUTTON,
                ),
              ),
              Container(width: 1, height: 36, color: GRAYSCALE_LABEL_200),
              Expanded(
                child: _buildRecordColumnItem(
                  label: '패',
                  value: '$losses',
                  color: Colors.redAccent,
                ),
              ),
              Container(width: 1, height: 36, color: GRAYSCALE_LABEL_200),
              Expanded(
                child: _buildRecordColumnItem(
                  label: '무',
                  value: '$draws',
                  color: GRAYSCALE_LABEL_600,
                ),
              ),
            ],
          ),
          if (totalGames > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
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
    );
  }

  Widget _buildRecordColumnItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: GRAYSCALE_LABEL_500,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            color: color,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              '공유하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
              ),
            ),
            SizedBox(height: 24),
            ShareOption(
              icon: Icons.download,
              iconColor: GREEN_SUCCESS_TEXT_50,
              title: '이미지로 저장',
              subtitle: '갤러리에 저장',
              onTap: () {
                Navigator.pop(context);
                _saveToGallery();
              },
            ),
            ShareOption(
              icon: Icons.post_add,
              iconColor: BUTTON,
              title: '게시물로 공유',
              subtitle: 'Feed에 올리기',
              onTap: () {
                Navigator.pop(context);
                _shareToFeed();
              },
            ),
            ShareOption(
              icon: Icons.share,
              iconColor: ORANGE_PRIMARY_500,
              title: '다른 앱으로 공유',
              subtitle: 'Instagram, Threads, 카톡 등',
              onTap: () {
                Navigator.pop(context);
                _shareToOtherApps();
              },
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(fontSize: 16, color: GRAYSCALE_LABEL_600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    try {
      // 임시 파일로 저장 후 갤러리에 저장
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(image);

      await Gal.putImage(tempFile.path);
      _showToast('갤러리에 저장되었습니다');

      // 임시 파일 삭제
      await tempFile.delete();
    } catch (e) {
      _showToast('저장 실패');
    }
  }

  // Feed에 공유
  Future<void> _shareToFeed() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    // UploadProvider에 이미지와 캡션 설정
    if (mounted) {
      final uploadProvider = context.read<UploadProvider>();

      // 저장된 이미지 파일 경로 찾기 (ImageGallerySaver는 경로를 직접 반환하지 않을 수 있어서 임시 파일 사용)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/winrate_temp.png');
      await tempFile.writeAsBytes(image);

      final irp = context.read<IntutionRecordListProvider>();
      final records = irp.records;
      int wins = 0;
      int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

      for (final item in records) {
        final int? my = _parseScore(item['myScore']);
        final int? opp = _parseScore(item['opponentScore']);
        if (my != null && opp != null) {
          if (my > opp) {
            wins++;
          }
        }
      }

      final totalGames = records.length;
      final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

      uploadProvider.setImages([tempFile]);
      uploadProvider.setInitialCaption(
        'ILU 직관 승률 ${winRate.toStringAsFixed(0)}% 달성! 🎉\n\n#직관승률 #승요 #ILU #직관러',
      );

      // AuthWrapper를 통해 이동하여 사용자 정보 로드 및 초기화 보장
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AuthWrapper(initialIndex: 2)),
        (route) => false, // 모든 이전 라우트 제거
      );
    }

    _showToast('이미지가 선택되었습니다');
  }

  Future<void> _shareToOtherApps() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    final directory = await getTemporaryDirectory();
    final imagePath =
        '${directory.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(image);

    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    // winRate 계산
    final irp = context.read<IntutionRecordListProvider>();
    final records = irp.records;
    int wins = 0;
    int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

    for (final item in records) {
      final int? my = _parseScore(item['myScore']);
      final int? opp = _parseScore(item['opponentScore']);
      if (my != null && opp != null) {
        if (my > opp) {
          wins++;
        }
      }
    }

    final totalGames = records.length;
    final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

    await Share.shareXFiles(
      [XFile(imagePath)],
      text:
          'ILU 직관 승률 ${winRate.toStringAsFixed(0)}% 달성! 🎉\n\n#직관승률 #승요 #ILU #직관러',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showToast(String message) {
    toastification.show(
      context: context,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: Duration(seconds: 2),
      type: ToastificationType.success,
      title: Text(message),
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

class _OpponentStat {
  final String name;
  final Color color;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  _OpponentStat({required this.name, required this.color});

  int get total => wins + losses + draws;
  double get winRate => total > 0 ? (wins / total) * 100 : 0.0;
}
