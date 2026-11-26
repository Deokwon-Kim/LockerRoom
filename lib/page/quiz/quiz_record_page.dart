import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_detail_page.dart';
import 'package:lockerroom/provider/quiz_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class QuizRecordPage extends StatefulWidget {
  const QuizRecordPage({super.key});

  @override
  State<QuizRecordPage> createState() => _QuizRecordPageState();
}

class _QuizRecordPageState extends State<QuizRecordPage> {
  String _modeFilter = 'all'; // 'all' | 'threeOut' | 'normal'
  String _categoryFilter = '전체';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<QuizProvider>().fetchMyHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final teamColor =
        context.watch<TeamProvider>().selectedTeam?.color ?? BUTTON;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0F172A)
          : const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF0F172A)
            : const Color(0xFFF9FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '나의 타격 기록',
          style: TextStyle(
            fontFamily: 'kbo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : const Color(0xFF141B2D),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<QuizProvider>(
        builder: (context, quizProvider, child) {
          if (quizProvider.isLoading) {
            return Center(child: CircularProgressIndicator(color: teamColor));
          }

          final history = quizProvider.myHistory;
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 76,
                    color: isDarkMode ? Colors.white12 : GRAYSCALE_LABEL_300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 푼 퀴즈가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white38 : GRAYSCALE_LABEL_600,
                      fontFamily: 'kbo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '퀴즈를 풀고 나만의 박스스코어를 쌓아보세요!',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDarkMode ? Colors.white24 : GRAYSCALE_LABEL_500,
                    ),
                  ),
                ],
              ),
            );
          }

          final categories = <String>{
            '전체',
            ...history.map((e) => e.category).where((c) => c.isNotEmpty),
          }.toList();
          if (!categories.contains(_categoryFilter)) {
            _categoryFilter = '전체';
          }

          final filtered = history.where((r) {
            final modeOk =
                _modeFilter == 'all' ||
                (_modeFilter == 'threeOut' && r.mode == 'threeOut') ||
                (_modeFilter == 'normal' && r.mode != 'threeOut');
            final catOk =
                _categoryFilter == '전체' || r.category == _categoryFilter;
            return modeOk && catOk;
          }).toList();

          return RefreshIndicator(
            color: teamColor,
            onRefresh: () => quizProvider.fetchMyHistory(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 48),
              children: [
                _buildCareerHeroCard(history, teamColor),
                const SizedBox(height: 12),
                _buildFilterStrip(categories, teamColor, isDarkMode),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        '선택한 조건의 경기 기록이 없습니다.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDarkMode
                              ? Colors.white54
                              : const Color(0xFF647189),
                        ),
                      ),
                    ),
                  )
                else
                  ...filtered.map(
                    (result) => _buildBoxScoreCard(context, result, isDarkMode),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCareerHeroCard(List<QuizResultModel> history, Color teamColor) {
    int totalAb = 0;
    int totalHits = 0;
    int bestCombo = 0;
    for (final r in history) {
      totalAb += r.atBats;
      totalHits += r.hits;
      bestCombo = math.max(bestCombo, r.boxScore?.maxCombo ?? 0);
    }
    final careerAvg = totalAb > 0 ? totalHits / totalAb : 0.0;
    final careerAvgStr = QuizResultModel.formatBattingAverage(
      careerAvg,
      totalAb,
    );
    final recentFive = history.take(5).toList();
    final gradEnd =
        Color.lerp(teamColor, const Color(0xFF0D0C28), 0.42) ?? teamColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [teamColor, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAREER BATTING SUMMARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    careerAvgStr,
                    style: const TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFDE68A),
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${history.length}경기 · $totalAb타수 $totalHits안타',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '최고 연타',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🔥 $bestCombo연타',
                      style: const TextStyle(
                        fontFamily: 'kbo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recentFive.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '최근 5경기',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: recentFive.map((r) {
                        final isHot = r.battingAverage >= 0.7;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isHot
                                ? const Color(
                                    0xFFFDE68A,
                                  ).withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: isHot
                                ? Border.all(
                                    color: const Color(
                                      0xFFFDE68A,
                                    ).withValues(alpha: 0.5),
                                  )
                                : null,
                          ),
                          child: Text(
                            r.formattedBattingAverage,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isHot
                                  ? const Color(0xFFFDE68A)
                                  : Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterStrip(
    List<String> categories,
    Color teamColor,
    bool isDarkMode,
  ) {
    Widget buildChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? teamColor
                  : (isDarkMode ? const Color(0xFF151E32) : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? teamColor
                    : (isDarkMode ? Colors.white12 : const Color(0xFFE6EBF2)),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : const Color(0xFF647189)),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              buildChip(
                label: '전체',
                selected: _modeFilter == 'all',
                onTap: () => setState(() => _modeFilter = 'all'),
              ),
              buildChip(
                label: '⚾ 3아웃 모드',
                selected: _modeFilter == 'threeOut',
                onTap: () => setState(() => _modeFilter = 'threeOut'),
              ),
              buildChip(
                label: '📋 일반 모드',
                selected: _modeFilter == 'normal',
                onTap: () => setState(() => _modeFilter = 'normal'),
              ),
            ],
          ),
        ),
        if (categories.length > 2) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories
                  .map(
                    (cat) => buildChip(
                      label: cat,
                      selected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter = cat),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBoxScoreCard(
    BuildContext context,
    QuizResultModel result,
    bool isDarkMode,
  ) {
    final formattedDate = DateFormat(
      'yyyy.MM.dd HH:mm',
    ).format(result.completedAt);
    final avg = result.battingAverage;
    final avgStr = result.formattedBattingAverage;
    final maxCombo = result.boxScore?.maxCombo ?? 0;
    final isThreeOut = result.mode == 'threeOut';

    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeFg;
    final String gradeLabel;

    if (avg >= 0.7) {
      badgeBg = isDarkMode
          ? const Color(0xFF064E3B).withValues(alpha: 0.45)
          : const Color(0xFFECFDF5);
      badgeBorder = isDarkMode
          ? const Color(0xFF10B981).withValues(alpha: 0.45)
          : const Color(0xFFA7F3D0);
      badgeFg = isDarkMode ? const Color(0xFF34D399) : const Color(0xFF047857);
      gradeLabel = '맹타';
    } else if (avg >= 0.5) {
      badgeBg = isDarkMode
          ? const Color(0xFF7C2D12).withValues(alpha: 0.35)
          : const Color(0xFFFFF7ED);
      badgeBorder = isDarkMode
          ? const Color(0xFFF97316).withValues(alpha: 0.45)
          : const Color(0xFFFED7AA);
      badgeFg = isDarkMode ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
      gradeLabel = '안타';
    } else {
      badgeBg = isDarkMode
          ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
          : const Color(0xFFFEF2F2);
      badgeBorder = isDarkMode
          ? const Color(0xFFEF4444).withValues(alpha: 0.45)
          : const Color(0xFFFECACA);
      badgeFg = isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      gradeLabel = '분전';
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizDetailPage(result: result),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF151E32) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : const Color(0xFFE6EBF2),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF141B2D).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // 좌측 경기 타율 배지
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: badgeBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    avgStr,
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: badgeFg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gradeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // 중앙 박스스코어 메타
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.teamName != null
                              ? '${result.category} · ${result.teamName}'
                              : result.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF141B2D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white10
                              : const Color(0xFFF2F5FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isThreeOut ? '⚾ 3아웃' : '📋 일반',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white70
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    maxCombo > 0
                        ? '${result.atBats}타수 ${result.hits}안타 · 🔥 $maxCombo연타'
                        : '${result.atBats}타수 ${result.hits}안타',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.white70
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.white54
                          : const Color(0xFF647189),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
