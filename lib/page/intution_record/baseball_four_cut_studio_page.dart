import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/widgets/team_wordmark.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

enum FourCutLayout {
  strip('1×4 스트립', isPro: false),
  grid('2×2 그리드', isPro: false),
  ticket('매치 티켓', isPro: false),
  scoreboard('전광판 라이브', isPro: true),
  broadcast('중계 ON-AIR', isPro: true),
  stitch('야구공 스티치', isPro: true),
  ground('그라운드 뷰', isPro: true),
  jersey('유니폼 저지', isPro: true);

  final String label;
  final bool isPro;
  const FourCutLayout(this.label, {required this.isPro});
}

enum FourCutTheme {
  team('구단 컬러'),
  dark('다크 필름'),
  white('클린 화이트'),
  cream('레트로 크림');

  final String label;
  const FourCutTheme(this.label);
}

class BaseballFourCutStudioPage extends StatefulWidget {
  final TeamModel? initialTeam;
  final String? opponentName;
  final String? stadium;
  final String? dateText;
  final String? myScore;
  final String? oppScore;
  final bool returnFileOnConfirm;

  const BaseballFourCutStudioPage({
    super.key,
    this.initialTeam,
    this.opponentName,
    this.stadium,
    this.dateText,
    this.myScore,
    this.oppScore,
    this.returnFileOnConfirm = false,
  });

  @override
  State<BaseballFourCutStudioPage> createState() =>
      _BaseballFourCutStudioPageState();
}

class _BaseballFourCutStudioPageState extends State<BaseballFourCutStudioPage> {
  final GlobalKey _captureKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _commentController;

  final List<File?> _photos = [null, null, null, null];
  TeamModel? _selectedTeam;
  WordmarkMode _wordmarkMode = WordmarkMode.english;
  FourCutLayout _layout = FourCutLayout.grid;
  FourCutTheme _theme = FourCutTheme.team;
  String _selectedSticker = '🔥 승요 인증';
  int _activeTab = 0; // 0: 레이아웃, 1: 컬러·구단, 2: 스티커·문구
  bool _isExporting = false;

  static const List<String> _stickers = [
    '',
    '🔥 승요 인증',
    '😭 패요지만 잼',
    '🎉 끝내기 승!',
    '⚾ 오늘도 직관',
    '🍗 치맥 직관',
    '📣 목청 터짐',
    '🌅 낭만 야구장',
    '☔ 우취 피함',
    '🏆 직관완료',
    '💙 내 팀 최고',
    '📸 인생샷 각',
    '🎫 티켓 인증',
    '👑 직관왕',
    '✨ 가을야구',
  ];

  static const List<String> _quickComments = [
    '가을야구 직관 완승 💙',
    '오늘도 승요 인증 🔥',
    '직관은 역시 직관이야 ⚾',
    '패요지만 너무 재밌었다 😭',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.initialTeam;
    _commentController = TextEditingController(text: '가을야구 직관 완승 💙');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  int get _filledPhotoCount => _photos.where((f) => f != null).length;

  Future<void> _pickSinglePhoto(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text(
                  '카메라로 직접 촬영',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text(
                  '앨범에서 사진 선택',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _photos[index] = File(picked.path);
    });
  }

  Future<void> _captureNextEmptySlot() async {
    final emptyIdx = _photos.indexWhere((f) => f == null);
    final targetIdx = emptyIdx == -1 ? 0 : emptyIdx;
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _photos[targetIdx] = File(picked.path);
    });
  }

  Future<void> _pickAllFourPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (int i = 0; i < 4; i++) {
        if (i < picked.length) {
          _photos[i] = File(picked[i].path);
        }
      }
    });
  }

  void _clearAllPhotos() {
    setState(() {
      for (int i = 0; i < 4; i++) {
        _photos[i] = null;
      }
    });
  }

  Future<File?> _renderFourCutToFile() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ilu_fourcut_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _handleConfirm() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await _renderFourCutToFile();
      if (file == null || !mounted) return;

      if (widget.returnFileOnConfirm) {
        Navigator.pop(context, file);
        return;
      }

      await Gal.putImage(file.path);
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.success,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관 네컷이 갤러리에 저장되었어요!'),
      );
    } catch (e) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('네컷 이미지 생성에 실패했습니다.'),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _buildMetaLine() {
    final teamName = _selectedTeam?.symplename ?? '삼성';
    final opp = (widget.opponentName?.trim().isNotEmpty ?? false)
        ? widget.opponentName!.trim()
        : '상대팀';
    final myS = (widget.myScore?.trim().isNotEmpty ?? false)
        ? widget.myScore!.trim()
        : '6';
    final oppS = (widget.oppScore?.trim().isNotEmpty ?? false)
        ? widget.oppScore!.trim()
        : '1';
    final date = (widget.dateText?.trim().isNotEmpty ?? false)
        ? widget.dateText!.trim()
        : '2026.11.01';
    return '$teamName $myS : $oppS $opp · $date';
  }

  String _buildResultBadge() {
    final my = int.tryParse(widget.myScore?.trim() ?? '');
    final opp = int.tryParse(widget.oppScore?.trim() ?? '');
    if (my != null && opp != null) {
      if (my > opp) return 'WIN';
      if (my < opp) return 'LOSE';
      return 'DRAW';
    }
    return 'WIN';
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final isAdmin = context.watch<UserProvider>().isAdmin;
    final team = _selectedTeam ?? teamProvider.selectedTeam;
    final accentColor = team?.color ?? BUTTON;

    // 개발자(isAdmin) 계정에만 PRO 레이아웃 5종 노출, 일반 유저는 기본 3종만 표시
    final availableLayouts = FourCutLayout.values
        .where((l) => !l.isPro || isAdmin)
        .toList();

    final availableTeams = teamProvider
        .getTeam('team')
        .where(
          (t) => const [
            '삼성',
            'LG',
            '두산',
            '기아',
            'SSG',
            '한화',
            '롯데',
            'NC',
            'KT',
            '키움',
            '대한민국',
          ].contains(t.symplename),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1120),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '직관 네컷 스튜디오',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _filledPhotoCount == 4
                    ? const Color(0xFF10B981).withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _filledPhotoCount == 4
                      ? const Color(0xFF34D399)
                      : Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                '$_filledPhotoCount/4',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _filledPhotoCount == 4
                      ? const Color(0xFF6EE7B7)
                      : Colors.white70,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isExporting ? null : _handleConfirm,
              style: TextButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 7,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isExporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.returnFileOnConfirm ? '적용하기' : '저장하기',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 스튜디오 스테이지 (항상 고정되어 실시간 프리뷰)
          Expanded(
            child: Stack(
              children: [
                // 구단 컬러 은은한 스튜디오 스포트라이트 배경
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.95,
                        colors: [
                          accentColor.withValues(alpha: 0.24),
                          const Color(0xFF0B1120),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 46),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: _buildFourCutFrame(team),
                      ),
                    ),
                  ),
                ),
                // 하단 플로팅 사진 액션 바
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStageActionPill(
                        icon: Icons.camera_alt_outlined,
                        label: '바로 촬영',
                        onTap: _captureNextEmptySlot,
                        accentColor: accentColor,
                      ),
                      const SizedBox(width: 8),
                      _buildStageActionPill(
                        icon: Icons.photo_library_outlined,
                        label: '사진 4장 한 번에',
                        onTap: _pickAllFourPhotos,
                        accentColor: accentColor,
                      ),
                      if (_filledPhotoCount > 0) ...[
                        const SizedBox(width: 8),
                        _buildStageActionPill(
                          icon: Icons.refresh_rounded,
                          label: '비우기',
                          onTap: _clearAllPhotos,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 하단 스튜디오 에디터 도크
          _buildBottomEditorDock(
            context,
            team: team,
            accentColor: accentColor,
            isAdmin: isAdmin,
            availableLayouts: availableLayouts,
            availableTeams: availableTeams,
          ),
        ],
      ),
    );
  }

  Widget _buildStageActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accentColor != null
                  ? accentColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomEditorDock(
    BuildContext context, {
    required TeamModel? team,
    required Color accentColor,
    required bool isAdmin,
    required List<FourCutLayout> availableLayouts,
    required List<TeamModel> availableTeams,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: math.max(bottomInset, 10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 + 탭 바
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildDockTab(
                    index: 0,
                    icon: Icons.dashboard_customize_rounded,
                    label: isAdmin ? '레이아웃 (PRO)' : '레이아웃',
                    accentColor: accentColor,
                  ),
                  _buildDockTab(
                    index: 1,
                    icon: Icons.palette_outlined,
                    label: '컬러 · 구단',
                    accentColor: accentColor,
                  ),
                  _buildDockTab(
                    index: 2,
                    icon: Icons.auto_awesome_outlined,
                    label: '스티커 · 문구',
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 선택된 탭 컨텐츠
          SizedBox(
            height: 186,
            child: IndexedStack(
              index: _activeTab,
              children: [
                _buildLayoutTab(availableLayouts, accentColor),
                _buildThemeAndTeamTab(team, availableTeams, accentColor),
                _buildStickerAndCommentTab(accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockTab({
    required int index,
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    final selected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : context.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutTab(
    List<FourCutLayout> availableLayouts,
    Color accentColor,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      scrollDirection: Axis.horizontal,
      itemCount: availableLayouts.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, idx) {
        final layout = availableLayouts[idx];
        final selected = _layout == layout;
        return GestureDetector(
          onTap: () => setState(() => _layout = layout),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 96,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: 0.12)
                  : context.bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accentColor : context.borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: layout.isPro
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox(height: 13),
                ),
                Expanded(
                  child: Center(
                    child: _buildLayoutThumbnail(layout, selected, accentColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  layout.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accentColor : context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutThumbnail(
    FourCutLayout layout,
    bool selected,
    Color accentColor,
  ) {
    final cellColor = selected
        ? accentColor.withValues(alpha: 0.72)
        : context.textSecondary.withValues(alpha: 0.28);

    Widget box({double? w, double? h, double r = 3}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    switch (layout) {
      case FourCutLayout.strip:
        return SizedBox(
          width: 30,
          height: 82,
          child: Column(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(child: box()),
                if (i < 3) const SizedBox(height: 3),
              ],
            ],
          ),
        );
      case FourCutLayout.grid:
      case FourCutLayout.scoreboard:
      case FourCutLayout.stitch:
      case FourCutLayout.jersey:
        return SizedBox(
          width: 58,
          height: 64,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(width: 4),
                    Expanded(child: box()),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(width: 4),
                    Expanded(child: box()),
                  ],
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.ticket:
        return SizedBox(
          width: 58,
          height: 70,
          child: Column(
            children: [
              box(h: 10, r: 2),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(width: 4),
                    Expanded(child: box()),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(width: 4),
                    Expanded(child: box()),
                  ],
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.broadcast:
        return SizedBox(
          width: 64,
          height: 64,
          child: Row(
            children: [
              Expanded(flex: 14, child: box()),
              const SizedBox(width: 3),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(height: 3),
                    Expanded(child: box()),
                    const SizedBox(height: 3),
                    Expanded(child: box()),
                  ],
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.ground:
        return SizedBox(
          width: 64,
          height: 66,
          child: Column(
            children: [
              Expanded(flex: 15, child: box()),
              const SizedBox(height: 3),
              Expanded(
                flex: 9,
                child: Row(
                  children: [
                    Expanded(child: box()),
                    const SizedBox(width: 3),
                    Expanded(child: box()),
                    const SizedBox(width: 3),
                    Expanded(child: box()),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildThemeAndTeamTab(
    TeamModel? team,
    List<TeamModel> availableTeams,
    Color accentColor,
  ) {
    final swatchColors = {
      FourCutTheme.team: accentColor,
      FourCutTheme.dark: const Color(0xFF111827),
      FourCutTheme.white: Colors.white,
      FourCutTheme.cream: const Color(0xFFF6F1E7),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프레임 컬러 + 워드마크 모드
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: FourCutTheme.values.map((t) {
                    final selected = _theme == t;
                    final swatch = swatchColors[t]!;
                    return GestureDetector(
                      onTap: () => setState(() => _theme = t),
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: swatch,
                              border: Border.all(
                                color: selected
                                    ? accentColor
                                    : context.borderColor,
                                width: selected ? 2.5 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color:
                                        t == FourCutTheme.white ||
                                            t == FourCutTheme.cream
                                        ? Colors.black87
                                        : Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: selected
                                  ? context.textPrimary
                                  : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 구단 로고 선택
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableTeams.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final t = availableTeams[idx];
                final selected = (team?.symplename ?? '') == t.symplename;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTeam = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? t.color.withValues(alpha: 0.14)
                          : context.bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? t.color : context.borderColor,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset(t.logoPath, width: 24, height: 24),
                        const SizedBox(width: 6),
                        Text(
                          t.symplename,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? t.color : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 워드마크 영문 / 한글 / 숨김 세그먼트
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.bgColor,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                _buildWordmarkSegment(
                  '영문 로고',
                  WordmarkMode.english,
                  accentColor,
                ),
                _buildWordmarkSegment(
                  '한글 로고',
                  WordmarkMode.korean,
                  accentColor,
                ),
                _buildWordmarkSegment(
                  '로고 숨김',
                  WordmarkMode.hidden,
                  accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmarkSegment(
    String label,
    WordmarkMode mode,
    Color accentColor,
  ) {
    final selected = _wordmarkMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _wordmarkMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerAndCommentTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 코멘트 입력창
          TextField(
            controller: _commentController,
            maxLength: 24,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 13, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: '한 줄 코멘트를 입력하세요 (최대 24자)',
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: accentColor,
              ),
              filled: true,
              fillColor: context.bgColor,
              counterText: '',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 추천 문구 퀵칩
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickComments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final text = _quickComments[idx];
                return GestureDetector(
                  onTap: () {
                    _commentController.text = text;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.bgColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 스티커 14종 가로 스크롤
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stickers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, idx) {
                final s = _stickers[idx];
                final selected = _selectedSticker == s;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSticker = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? accentColor : context.bgColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? accentColor : context.borderColor,
                      ),
                    ),
                    child: Text(
                      s.isEmpty ? '스티커 없음' : s,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : context.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourCutFrame(TeamModel? team) {
    final teamColor = team?.color ?? const Color(0xFF074CA1);
    final isLightFrame =
        _theme == FourCutTheme.white || _theme == FourCutTheme.cream;
    final fgColor = isLightFrame ? const Color(0xFF111827) : Colors.white;
    final isStrip = _layout == FourCutLayout.strip;

    BoxDecoration frameDecoration;
    switch (_theme) {
      case FourCutTheme.team:
        frameDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(teamColor, Colors.white, 0.14) ?? teamColor,
              teamColor,
              Color.lerp(teamColor, Colors.black, 0.35) ?? teamColor,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        );
        break;
      case FourCutTheme.dark:
        frameDecoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF171F30), Color(0xFF090D16)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        );
        break;
      case FourCutTheme.white:
        frameDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        );
        break;
      case FourCutTheme.cream:
        frameDecoration = BoxDecoration(
          color: const Color(0xFFF6F1E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E0D3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        );
        break;
    }

    final frameWidth = isStrip ? 196.0 : 292.0;
    final watermarkPath =
        team?.logoPath ?? 'assets/images/korean_logo/lions.png';

    return Container(
      width: frameWidth,
      decoration: frameDecoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_layout == FourCutLayout.jersey)
            Positioned.fill(
              child: CustomPaint(
                painter: _JerseyPinstripePainter(
                  lineColor: isLightFrame
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 워드마크 + 날짜
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TeamWordmark(
                        team: team,
                        mode: _wordmarkMode,
                        textColor: fgColor,
                        compact: isStrip,
                      ),
                    ),
                    if (!isStrip)
                      Text(
                        widget.dateText ?? '2026.11.01',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: fgColor.withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),

                // 티켓 헤더 또는 PRO 배너
                if (_layout == FourCutLayout.ticket) ...[
                  _buildTicketHeader(fgColor, team),
                  const SizedBox(height: 8),
                ] else if (_layout.isPro) ...[
                  _buildProBanner(fgColor, isLightFrame),
                  const SizedBox(height: 8),
                ],

                // 4컷 사진 영역 (스티커는 절대 사진을 가리지 않음)
                _buildCutsStage(isLightFrame, fgColor),

                // 하단 푸터 (워터마크 + 메타 + 코멘트 + 스티커 + 앱 로고)
                const SizedBox(height: 9),
                Stack(
                  children: [
                    Positioned(
                      right: 2,
                      top: -2,
                      child: Opacity(
                        opacity: 0.16,
                        child: Image.asset(
                          watermarkPath,
                          width: isStrip ? 30 : 38,
                          height: isStrip ? 30 : 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _buildMetaLine(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: fgColor.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _buildResultBadge(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: fgColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (isStrip) ...[
                          Text(
                            _commentController.text.trim().isEmpty
                                ? ' '
                                : _commentController.text.trim(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: fgColor,
                            ),
                          ),
                          if (_selectedSticker.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            _buildStickerPill(),
                          ],
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _commentController.text.trim().isEmpty
                                      ? ' '
                                      : _commentController.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: fgColor,
                                  ),
                                ),
                              ),
                              if (_selectedSticker.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _buildStickerPill(),
                              ],
                            ],
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: fgColor.withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Image.asset(
                                      'assets/images/applogo/ilu_app_icon.png',
                                      width: 15,
                                      height: 15,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ILU BASEBALL FOUR-CUT',
                                    style: TextStyle(
                                      fontSize: isStrip ? 8.5 : 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: fgColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                              if (!isStrip)
                                Text(
                                  'ILU APP',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: fgColor.withValues(alpha: 0.65),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        _selectedSticker,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildTicketHeader(Color fgColor, TeamModel? team) {
    final teamName = team?.symplename ?? '삼성';
    final opp = (widget.opponentName?.trim().isNotEmpty ?? false)
        ? widget.opponentName!.trim()
        : '기아';
    final stadium = (widget.stadium?.trim().isNotEmpty ?? false)
        ? widget.stadium!.trim()
        : (team?.stadium ?? '야구장');
    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: fgColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$teamName vs $opp',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: fgColor,
                ),
              ),
              Text(
                '${widget.dateText ?? '2026.11.01'} · $stadium',
                style: TextStyle(
                  fontSize: 10,
                  color: fgColor.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _buildResultBadge(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner(Color fgColor, bool isLightFrame) {
    switch (_layout) {
      case FourCutLayout.scoreboard:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '● LIVE  9회말 · 직관 승리',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4ADE80),
                ),
              ),
              Text(
                'R6 H11 E0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.broadcast:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border(
              left: BorderSide(color: Color(0xFFEF4444), width: 4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '● ON AIR',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ILU SPORTS HD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Text(
                "TODAY'S MVP",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFFACC15),
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.stitch:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isLightFrame
                ? const Color(0xFFFEF2F2)
                : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLightFrame
                  ? const Color(0xFFFECACA)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚾ OFFICIAL GAME BALL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isLightFrame ? const Color(0xFF991B1B) : fgColor,
                ),
              ),
              Text(
                'STADIUM ED.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isLightFrame ? const Color(0xFF991B1B) : fgColor,
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.ground:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF6EE7B7).withValues(alpha: 0.5),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🏟️ MATCHDAY POSTER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFECFDF5),
                ),
              ),
              Text(
                'INFIELD VIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFECFDF5),
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.jersey:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isLightFrame
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: fgColor, width: 3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '👕 JERSEY NO.10',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: fgColor,
                ),
              ),
              Text(
                'WINNING STREAK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: fgColor,
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCutsStage(bool isLightFrame, Color fgColor) {
    switch (_layout) {
      case FourCutLayout.strip:
        return Column(
          children: [
            for (int i = 0; i < 4; i++) ...[
              _buildCutSlot(i, height: 92),
              if (i < 3) const SizedBox(height: 6),
            ],
          ],
        );
      case FourCutLayout.scoreboard:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF070B14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: _build2x2Grid(height: 160, gap: 5, radius: 5),
        );
      case FourCutLayout.broadcast:
        return Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFEF4444), width: 3),
            ),
          ),
          child: SizedBox(
            height: 330,
            child: Row(
              children: [
                Expanded(
                  flex: 14,
                  child: _buildCutSlot(0, height: 330, radius: 8),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      Expanded(child: _buildCutSlot(1, radius: 6)),
                      const SizedBox(height: 5),
                      Expanded(child: _buildCutSlot(2, radius: 6)),
                      const SizedBox(height: 5),
                      Expanded(child: _buildCutSlot(3, radius: 6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case FourCutLayout.stitch:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLightFrame
                  ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              _build2x2Grid(height: 160, gap: 16, radius: 10),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _BaseballStitchPainter()),
                ),
              ),
            ],
          ),
        );
      case FourCutLayout.ground:
        return Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLightFrame
                  ? const Color(0xFF10B981)
                  : Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
          ),
          child: Column(
            children: [
              _buildCutSlot(0, height: 196, radius: 9),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildCutSlot(1, height: 128, radius: 7)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildCutSlot(2, height: 128, radius: 7)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildCutSlot(3, height: 128, radius: 7)),
                ],
              ),
            ],
          ),
        );
      case FourCutLayout.jersey:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: fgColor.withValues(alpha: 0.8), width: 3),
              bottom: BorderSide(
                color: fgColor.withValues(alpha: 0.8),
                width: 3,
              ),
            ),
          ),
          child: _build2x2Grid(height: 160, gap: 6, radius: 7),
        );
      case FourCutLayout.ticket:
        return _build2x2Grid(height: 158, gap: 6, radius: 9);
      case FourCutLayout.grid:
        return _build2x2Grid(height: 176, gap: 7, radius: 9);
    }
  }

  Widget _build2x2Grid({
    required double height,
    required double gap,
    required double radius,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCutSlot(0, height: height, radius: radius),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildCutSlot(1, height: height, radius: radius),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _buildCutSlot(2, height: height, radius: radius),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _buildCutSlot(3, height: height, radius: radius),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCutSlot(int index, {double? height, double radius = 9}) {
    final file = _photos[index];
    const placeholders = ['경기장 전경', '유니폼 인증', '치맥 타임', '승리 세리머니'];
    return GestureDetector(
      onTap: () => _pickSinglePhoto(index),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: file == null
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1,
                )
              : null,
          gradient: file == null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null)
              Image.file(file, fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        size: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      placeholders[index],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              top: 5,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '0${index + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _JerseyPinstripePainter extends CustomPainter {
  final Color lineColor;
  const _JerseyPinstripePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2;
    for (double x = 14; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _JerseyPinstripePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

class _BaseballStitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      seamPaint,
    );

    final stitchPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (double y = 8; y < size.height - 8; y += 16) {
      final path = Path()
        ..moveTo(centerX - 5, y)
        ..lineTo(centerX, y + math.min(5.0, size.height - y))
        ..lineTo(centerX + 5, y);
      canvas.drawPath(path, stitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
