import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/provider/team_news_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/notification_service.dart';
import 'package:lockerroom/widgets/team_news_section.dart';
import 'package:provider/provider.dart';

class TeamNewsListPage extends StatefulWidget {
  final TeamModel initialTeam;
  final NewsCategory? initialCategory;
  final String? highlightedArticleUrl;

  const TeamNewsListPage({
    super.key,
    required this.initialTeam,
    this.initialCategory,
    this.highlightedArticleUrl,
  });

  @override
  State<TeamNewsListPage> createState() => _TeamNewsListPageState();
}

class _TeamNewsListPageState extends State<TeamNewsListPage> {
  static const List<String> _kboTeams = [
    '두산',
    'LG',
    '기아',
    '삼성',
    'SSG',
    '한화',
    '롯데',
    'NC',
    'KT',
    '키움',
  ];

  late String _selectedTeamSymple;
  NewsCategory _selectedCategory = NewsCategory.all;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _teamScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTeamSymple = widget.initialTeam.symplename;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeamNewsProvider>().loadTeamNews(_selectedTeamSymple);
      _scrollToSelectedTeam(animate: false);
    });
  }

  void _scrollToSelectedTeam({bool animate = true}) {
    final index = _kboTeams.indexOf(_selectedTeamSymple);
    if (index < 0 || !_teamScrollController.hasClients) return;
    const itemExtent = 68.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final target = (index * itemExtent) - (screenWidth / 2) + (itemExtent / 2);
    final clamped = target.clamp(
      0.0,
      _teamScrollController.position.maxScrollExtent,
    );
    if (animate) {
      _teamScrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _teamScrollController.jumpTo(clamped);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _teamScrollController.dispose();
    super.dispose();
  }

  bool _isBreaking(TeamNewsModel article) {
    return DateTime.now().difference(article.publishedAt).inHours < 3;
  }

  int _countForCategory(List<TeamNewsModel> raw, NewsCategory category) {
    if (category == NewsCategory.all) return raw.length;
    return raw.where((e) => e.category == category).length;
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final activeTeam =
        teamProvider.findTeamByName(_selectedTeamSymple) ?? widget.initialTeam;
    final teamColor = activeTeam.color;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: WHITE,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: GRAYSCALE_LABEL_900,
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(activeTeam.logoPath, fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Text(
              '${activeTeam.symplename} 주요뉴스',
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: GRAYSCALE_LABEL_950,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: WHITE,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '구단 뉴스 알림 설정',
            onPressed: () => _openPushSettingsSheet(context, activeTeam),
            style: IconButton.styleFrom(
              backgroundColor: GRAYSCALE_LABEL_50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: teamColor,
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: '새로고침',
              onPressed: () => context.read<TeamNewsProvider>().loadTeamNews(
                _selectedTeamSymple,
                forceRefresh: true,
              ),
              style: IconButton.styleFrom(
                backgroundColor: GRAYSCALE_LABEL_50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: GRAYSCALE_LABEL_800,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<TeamNewsProvider>(
        builder: (context, np, _) {
          final raw = np.newsForTeam(_selectedTeamSymple);
          final isLoading = np.isLoading(_selectedTeamSymple);
          final error = np.errorForTeam(_selectedTeamSymple);

          final filtered = raw.where((item) {
            final matchCat =
                _selectedCategory == NewsCategory.all ||
                item.category == _selectedCategory;
            final matchQuery =
                _searchQuery.isEmpty ||
                item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.source.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchCat && matchQuery;
          }).toList();

          return Column(
            children: [
              // 상단 통합 컨트롤 패널 (구단 로고+sympleName / 검색바 / 카테고리 칩)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: WHITE,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BLACK.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
                child: Column(
                  children: [
                    // 1. 구단 전환 로고 + sympleName 바
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        controller: _teamScrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _kboTeams.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final symple = _kboTeams[index];
                          final team = teamProvider.findTeamByName(symple);
                          final displaySymple = team?.symplename ?? symple;
                          final isSelected = symple == _selectedTeamSymple;
                          final chipColor = team?.color ?? BUTTON;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (_selectedTeamSymple == symple) return;
                              setState(() => _selectedTeamSymple = symple);
                              context.read<TeamNewsProvider>().loadTeamNews(
                                symple,
                              );
                              _scrollToSelectedTeam();
                            },
                            child: SizedBox(
                              width: 58,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    width: 48,
                                    height: 48,
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? chipColor.withValues(alpha: 0.12)
                                          : GRAYSCALE_LABEL_50,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? chipColor
                                            : GRAYSCALE_LABEL_200,
                                        width: isSelected ? 2.2 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: chipColor.withValues(
                                                  alpha: 0.22,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: team != null
                                        ? Opacity(
                                            opacity: isSelected ? 1.0 : 0.65,
                                            child: Image.asset(
                                              team.logoPath,
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              displaySymple,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? chipColor
                                                    : GRAYSCALE_LABEL_700,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    displaySymple,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? GRAYSCALE_LABEL_950
                                          : GRAYSCALE_LABEL_500,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. 검색바
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        cursorColor: teamColor,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: GRAYSCALE_LABEL_950,
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: '${activeTeam.symplename} 선수명, 키워드로 뉴스 검색',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: GRAYSCALE_LABEL_400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: _searchQuery.isNotEmpty
                                ? teamColor
                                : GRAYSCALE_LABEL_500,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 18,
                                    color: GRAYSCALE_LABEL_400,
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: GRAYSCALE_LABEL_50,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: GRAYSCALE_LABEL_100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: teamColor,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. 카테고리 필터 칩 (건수 배지 포함)
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: NewsCategory.values.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = NewsCategory.values[index];
                          final selected = cat == _selectedCategory;
                          final count = _countForCategory(raw, cat);

                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? teamColor
                                    : GRAYSCALE_LABEL_50,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: selected
                                      ? teamColor
                                      : GRAYSCALE_LABEL_200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? WHITE
                                          : GRAYSCALE_LABEL_700,
                                    ),
                                  ),
                                  if (raw.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5.5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? WHITE.withValues(alpha: 0.22)
                                            : WHITE,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? WHITE
                                              : GRAYSCALE_LABEL_600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 4. 기사 리스트 영역
              Expanded(
                child: _buildArticleBody(
                  np: np,
                  raw: raw,
                  filtered: filtered,
                  isLoading: isLoading,
                  error: error,
                  activeTeam: activeTeam,
                  teamColor: teamColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildArticleBody({
    required TeamNewsProvider np,
    required List<TeamNewsModel> raw,
    required List<TeamNewsModel> filtered,
    required bool isLoading,
    required String? error,
    required TeamModel activeTeam,
    required Color teamColor,
  }) {
    if (isLoading && raw.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _NewsSkeletonCard(isFeatured: index == 0),
      );
    }

    if (error != null && raw.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: GRAYSCALE_LABEL_500,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    np.loadTeamNews(_selectedTeamSymple, forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamColor,
                  foregroundColor: WHITE,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      final hasFilter =
          _selectedCategory != NewsCategory.all || _searchQuery.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: GRAYSCALE_LABEL_100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.newspaper_rounded,
                  color: GRAYSCALE_LABEL_400,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '조건에 맞는 기사가 없습니다.',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: GRAYSCALE_LABEL_700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '다른 키워드나 카테고리를 선택해 보세요.',
                style: TextStyle(fontSize: 12.5, color: GRAYSCALE_LABEL_500),
              ),
              if (hasFilter) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = NewsCategory.all;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: teamColor,
                    backgroundColor: teamColor.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '필터 초기화',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final showFeatured = _searchQuery.isEmpty && filtered.isNotEmpty;

    return RefreshIndicator(
      color: teamColor,
      onRefresh: () => np.loadTeamNews(_selectedTeamSymple, forceRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final article = filtered[index];
          final isBreaking = _isBreaking(article);

          if (showFeatured && index == 0) {
            return _FeaturedNewsCard(
              article: article,
              team: activeTeam,
              teamColor: teamColor,
              isBreaking: isBreaking,
              onTap: () => openNewsArticle(context, article),
            );
          }

          final isHighlighted =
              widget.highlightedArticleUrl != null &&
              widget.highlightedArticleUrl == article.url;

          return Container(
            decoration: isHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: teamColor, width: 1.8),
                  )
                : null,
            child: _StandardNewsCard(
              article: article,
              teamColor: teamColor,
              isBreaking: isBreaking || isHighlighted,
              rankNumber: showFeatured ? index + 1 : null,
              onTap: () => openNewsArticle(context, article),
            ),
          );
        },
      ),
    );
  }

  void _openPushSettingsSheet(BuildContext context, TeamModel activeTeam) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamNewsPushSettingsSheet(team: activeTeam),
    );
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  final TeamNewsModel article;
  final TeamModel team;
  final Color teamColor;
  final bool isBreaking;
  final VoidCallback onTap;

  const _FeaturedNewsCard({
    required this.article,
    required this.team,
    required this.teamColor,
    required this.isBreaking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WHITE,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: teamColor.withValues(alpha: 0.25)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                teamColor.withValues(alpha: 0.07),
                WHITE,
                WHITE,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: teamColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: teamColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: WHITE),
                        SizedBox(width: 2),
                        Text(
                          'HEADLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: WHITE,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  NewsCategoryBadge(category: article.category),
                  if (isBreaking) ...[
                    const SizedBox(width: 6),
                    const _NewPulseBadge(),
                  ],
                  const Spacer(),
                  Text(
                    article.relativeTimeText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_950,
                  height: 1.42,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 11),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GRAYSCALE_LABEL_100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: GRAYSCALE_LABEL_50,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.article_outlined,
                            size: 13,
                            color: GRAYSCALE_LABEL_600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.source,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: GRAYSCALE_LABEL_700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '원문 읽기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: teamColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 13.5,
                      color: teamColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandardNewsCard extends StatelessWidget {
  final TeamNewsModel article;
  final Color teamColor;
  final bool isBreaking;
  final int? rankNumber;
  final VoidCallback onTap;

  const _StandardNewsCard({
    required this.article,
    required this.teamColor,
    required this.isBreaking,
    this.rankNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WHITE,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GRAYSCALE_LABEL_100),
            boxShadow: [
              BoxShadow(
                color: BLACK.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rankNumber != null && rankNumber! <= 5) ...[
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 11, top: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: teamColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$rankNumber',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: teamColor,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        NewsCategoryBadge(category: article.category),
                        if (isBreaking) ...[
                          const SizedBox(width: 6),
                          const _NewPulseBadge(),
                        ],
                        const Spacer(),
                        Text(
                          article.relativeTimeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: GRAYSCALE_LABEL_500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: GRAYSCALE_LABEL_950,
                        height: 1.42,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.feed_outlined,
                          size: 13,
                          color: GRAYSCALE_LABEL_400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            article.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: GRAYSCALE_LABEL_400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPulseBadge extends StatelessWidget {
  const _NewPulseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: ACCENT_CORAL,
          height: 1.1,
        ),
      ),
    );
  }
}

class _NewsSkeletonCard extends StatelessWidget {
  final bool isFeatured;

  const _NewsSkeletonCard({required this.isFeatured});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(isFeatured ? 20 : 18),
        border: Border.all(color: GRAYSCALE_LABEL_100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isFeatured ? 72 : 48,
                height: 18,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_100,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 12,
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: GRAYSCALE_LABEL_100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 210,
            height: 16,
            decoration: BoxDecoration(
              color: GRAYSCALE_LABEL_100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: GRAYSCALE_LABEL_50,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamNewsPushSettingsSheet extends StatefulWidget {
  final TeamModel team;

  const _TeamNewsPushSettingsSheet({required this.team});

  @override
  State<_TeamNewsPushSettingsSheet> createState() =>
      _TeamNewsPushSettingsSheetState();
}

class _TeamNewsPushSettingsSheetState
    extends State<_TeamNewsPushSettingsSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isNewsPushEnabled = true;
  bool _faEnabled = true;
  bool _tradeReleaseEnabled = true;
  bool _dndEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _isNewsPushEnabled = data['isNewsPushEnabled'] != false;
          _faEnabled = data['newsPushFaEnabled'] != false;
          _tradeReleaseEnabled =
              data['newsPushTradeEnabled'] != false &&
              data['newsPushReleaseEnabled'] != false;
          _dndEnabled = data['newsPushDndEnabled'] != false;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isNewsPushEnabled': _isNewsPushEnabled,
        'newsPushFaEnabled': _faEnabled,
        'newsPushTradeEnabled': _tradeReleaseEnabled,
        'newsPushReleaseEnabled': _tradeReleaseEnabled,
        'newsPushDndEnabled': _dndEnabled,
      }, SetOptions(merge: true));

      await NotificationService().syncTeamNewsTopic(
        widget.team.symplename,
        enabled: _isNewsPushEnabled,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = widget.team.color;
    final topicName =
        NotificationService.topicNameForTeam(widget.team.symplename) ??
        'team_news_none';

    return Container(
      decoration: const BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_200,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: teamColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(widget.team.logoPath, fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.team.symplename} 주요뉴스 푸시 설정',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: GRAYSCALE_LABEL_950,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '응원팀 변경 시 FCM 토픽 구독이 자동 동기화됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildToggleTile(
              title: '${widget.team.symplename} 이적·주요뉴스 알림',
              subtitle: 'FCM Topic: $topicName',
              value: _isNewsPushEnabled,
              activeColor: teamColor,
              onChanged: (v) {
                setState(() => _isNewsPushEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              title: 'FA 영입 / 재계약 속보',
              subtitle: 'FA 및 재계약 공식 발표 뉴스 우선 알림',
              value: _faEnabled,
              activeColor: teamColor,
              enabled: _isNewsPushEnabled,
              onChanged: (v) {
                setState(() => _faEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              title: '트레이드 / 방출(웨이버)',
              subtitle: '동일 이슈 중복 발송 방지 쿨다운 적용',
              value: _tradeReleaseEnabled,
              activeColor: teamColor,
              enabled: _isNewsPushEnabled,
              onChanged: (v) {
                setState(() => _tradeReleaseEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 8),
            _buildToggleTile(
              title: '야간 방해금지 시간',
              subtitle: '22:00 ~ 08:00 무음 처리 (피드에만 적재)',
              value: _dndEnabled,
              activeColor: teamColor,
              enabled: _isNewsPushEnabled,
              onChanged: (v) {
                setState(() => _dndEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GRAYSCALE_LABEL_100),
              ),
              child: Text(
                '구독 상태: $topicName [${_isNewsPushEnabled ? "ON" : "OFF"}] · 야간 방해금지 [${_dndEnabled ? "22:00~08:00" : "OFF"}]',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: GRAYSCALE_LABEL_700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: BACKGROUND_COLOR,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GRAYSCALE_LABEL_100),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: GRAYSCALE_LABEL_900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: activeColor,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
