import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/mate_checklist_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class MateChecklistPage extends StatefulWidget {
  final int initialTab;

  const MateChecklistPage({super.key, this.initialTab = 0});

  @override
  State<MateChecklistPage> createState() => _MateChecklistPageState();
}

class _MateChecklistPageState extends State<MateChecklistPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  late int _tabIndex;
  late MateChecklistModel _checklist;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
    final teamName =
        context.read<TeamProvider>().selectedTeam?.symplename ?? '두산';
    _checklist = MateChecklistModel.defaults(team: teamName);
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final raw = doc.data()?['mateChecklist'];
        if (raw is Map<String, dynamic> && mounted) {
          setState(() {
            _checklist = MateChecklistModel.fromMap(raw);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveChecklist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'mateChecklist': _checklist.toMap(),
        'mateChecklistUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('직관메이트 체크리스트가 저장되었습니다!')));
      Navigator.pop(context, _checklist);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveShareImage() async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null) return;
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('체크리스트 카드가 갤러리에 저장되었습니다!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 저장 실패: $e')));
    }
  }

  Future<void> _shareImage() async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ilu_mate_checklist_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '나의 야구 직관메이트 체크리스트 #iLU');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
    }
  }

  void _toggleOption(MateQuestionDef q, String option) {
    final current = List<String>.from(_checklist.answers[q.key] ?? const []);
    if (q.multiSelect) {
      if (current.contains(option)) {
        if (current.length > 1) current.remove(option);
      } else {
        current.add(option);
      }
    } else {
      current
        ..clear()
        ..add(option);
    }
    final nextAnswers = Map<String, List<String>>.from(_checklist.answers);
    nextAnswers[q.key] = current;
    setState(() {
      _checklist = _checklist.copyWith(answers: nextAnswers);
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(teamColor);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          '직관메이트 체크리스트',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveChecklist,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : Column(
              children: [
                // Tab Switcher
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopTabBtn(
                          label: '1. 체크리스트 작성',
                          selected: _tabIndex == 0,
                          accentColor: accentColor,
                          onTap: () => setState(() => _tabIndex = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TopTabBtn(
                          label: '2. 공유 카드',
                          selected: _tabIndex == 1,
                          accentColor: accentColor,
                          onTap: () => setState(() => _tabIndex = 1),
                        ),
                      ),
                    ],
                  ),
                ),

                // Highlighter Color Palette
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '형광펜 색상',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        ...MateChecklistModel.highlightPresets.map((hex) {
                          final c = Color(hex);
                          final isSelected =
                              _checklist.highlightColorValue == hex;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _checklist = _checklist.copyWith(
                                highlightColorValue: hex,
                              );
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              margin: const EdgeInsets.only(left: 8),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? context.textPrimary
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _tabIndex == 0
                      ? _buildFormTab()
                      : _buildShareCardTab(accentColor),
                ),
              ],
            ),
    );
  }

  Widget _buildFormTab() {
    final hiColor = _checklist.highlightColor;
    final accentTextColor = context.isDarkMode
        ? hiColor
        : context.readableColor(hiColor);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: accentTextColor.withValues(
              alpha: context.isDarkMode ? 0.14 : 0.10,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentTextColor.withValues(
                alpha: context.isDarkMode ? 0.36 : 0.28,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_pin_rounded, size: 20, color: accentTextColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 기본 정보 (본인 기준)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '찾는 상대 조건이 아니라, 나의 응원 구단·연령대·성별을 선택해 주세요.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSingleSelectCard(
          title: '내 응원 구단',
          badgeText: '내 정보',
          options: MateChecklistModel.teamOptions,
          selected: _checklist.team,
          hiColor: hiColor,
          onSelect: (v) =>
              setState(() => _checklist = _checklist.copyWith(team: v)),
        ),
        const SizedBox(height: 10),
        _buildSingleSelectCard(
          title: '내 연령대',
          badgeText: '내 정보',
          options: MateChecklistModel.ageOptions,
          selected: _checklist.age,
          hiColor: hiColor,
          onSelect: (v) =>
              setState(() => _checklist = _checklist.copyWith(age: v)),
        ),
        const SizedBox(height: 10),
        _buildSingleSelectCard(
          title: '내 성별',
          badgeText: '내 정보',
          options: MateChecklistModel.genderOptions,
          selected: _checklist.gender,
          hiColor: hiColor,
          onSelect: (v) =>
              setState(() => _checklist = _checklist.copyWith(gender: v)),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.sports_baseball_rounded,
                size: 15,
                color: accentTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                '나의 직관 스타일',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ...MateChecklistModel.questions.map((q) {
          final selectedList = _checklist.answers[q.key] ?? const [];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          q.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        q.multiSelect ? '중복 가능' : '1개 선택',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: q.options.map((opt) {
                      final isSel = selectedList.contains(opt);
                      return _HighlightOptionChip(
                        label: opt,
                        selected: isSel,
                        hiColor: hiColor,
                        onTap: () => _toggleOption(q, opt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSingleSelectCard({
    required String title,
    String? badgeText,
    required List<String> options,
    required String selected,
    required Color hiColor,
    required ValueChanged<String> onSelect,
  }) {
    final badgeColor = context.isDarkMode
        ? hiColor
        : context.readableColor(hiColor);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(
                      alpha: context.isDarkMode ? 0.16 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (opt) => _HighlightOptionChip(
                    label: opt,
                    selected: selected == opt,
                    hiColor: hiColor,
                    onTap: () => onSelect(opt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCardTab(Color accentColor) {
    final hiBg = _checklist.highlightColor.withValues(alpha: 0.34);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Screenshot(
          controller: _screenshotController,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0F172A), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center Logo Watermark
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 0.06,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(42),
                          child: Image.asset(
                            'assets/images/applogo/ilu_app_icon.png',
                            width: 210,
                            height: 210,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '⚾ 야구 직관메이트 체크리스트',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(height: 2, color: const Color(0xFF0F172A)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetaHighlightPill(
                            text: '응원팀: ${_checklist.team}',
                            bg: hiBg,
                          ),
                          const SizedBox(width: 8),
                          _MetaHighlightPill(
                            text: '연령: ${_checklist.age}',
                            bg: hiBg,
                          ),
                          const SizedBox(width: 8),
                          _MetaHighlightPill(text: _checklist.gender, bg: hiBg),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...MateChecklistModel.questions.map((q) {
                        final ans = (_checklist.answers[q.key] ?? const [])
                            .join(' · ');
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  q.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: hiBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ans.isEmpty ? '-' : ans,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      // Bottom-right App Logo Watermark
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.asset(
                              'assets/images/applogo/ilu_app_icon.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'made with iLU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                            ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saveShareImage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: context.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.download_rounded, color: context.textPrimary),
                label: Text(
                  '갤러리 저장',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: WHITE,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'SNS 공유하기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopTabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TopTabBtn({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor : context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : context.borderColor,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? selectedTextColor : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color hiColor;
  final VoidCallback onTap;

  const _HighlightOptionChip({
    required this.label,
    required this.selected,
    required this.hiColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? hiColor.withValues(alpha: 0.30)
              : context.surfaceAltColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? hiColor : context.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? context.textPrimary : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetaHighlightPill extends StatelessWidget {
  final String text;
  final Color bg;

  const _MetaHighlightPill({required this.text, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
