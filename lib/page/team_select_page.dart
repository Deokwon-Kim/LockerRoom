import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/components/theme_tile.dart';
import 'package:lockerroom/const/color.dart';
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
    final isFeaturedSelected = selectedTeam == featuredTeam;
    final canSubmit = selectedTeam != null && !_isSaving;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: widget.isChanging
          ? AppBar(
              backgroundColor: BACKGROUND_COLOR,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: GRAYSCALE_LABEL_900,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: widget.isChanging ? 4 : 28),
            const Text(
              '응원하는 팀을 선택해주세요',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GRAYSCALE_LABEL_950,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '선택한 팀의 소식을 가장 먼저 받아보세요',
              style: TextStyle(
                fontSize: 14,
                color: GRAYSCALE_LABEL_600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () =>
                    context.read<TeamProvider>().selectTeam(featuredTeam),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 112,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: featuredTeam.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFeaturedSelected
                          ? const Color(0xFFFFBC02)
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isFeaturedSelected ? 0.12 : 0.05,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            featuredTeam.logoPath,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (isFeaturedSelected)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFFBC02),
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: otherTeams.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final team = otherTeams[index];
                  final isSelected = selectedTeam == team;
                  return ThemeTile(
                    teamModel: team,
                    isSelected: isSelected,
                    onTap: () => context.read<TeamProvider>().selectTeam(team),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: BACKGROUND_COLOR,
                border: Border(
                  top: BorderSide(color: GRAYSCALE_LABEL_100),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: canSubmit ? BUTTON : GRAYSCALE_LABEL_300,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canSubmit
                      ? [
                          BoxShadow(
                            color: BUTTON.withValues(alpha: 0.22),
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
                      height: 54,
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
                                widget.isChanging ? '변경하기' : '선택완료',
                                style: const TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
