import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class TeamSelectPage extends StatefulWidget {
  final bool isChanging;
  const TeamSelectPage({super.key, this.isChanging = false});

  @override
  State<TeamSelectPage> createState() => _TeamSelectPageState();
}

class _TeamSelectPageState extends State<TeamSelectPage> {
  bool _isSaving = false;

  Future<void> _selectTeam(BuildContext context, String teamName) async {
    if (_isSaving) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 상태를 확인할 수 없습니다.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'team': teamName,
      }, SetOptions(merge: true));

      if (!mounted) return;
      await Provider.of<TeamProvider>(context, listen: false).setTeam(teamName);

      if (!mounted) return;
      if (widget.isChanging) {
        Navigator.pop(context, teamName);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomTabBar()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팀 저장에 실패했습니다. 잠시 후 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = Provider.of<TeamProvider>(context).getTeam('team');
    final teamState = context.watch<TeamProvider>();
    final selectedTeam = teamState.selectedTeam;

    if (widget.isChanging && selectedTeam == null && teamState.team != null) {
      final initial = teamState.findTeamByName(teamState.team!);
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<TeamProvider>().selectTeam(initial);
        });
      }
    }

    final excludedTeamNames = <String>[
      '일본',
      '체코',
      '대만',
      '쿠바',
      '호주',
      '도미니카',
      '태국',
      '홍콩',
      '중국',
      'LAD',
      'SD',
      'SK와이번스',
      '넥센히어로즈',
      '미국',
      '이스라엘',
      '멕시코',
      '인도네시아',
      '베네수엘라',
      '파키스탄',
      '네덜란드',
      '캐나다',
    ];

    final selectableTeams = teamProvider
        .where((t) => !excludedTeamNames.contains(t.name))
        .toList();

    final featuredTeam = selectableTeams.firstWhere(
      (t) => t.name == "대한민국",
      orElse: () => selectableTeams[0],
    );
    final otherTeams = selectableTeams.where((t) => t != featuredTeam).toList();
    final List<TeamModel> dockTeams = [...otherTeams, featuredTeam];
    final TeamModel displayTeam =
        selectedTeam ?? (dockTeams.isNotEmpty ? dockTeams.first : featuredTeam);
    final bool canSubmit = selectedTeam != null && !_isSaving;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isChanging)
                    Positioned(
                      left: 4,
                      top: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: GRAYSCALE_LABEL_900,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '응원하는 팀을 선택해주세요',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: GRAYSCALE_LABEL_950,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '선택한 팀의 소식을 가장 먼저 받아보세요',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: GRAYSCALE_LABEL_600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 상단 히어로 선택 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      displayTeam.color,
                      Color.lerp(displayTeam.color, Colors.black, 0.35) ??
                          displayTeam.color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: displayTeam.color.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selectedTeam != null
                            ? 'MY TEAM · ${displayTeam.stadium}'
                            : 'PREVIEW · ${displayTeam.stadium}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WHITE,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (displayTeam.name == '대한민국')
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            displayTeam.logoPath,
                            width: 136,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Image.asset(
                        displayTeam.logoPath,
                        width: 92,
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      displayTeam.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: WHITE,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '이 구단의 소식과 직관·퀴즈 테마가 적용됩니다',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: WHITE.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 하단 4열 원형/카드 아이콘 독 (노스크롤)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const int cols = 4;
                  final int rows = (dockTeams.length / cols).ceil().clamp(1, 6);
                  const double hPad = 16;
                  const double crossSpacing = 9;
                  const double mainSpacing = 9;
                  const double bottomPad = 6;
                  final double tileWidth =
                      (constraints.maxWidth -
                          hPad * 2 -
                          crossSpacing * (cols - 1)) /
                      cols;
                  final double tileHeight =
                      ((constraints.maxHeight -
                                  bottomPad -
                                  mainSpacing * (rows - 1)) /
                              rows)
                          .clamp(58.0, 140.0);
                  final double ratio = (tileWidth / tileHeight).clamp(0.7, 1.8);
                  final double iconSize = (tileHeight * 0.56).clamp(32.0, 52.0);

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      hPad,
                      0,
                      hPad,
                      bottomPad,
                    ),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dockTeams.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: crossSpacing,
                      mainAxisSpacing: mainSpacing,
                      childAspectRatio: ratio,
                    ),
                    itemBuilder: (context, index) {
                      final team = dockTeams[index];
                      final isSelected = selectedTeam == team;
                      final isKorea = team.name == '대한민국';
                      return GestureDetector(
                        onTap: () =>
                            context.read<TeamProvider>().selectTeam(team),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? team.color.withValues(alpha: 0.08)
                                : WHITE,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? team.color
                                  : GRAYSCALE_LABEL_200,
                              width: isSelected ? 2.2 : 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isKorea)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    team.logoPath,
                                    width: iconSize,
                                    height: iconSize * 0.68,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Image.asset(
                                  team.logoPath,
                                  width: iconSize,
                                  height: iconSize,
                                  fit: BoxFit.contain,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                team.symplename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: isSelected
                                      ? team.color
                                      : GRAYSCALE_LABEL_800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: BACKGROUND_COLOR,
                border: Border(top: BorderSide(color: GRAYSCALE_LABEL_100)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: canSubmit ? selectedTeam.color : GRAYSCALE_LABEL_300,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canSubmit
                      ? [
                          BoxShadow(
                            color: selectedTeam.color.withValues(alpha: 0.24),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canSubmit
                        ? () => _selectTeam(context, selectedTeam.name)
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: WHITE,
                                ),
                              )
                            : Text(
                                selectedTeam != null
                                    ? '${selectedTeam.name} ${widget.isChanging ? '변경하기' : '선택완료'}'
                                    : '응원하는 팀을 선택해주세요',
                                style: const TextStyle(
                                  color: WHITE,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
