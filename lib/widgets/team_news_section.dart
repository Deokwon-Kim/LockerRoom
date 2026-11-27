import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/page/news/team_news_detail_page.dart';
import 'package:lockerroom/page/news/team_news_list_page.dart';
import 'package:lockerroom/provider/team_news_provider.dart';
import 'package:provider/provider.dart';

/// 기사 원문을 앱 내부 상세 페이지(WebView)로 열기
Future<void> openNewsArticle(
  BuildContext context,
  TeamNewsModel article,
) async {
  if (article.url.trim().isEmpty) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TeamNewsDetailPage(article: article)),
  );
}

class NewsCategoryBadge extends StatelessWidget {
  final NewsCategory category;

  const NewsCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Color border;
    switch (category) {
      case NewsCategory.game:
        fg = const Color(0xFF1D4ED8);
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
      case NewsCategory.transfer:
        fg = const Color(0xFFBE123C);
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
      case NewsCategory.player:
      case NewsCategory.all:
        fg = const Color(0xFFB45309);
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.1,
        ),
      ),
    );
  }
}

class TeamNewsSection extends StatefulWidget {
  final TeamModel selectedTeam;

  const TeamNewsSection({super.key, required this.selectedTeam});

  @override
  State<TeamNewsSection> createState() => _TeamNewsSectionState();
}

class _TeamNewsSectionState extends State<TeamNewsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeamNewsProvider>().loadTeamNews(
        widget.selectedTeam.symplename,
      );
    });
  }

  @override
  void didUpdateWidget(covariant TeamNewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTeam.symplename != widget.selectedTeam.symplename) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TeamNewsProvider>().loadTeamNews(
          widget.selectedTeam.symplename,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.selectedTeam;
    final teamColor = team.color;

    return Consumer<TeamNewsProvider>(
      builder: (context, np, _) {
        final newsList = np.newsForTeam(team.symplename);
        final isLoading = np.isLoading(team.symplename);
        final error = np.errorForTeam(team.symplename);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.borderColor),
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
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: teamColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(team.logoPath, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${team.symplename} 주요뉴스',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: WHITE,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamNewsListPage(initialTeam: team),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '전체보기',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: context.textMuted,
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading && newsList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: teamColor,
                      ),
                    ),
                  ),
                )
              else if (error != null && newsList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BACKGROUND_COLOR,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => np.loadTeamNews(
                          team.symplename,
                          forceRefresh: true,
                        ),
                        child: Text(
                          '다시 시도',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: teamColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (newsList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '현재 표시할 최신 뉴스가 없습니다.',
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                  ),
                )
              else
                _RollingNewsCard(articles: newsList, teamColor: teamColor),
            ],
          ),
        );
      },
    );
  }
}

class _RollingNewsCard extends StatefulWidget {
  final List<TeamNewsModel> articles;
  final Color teamColor;

  const _RollingNewsCard({required this.articles, required this.teamColor});

  @override
  State<_RollingNewsCard> createState() => _RollingNewsCardState();
}

class _RollingNewsCardState extends State<_RollingNewsCard> {
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _RollingNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articles != widget.articles) {
      _currentIndex = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.articles.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.articles.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.articles[_currentIndex % widget.articles.length];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openNewsArticle(context, article),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: context.surfaceAltColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final isIncoming = child.key == ValueKey(article.id);
              final offsetAnimation = Tween<Offset>(
                begin: isIncoming
                    ? const Offset(0, 1.0)
                    : const Offset(0, -1.0),
                end: Offset.zero,
              ).animate(animation);
              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Row(
              key: ValueKey(article.id),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          NewsCategoryBadge(category: article.category),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${article.source} · ${article.relativeTimeText}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context
                                  .readableColor(widget.teamColor)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_currentIndex + 1}/${widget.articles.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.readableColor(widget.teamColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                          height: 1.38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
