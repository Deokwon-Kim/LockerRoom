import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/model/team_news_model.dart';
import 'package:lockerroom/provider/team_news_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/widgets/team_news_section.dart';
import 'package:provider/provider.dart';

class TeamNewsListPage extends StatefulWidget {
  final TeamModel initialTeam;

  const TeamNewsListPage({super.key, required this.initialTeam});

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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTeamSymple = widget.initialTeam.symplename;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeamNewsProvider>().loadTeamNews(_selectedTeamSymple);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '📰 ${activeTeam.symplename} 주요뉴스',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: GRAYSCALE_LABEL_950,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<TeamNewsProvider>().loadTeamNews(
              _selectedTeamSymple,
              forceRefresh: true,
            ),
            icon: const Icon(Icons.refresh_rounded, color: GRAYSCALE_LABEL_800),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 구단 전환 로고 칩 바
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _kboTeams.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final symple = _kboTeams[index];
                final team = teamProvider.findTeamByName(symple);
                final isSelected = symple == _selectedTeamSymple;
                final chipColor = team?.color ?? BUTTON;
                return GestureDetector(
                  onTap: () {
                    if (_selectedTeamSymple == symple) return;
                    setState(() => _selectedTeamSymple = symple);
                    context.read<TeamNewsProvider>().loadTeamNews(symple);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? chipColor.withValues(alpha: 0.12)
                          : WHITE,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? chipColor : GRAYSCALE_LABEL_200,
                        width: isSelected ? 2.2 : 1.0,
                      ),
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
                              symple,
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
              cursorColor: BUTTON,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: '선수명, 키워드로 뉴스 검색',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: GRAYSCALE_LABEL_400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: GRAYSCALE_LABEL_500,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: GRAYSCALE_LABEL_500,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: WHITE,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: teamColor, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. 카테고리 필터 칩
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
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? teamColor : WHITE,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? teamColor : GRAYSCALE_LABEL_200,
                      ),
                    ),
                    child: Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? WHITE : GRAYSCALE_LABEL_700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 4. 기사 리스트
          Expanded(
            child: Consumer<TeamNewsProvider>(
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
                      item.title.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      item.source.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                  return matchCat && matchQuery;
                }).toList();

                if (isLoading && raw.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: teamColor),
                  );
                }

                if (error != null && raw.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: GRAYSCALE_LABEL_600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => np.loadTeamNews(
                              _selectedTeamSymple,
                              forceRefresh: true,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: teamColor,
                              foregroundColor: WHITE,
                            ),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      '조건에 맞는 기사가 없습니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: teamColor,
                  onRefresh: () =>
                      np.loadTeamNews(_selectedTeamSymple, forceRefresh: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = filtered[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openNewsArticle(context, article),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  NewsCategoryBadge(category: article.category),
                                  const Spacer(),
                                  Text(
                                    '${article.source} · ${article.relativeTimeText}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: GRAYSCALE_LABEL_500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                article.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GRAYSCALE_LABEL_950,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
