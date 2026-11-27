import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/comment_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/page/intution_record/_ticket_stub_tile.dart';
import 'package:lockerroom/page/intution_record/baseball_four_cut_studio_page.dart';
import 'package:lockerroom/page/intution_record/ticker_camera_scan_page.dart';
import 'package:lockerroom/provider/comment_provider.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:lockerroom/widgets/stadium_receipt_card.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordDetailPage extends StatefulWidget {
  final AttendanceModel? attendanceModel;
  final String gameId;
  final String? ownerUserId;
  const IntutionRecordDetailPage({
    super.key,
    required this.gameId,
    this.attendanceModel,
    this.ownerUserId,
  });

  @override
  State<IntutionRecordDetailPage> createState() =>
      _IntutionRecordDetailPageState();
}

class _IntutionRecordDetailPageState extends State<IntutionRecordDetailPage> {
  late final PageController _newImagesPageController;
  late final PageController _existingImagesPageController;
  final ValueNotifier<int> _currentImageIndex = ValueNotifier<int>(0);
  bool _isEditing = false;

  String get _targetOwnerId =>
      widget.ownerUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwner {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return false;
    return widget.ownerUserId == null || widget.ownerUserId == currentUid;
  }

  Future<AttendanceModel?> _loadAttendance() async {
    final targetUid = _targetOwnerId;
    if (targetUid.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('attendances')
        .doc(widget.gameId)
        .get();

    if (!doc.exists) return null;

    return AttendanceModel.fromDoc(doc);
  }

  String _logoForTeam(TeamProvider tp, String nameOrSymple) {
    final bySymple = tp.findTeamByName(nameOrSymple);
    if (bySymple != null) return bySymple.calenderLogo;
    final list = tp.getTeam('team');
    final byFull = list.where((t) => t.name == nameOrSymple).toList();
    return byFull.isNotEmpty ? byFull.first.calenderLogo : context.appLogoAsset;
  }

  // 날짜 포맷 변환: "2025.01.15" -> "2025년 1월 15일"
  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        return '$year년 $month월 $day일';
      }
    } catch (e) {
      // 파싱 실패 시 원본 반환
    }
    return dateStr;
  }

  // gameId로 스케줄 정보 찾기
  Future<ScheduleModel?> _findScheduleByGameId(String gameId) async {
    try {
      final schedules = await ScheduleService().loadSchedules();
      return schedules.firstWhere(
        (s) => s.gameId == gameId,
        orElse: () => schedules.first,
      );
    } catch (e) {
      return null;
    }
  }

  // 취소된 경기인지 확인
  bool _isCancelledGame(ScheduleModel? schedule) {
    if (schedule == null) return false;
    final statusUpper = schedule.status.toUpperCase();
    return schedule.status == '경기취소' || statusUpper.startsWith('CANCELLED');
  }

  late final TextEditingController _myTeamScore;
  late final TextEditingController _oppTeamScore;
  late final TextEditingController _memoController;
  late final TextEditingController _seatController;
  late final TextEditingController _ticketPriceController;
  late final TextEditingController _foodCostController;
  late final TextEditingController _goodsCostController;
  List<String> _foodItems = [];
  Map<String, int> _foodPrices = {};
  List<String> _goodsItems = [];
  Map<String, int> _goodsPrices = {};
  late final Future<AttendanceModel?> _attendanceFuture;
  bool _controllersInitialized = false;
  AttendanceModel? _loadedAttendance;
  bool _isPublic = true;
  late final CommentProvider _commentProvider;
  final TextEditingController _commentController = TextEditingController();
  String? _replyParentId;
  String? _replyToUserName;
  String? _replyToUserId;
  bool _replyIsToReply = false;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _newImagesPageController = PageController();
    _existingImagesPageController = PageController();
    _attendanceFuture = _loadAttendance();
    _commentProvider = context.read<CommentProvider>();
    if (_targetOwnerId.isNotEmpty) {
      _commentProvider.subscribeAttendanceComments(
        _targetOwnerId,
        widget.gameId,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IntutionRecordProvider>().resetState();
    });
    // 초기값 설정 (attendanceModel이 있으면 사용, 없으면 빈 문자열)
    _myTeamScore = TextEditingController(
      text: widget.attendanceModel?.myScore.toString() ?? '',
    );
    _oppTeamScore = TextEditingController(
      text: widget.attendanceModel?.opponentScore.toString() ?? '',
    );
    _memoController = TextEditingController(
      text: widget.attendanceModel?.memo ?? '',
    );
    _seatController = TextEditingController(
      text: widget.attendanceModel?.seat ?? '',
    );
    _ticketPriceController = TextEditingController(
      text:
          (widget.attendanceModel?.ticketPrice != null &&
              widget.attendanceModel!.ticketPrice! > 0)
          ? widget.attendanceModel!.ticketPrice.toString()
          : '',
    );
    _foodCostController = TextEditingController(
      text:
          (widget.attendanceModel?.foodCost != null &&
              widget.attendanceModel!.foodCost! > 0)
          ? widget.attendanceModel!.foodCost.toString()
          : '',
    );
    _foodItems = List<String>.from(widget.attendanceModel?.foodItems ?? []);
    _foodPrices = Map<String, int>.from(
      widget.attendanceModel?.foodPrices ?? {},
    );
    _goodsCostController = TextEditingController(
      text:
          (widget.attendanceModel?.goodsCost != null &&
              widget.attendanceModel!.goodsCost! > 0)
          ? widget.attendanceModel!.goodsCost.toString()
          : '',
    );
    _goodsItems = List<String>.from(widget.attendanceModel?.goodsItems ?? []);
    _goodsPrices = Map<String, int>.from(
      widget.attendanceModel?.goodsPrices ?? {},
    );
  }

  @override
  void dispose() {
    if (_targetOwnerId.isNotEmpty) {
      _commentProvider.cancelAttendanceSubscription(
        _targetOwnerId,
        widget.gameId,
      );
    }
    _commentController.dispose();
    _myTeamScore.dispose();
    _oppTeamScore.dispose();
    _memoController.dispose();
    _seatController.dispose();
    _ticketPriceController.dispose();
    _foodCostController.dispose();
    _goodsCostController.dispose();
    _newImagesPageController.dispose();
    _existingImagesPageController.dispose();
    _currentImageIndex.dispose();
    super.dispose();
  }

  // FutureBuilder에서 데이터를 불러온 후 컨트롤러 값 업데이트
  void _updateControllers(AttendanceModel attendance) {
    if (!_controllersInitialized) {
      _myTeamScore.text = attendance.myScore.toString();
      _oppTeamScore.text = attendance.opponentScore.toString();
      _memoController.text = attendance.memo ?? '';
      _seatController.text = attendance.seat ?? '';
      _ticketPriceController.text =
          (attendance.ticketPrice != null && attendance.ticketPrice! > 0)
          ? attendance.ticketPrice.toString()
          : '';
      _foodCostController.text =
          (attendance.foodCost != null && attendance.foodCost! > 0)
          ? attendance.foodCost.toString()
          : '';
      _foodItems = List<String>.from(attendance.foodItems);
      _foodPrices = Map<String, int>.from(attendance.foodPrices);
      _goodsCostController.text =
          (attendance.goodsCost != null && attendance.goodsCost! > 0)
          ? attendance.goodsCost.toString()
          : '';
      _goodsItems = List<String>.from(attendance.goodsItems);
      _goodsPrices = Map<String, int>.from(attendance.goodsPrices);
      _isPublic = attendance.isPublic;
      _controllersInitialized = true;
    }
    _loadedAttendance = attendance;
  }

  Future<void> _confirmAndDelete(AttendanceModel attendance) async {
    final confirmed = await showDeleteAttendanceConfirmDialog(context);
    if (!confirmed || !mounted) return;

    final ok = await context.read<IntutionRecordProvider>().deleteRecord(
      attendance,
    );
    if (!mounted) return;
    if (ok) {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관기록이 삭제되었습니다'),
      );
      Navigator.of(context).pop(true);
    } else {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관기록 삭제에 실패했습니다'),
      );
    }
  }

  Future<void> _scanTicketForSeatAndPrice() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (ctx) => TicketScanProvider(
            scheduleProvider: ctx.read<ScheduleProvider>(),
          ),
          child: const TickerCameraScanPage(returnOnlySeatAndPrice: true),
        ),
      ),
    );

    if (!mounted || result == null) return;

    final scannedSeat = (result['seat'] as String?)?.trim() ?? '';
    final scannedPrice = (result['ticketPrice'] as int?) ?? 0;

    if (scannedSeat.isNotEmpty) {
      _seatController.text = scannedSeat;
    }
    if (scannedPrice > 0) {
      _ticketPriceController.text = '$scannedPrice';
    }

    if (scannedSeat.isNotEmpty || scannedPrice > 0) {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('티켓에서 좌석·금액 정보를 불러왔습니다'),
      );
    } else {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('티켓에서 좌석·금액을 인식하지 못했습니다. 직접 입력해 주세요.'),
      );
    }
  }

  String _formatPrice(int price) {
    if (price <= 0) return '미입력';
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }

  String _shortStadium(String stadium) {
    return stadium
        .replaceAll('야구장', '')
        .replaceAll('구장', '')
        .replaceAll('파크', '')
        .trim();
  }

  Future<void> _saveEdits(IntutionRecordProvider irp) async {
    final myScoreText = _myTeamScore.text.trim();
    final oppScoreText = _oppTeamScore.text.trim();

    if (myScoreText.isEmpty || oppScoreText.isEmpty) {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('점수를 입력해주세요'),
      );
      return;
    }

    final myScore = int.tryParse(myScoreText);
    final oppScore = int.tryParse(oppScoreText);

    if (myScore == null || oppScore == null) {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('점수를 입력해주세요'),
      );
      return;
    }

    final parsedPrice =
        int.tryParse(_ticketPriceController.text.replaceAll(',', '').trim()) ??
        0;
    final parsedFoodCost =
        int.tryParse(_foodCostController.text.replaceAll(',', '').trim()) ?? 0;
    final parsedGoodsCost =
        int.tryParse(_goodsCostController.text.replaceAll(',', '').trim()) ?? 0;

    final success = await irp.updateRecord(
      gameId: widget.gameId,
      newMyscore: myScore,
      newOppScore: oppScore,
      newMemo: _memoController.text.trim(),
      newSeat: _seatController.text.trim(),
      newTicketPrice: parsedPrice,
      newFoodCost: parsedFoodCost,
      newFoodItems: _foodItems,
      newFoodPrices: _foodPrices,
      newGoodsCost: parsedGoodsCost,
      newGoodsItems: _goodsItems,
      newGoodsPrices: _goodsPrices,
      newImages: irp.image.isNotEmpty ? irp.image : null,
      oldImageUrls: _loadedAttendance?.imageUrls,
      newIsPublic: _isPublic,
    );

    if (!mounted) return;
    if (success) {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관기록이 수정되었습니다'),
      );
      Navigator.of(context).pop(true);
    } else {
      toastification.show(
        context: context,
        alignment: Alignment.bottomCenter,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('직관기록 수정실패'),
      );
    }
  }

  Future<void> _confirmAndShareToFeed(AttendanceModel attendance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '피드에 직관 인증 공유',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ctx.textPrimary,
          ),
        ),
        content: Text(
          '이 직관기록(스코어·구장·사진)을 피드에 공유할까요?\n다른 팬들과 댓글로 소통할 수 있습니다.',
          style: TextStyle(fontSize: 13.5, color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: ctx.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.isDarkMode
                  ? const Color(0xFF60A5FA)
                  : BUTTON,
              foregroundColor: ctx.isDarkMode ? Colors.black : WHITE,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('공유하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context
        .read<IntutionRecordProvider>()
        .shareAttendanceToFeed(attendance);
    if (!mounted) return;
    toastification.show(
      context: context,
      alignment: Alignment.bottomCenter,
      type: ok ? ToastificationType.success : ToastificationType.error,
      autoCloseDuration: const Duration(seconds: 2),
      title: Text(ok ? '피드에 직관 인증을 공유했어요!' : '피드 공유에 실패했습니다'),
    );
  }

  Widget _buildMagazineView(
    BuildContext context,
    AttendanceModel attendance,
    TeamProvider teamProvider,
  ) {
    if (!_isOwner && !attendance.isPublic) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: GRAYSCALE_LABEL_400,
              ),
              const SizedBox(height: 12),
              const Text(
                '비공개 직관기록입니다',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '작성자가 공개로 설정한 직관기록만 열람할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_500),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    final accentColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final myTeamModel = teamProvider.findTeamByName(attendance.myTeam);
    final myTeamLogo = _logoForTeam(teamProvider, attendance.myTeam);
    final oppTeamLogo = attendance.oppTeam != null
        ? _logoForTeam(teamProvider, attendance.oppTeam!)
        : context.appLogoAsset;

    final myScore = attendance.myScore;
    final oppScore = attendance.opponentScore;
    final isWin = myScore > oppScore;
    final isDraw = myScore == oppScore;
    final resultLabel = isWin ? '승리' : (isDraw ? '무승부' : '패배');
    final resultColor = isWin
        ? accentColor
        : (isDraw ? GRAYSCALE_LABEL_600 : Colors.redAccent);
    final seat = (attendance.seat ?? '').trim();
    final memo = (attendance.memo ?? '').trim();
    final stadiumShort = _shortStadium(attendance.stadium);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) 상단 풀 블리드 히어로 사진 + 오버레이 네비게이션
          SizedBox(
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (attendance.imageUrls.isNotEmpty)
                  PageView.builder(
                    controller: _existingImagesPageController,
                    onPageChanged: (index) {
                      _currentImageIndex.value = index;
                    },
                    itemCount: attendance.imageUrls.length,
                    itemBuilder: (context, imgIndex) {
                      return CachedNetworkImage(
                        imageUrl: attendance.imageUrls[imgIndex],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: accentColor.withValues(alpha: 0.15),
                        ),
                        errorWidget: (context, error, stackTrace) =>
                            Container(color: accentColor),
                      );
                    },
                  )
                else
                  Container(
                    color: accentColor,
                    alignment: Alignment.center,
                    child: myTeamModel != null
                        ? Opacity(
                            opacity: 0.25,
                            child: Image.asset(
                              myTeamModel.logoPath,
                              height: 110,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                // 상단 뒤로가기 & 수정 버튼
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 14,
                                color: WHITE,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '목록',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isOwner)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BaseballFourCutStudioPage(
                                      initialTeam: myTeamModel,
                                      opponentName: attendance.oppTeam,
                                      stadium: attendance.stadium,
                                      dateText: attendance.date,
                                      myScore: attendance.myScore.toString(),
                                      oppScore: attendance.opponentScore
                                          .toString(),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.grid_view_rounded,
                                      size: 14,
                                      color: WHITE,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '네컷',
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _confirmAndShareToFeed(attendance),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.campaign_outlined,
                                      size: 15,
                                      color: WHITE,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '피드 공유',
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _confirmAndDelete(attendance),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: Color(0xFFFF8A80),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _isEditing = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: WHITE,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '수정',
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (attendance.imageUrls.length > 1)
                  Positioned(
                    bottom: 38,
                    right: 16,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentImageIndex,
                      builder: (context, idx, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${idx + 1} / ${attendance.imageUrls.length}',
                            style: const TextStyle(
                              color: WHITE,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 2) 오버랩 스코어보드 카드 + 2열 메타 그리드 + 감성 메모 일기 카드
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.isDarkMode ? 0.25 : 0.06,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        FutureBuilder<ScheduleModel?>(
                          future: _findScheduleByGameId(widget.gameId),
                          builder: (context, schedSnap) {
                            final schedule = schedSnap.data;
                            final dh = schedule?.doubleHeaderNo?.trim() ?? '';
                            final timeText = attendance.time.trim();
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_formatDate(attendance.date)}${timeText.isNotEmpty ? ' $timeText' : ''} · ${attendance.stadium}${dh.isNotEmpty ? ' ($dh)' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: resultColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    resultLabel,
                                    style: const TextStyle(
                                      color: WHITE,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '응원 팀',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Image.asset(
                                    myTeamLogo,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    attendance.myTeam,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '$myScore : $oppScore',
                                style: GoogleFonts.roboto(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: context.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '상대 팀',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Image.asset(
                                    oppTeamLogo,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    attendance.oppTeam ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
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
                  const SizedBox(height: 12),

                  // 3) 티켓 메타 정보 (좌석 정보 전체 너비 + 티켓 금액)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                '좌석 정보',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                seat.isNotEmpty ? seat : '미입력',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  color: seat.isNotEmpty
                                      ? context.textPrimary
                                      : context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            height: 1,
                            color: context.dividerColor,
                          ),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                '티켓 금액',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatPrice(attendance.ticketPrice ?? 0),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: (attendance.ticketPrice ?? 0) > 0
                                      ? context.textPrimary
                                      : context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (attendance.foodItems.isNotEmpty ||
                            (attendance.foodCost ?? 0) > 0) ...[
                          Divider(height: 20, color: context.dividerColor),
                          Row(
                            children: [
                              SizedBox(
                                width: 68,
                                child: Text(
                                  '구장 먹거리',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  [
                                    if (attendance.foodItems.isNotEmpty)
                                      attendance.foodItems.join('·'),
                                    if ((attendance.foodCost ?? 0) > 0)
                                      _formatPrice(attendance.foodCost!),
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (attendance.goodsItems.isNotEmpty ||
                            (attendance.goodsCost ?? 0) > 0) ...[
                          Divider(height: 20, color: context.dividerColor),
                          Row(
                            children: [
                              SizedBox(
                                width: 68,
                                child: Text(
                                  '유니폼·굿즈',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  [
                                    if (attendance.goodsItems.isNotEmpty)
                                      attendance.goodsItems.join('·'),
                                    if ((attendance.goodsCost ?? 0) > 0)
                                      _formatPrice(attendance.goodsCost!),
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4) 줄 노트 감성 직관 일기 카드 (투명 배경 + NanumPenScript)
                  Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CustomPaint(
                        painter: _RuledPaperPainter(
                          lineColor: context.borderColor.withValues(alpha: 0.7),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '⚾ 오늘의 직관 일기',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '$stadiumShort에서의 기록',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                memo.isNotEmpty
                                    ? '"$memo"'
                                    : '"작성된 직관 메모가 없어요. 수정 버튼을 눌러 기록해보세요!"',
                                style: GoogleFonts.nanumPenScript(
                                  fontSize: 22,
                                  height: 1.35,
                                  color: memo.isNotEmpty
                                      ? context.textPrimary
                                      : context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAttendanceCommentsSection(
                    context,
                    attendance,
                    accentColor,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAttendanceComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment || _targetOwnerId.isEmpty) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSendingComment = true);
    try {
      final up = context.read<UserProvider>();
      final finalText =
          (_replyIsToReply &&
              _replyToUserName != null &&
              !text.startsWith('@$_replyToUserName'))
          ? '@$_replyToUserName $text'
          : text;
      final comment = CommentModel(
        id: '',
        postId: _commentProvider.attendancePostKey(
          _targetOwnerId,
          widget.gameId,
        ),
        userId: currentUser.uid,
        userName: up.nickname ?? currentUser.displayName ?? '야구팬',
        text: finalText,
        reComments: _replyParentId ?? '',
        createdAt: DateTime.now(),
      );
      await _commentProvider.addAttendanceCommentAndNotify(
        ownerUserId: _targetOwnerId,
        gameId: widget.gameId,
        comment: comment,
        currentUserId: currentUser.uid,
        parentCommentOwnerId: _replyToUserId,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _replyParentId = null;
        _replyToUserName = null;
        _replyToUserId = null;
        _replyIsToReply = false;
      });
    } catch (_) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('댓글 등록에 실패했습니다'),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Widget _buildAttendanceCommentsSection(
    BuildContext context,
    AttendanceModel attendance,
    Color accentColor,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final comments = _targetOwnerId.isEmpty
        ? const <CommentModel>[]
        : context.watch<CommentProvider>().getAttendanceComments(
            _targetOwnerId,
            widget.gameId,
          );
    final parents = comments.where((c) => c.reComments.isEmpty).toList();
    final Map<String, List<CommentModel>> repliesMap = {};
    for (final c in comments.where((c) => c.reComments.isNotEmpty)) {
      repliesMap.putIfAbsent(c.reComments, () => []).add(c);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '💬 댓글 ${comments.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                attendance.isPublic ? '전체 공개' : '비공개',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '첫 댓글로 직관 이야기를 나눠보세요!',
                style: TextStyle(fontSize: 13, color: context.textMuted),
              ),
            )
          else
            ...parents.map((parent) {
              final replies = repliesMap[parent.id] ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttendanceCommentItem(
                    parent,
                    currentUid: currentUid,
                    accentColor: accentColor,
                    isReply: false,
                  ),
                  ...replies.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: _buildAttendanceCommentItem(
                        r,
                        currentUid: currentUid,
                        accentColor: accentColor,
                        isReply: true,
                      ),
                    ),
                  ),
                ],
              );
            }),
          if (_replyToUserName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.surfaceAltColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '$_replyToUserName님에게 답글 작성 중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.readableColor(accentColor),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyParentId = null;
                      _replyToUserName = null;
                      _replyToUserId = null;
                      _replyIsToReply = false;
                    }),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  cursorColor: context.readableColor(accentColor),
                  style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isOwner
                        ? '댓글 또는 답글을 입력하세요'
                        : '이 직관기록에 댓글을 남겨보세요',
                    hintStyle: TextStyle(color: context.textMuted),
                    filled: true,
                    fillColor: context.surfaceAltColor,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSendingComment ? null : _submitAttendanceComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: WHITE,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  '등록',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCommentItem(
    CommentModel c, {
    required String? currentUid,
    required Color accentColor,
    required bool isReply,
  }) {
    final canDelete =
        currentUid != null &&
        (c.userId == currentUid || _targetOwnerId == currentUid);
    return Container(
      margin: EdgeInsets.symmetric(vertical: isReply ? 4 : 6),
      padding: isReply
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : EdgeInsets.zero,
      decoration: isReply
          ? BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: context.borderColor, width: 2.5),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isReply) ...[
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 15,
                  color: context.textMuted,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                c.userName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              if (c.userId == _targetOwnerId) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: context
                        .readableColor(accentColor)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '작성자',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.readableColor(accentColor),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _replyParentId = isReply ? c.reComments : c.id;
                  _replyToUserName = c.userName;
                  _replyToUserId = c.userId;
                  _replyIsToReply = isReply;
                }),
                child: const Text(
                  '답글',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _commentProvider.deleteAttendanceComment(
                    ownerUserId: _targetOwnerId,
                    gameId: widget.gameId,
                    commentId: c.id,
                  ),
                  child: const Text(
                    '삭제',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: RED_DANGER_TEXT_50,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          _buildMentionText(c.text, accentColor),
        ],
      ),
    );
  }

  Widget _buildMentionText(String text, Color mentionColor) {
    final match = RegExp(r'^(@\S+)\s+(.*)$', dotAll: true).firstMatch(text);
    if (match == null) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: GRAYSCALE_LABEL_800,
          height: 1.4,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${match.group(1)} ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mentionColor,
              height: 1.4,
            ),
          ),
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              fontSize: 13,
              color: GRAYSCALE_LABEL_800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _isEditing
          ? AppBar(
              backgroundColor: context.bgColor,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: context.textPrimary),
                onPressed: () => setState(() => _isEditing = false),
              ),
              title: Text(
                '직관 기록 수정',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              scrolledUnderElevation: 0,
              actions: [
                Consumer2<IntutionRecordProvider, TeamProvider>(
                  builder: (context, irp, tp, child) {
                    final accentColor = tp.selectedTeam?.color ?? BUTTON;
                    final isDisabled =
                        irp.isLoding || irp.saving || irp.isImagePicking;
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: TextButton(
                        onPressed: isDisabled ? null : () => _saveEdits(irp),
                        style: TextButton.styleFrom(
                          backgroundColor: isDisabled
                              ? GRAYSCALE_LABEL_200
                              : accentColor,
                          foregroundColor: WHITE,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: (irp.isLoding && !irp.saving)
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: accentColor,
                                ),
                              )
                            : Text(
                                '저장',
                                style: TextStyle(
                                  color: isDisabled
                                      ? GRAYSCALE_LABEL_500
                                      : WHITE,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: FutureBuilder<AttendanceModel?>(
              future: _attendanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(child: Text('기록을 찾을 수 없습니다.'));
                }

                final attendance = snapshot.data!;
                // 데이터를 불러온 후 컨트롤러 값 업데이트
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateControllers(attendance);
                });

                return Consumer<TeamProvider>(
                  builder: (context, teamProvider, child) {
                    if (!_isEditing) {
                      return _buildMagazineView(
                        context,
                        attendance,
                        teamProvider,
                      );
                    }

                    final accentColor =
                        teamProvider.selectedTeam?.color ?? BUTTON;
                    final myTeamLogo = _logoForTeam(
                      teamProvider,
                      attendance.myTeam,
                    );
                    final oppTeamLogo = attendance.oppTeam != null
                        ? _logoForTeam(teamProvider, attendance.oppTeam!)
                        : context.appLogoAsset;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 날짜 카드
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: WHITE,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: GRAYSCALE_LABEL_200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 17,
                                  color: GRAYSCALE_LABEL_600,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _formatDate(attendance.date),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: GRAYSCALE_LABEL_950,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildSectionTitle('경기 정보'),
                          const SizedBox(height: 10),
                          // 통합 경기 정보 + 스코어 카드
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: WHITE,
                              border: Border.all(color: GRAYSCALE_LABEL_200),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                FutureBuilder<ScheduleModel?>(
                                  future: _findScheduleByGameId(widget.gameId),
                                  builder: (context, schedSnap) {
                                    final schedule = schedSnap.data;
                                    final dh =
                                        schedule?.doubleHeaderNo?.trim() ?? '';
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: GRAYSCALE_LABEL_100,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            attendance.stadium,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: GRAYSCALE_LABEL_700,
                                            ),
                                          ),
                                        ),
                                        if (dh.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: BUTTON.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              dh,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: BUTTON,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (_isCancelledGame(schedule)) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: RED_DANGER_SURFACE_5,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: RED_DANGER_BORDER_10,
                                              ),
                                            ),
                                            child: const Text(
                                              '경기취소',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: RED_DANGER_TEXT_50,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            '응원 팀',
                                            style: TextStyle(
                                              color: GRAYSCALE_LABEL_500,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Image.asset(
                                            myTeamLogo,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.contain,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            attendance.myTeam,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: GRAYSCALE_LABEL_950,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GRAYSCALE_LABEL_50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'VS',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: GRAYSCALE_LABEL_500,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            '상대 팀',
                                            style: TextStyle(
                                              color: GRAYSCALE_LABEL_500,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Image.asset(
                                            oppTeamLogo,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.contain,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            attendance.oppTeam ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: GRAYSCALE_LABEL_950,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(
                                  height: 1,
                                  color: GRAYSCALE_LABEL_100,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 88,
                                      child: TextFormField(
                                        cursorColor: BUTTON,
                                        controller: _myTeamScore,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: GRAYSCALE_LABEL_950,
                                        ),
                                        decoration:
                                            _buildInputDecoration(
                                              hintText: attendance.myTeam,
                                            ).copyWith(
                                              fillColor: BACKGROUND_COLOR,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                            ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: GRAYSCALE_LABEL_400,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 88,
                                      child: TextFormField(
                                        cursorColor: BUTTON,
                                        controller: _oppTeamScore,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: GRAYSCALE_LABEL_950,
                                        ),
                                        decoration:
                                            _buildInputDecoration(
                                              hintText:
                                                  attendance.oppTeam ?? '상대',
                                            ).copyWith(
                                              fillColor: BACKGROUND_COLOR,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('직관 사진', isOptional: true),
                          const SizedBox(height: 10),
                          Consumer<IntutionRecordProvider>(
                            builder: (context, intutionProvider, child) {
                              if (attendance.isFourCut) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: accentColor.withValues(
                                            alpha: 0.25,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline_rounded,
                                            size: 16,
                                            color: accentColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '네컷으로 등록된 기록은 네컷 스튜디오에서만 사진을 수정할 수 있어요',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxHeight: 340,
                                              ),
                                              child:
                                                  intutionProvider
                                                      .image
                                                      .isNotEmpty
                                                  ? Image.file(
                                                      intutionProvider
                                                          .image
                                                          .first,
                                                      fit: BoxFit.contain,
                                                    )
                                                  : (attendance
                                                            .imageUrls
                                                            .isNotEmpty
                                                        ? CachedNetworkImage(
                                                            imageUrl: attendance
                                                                .imageUrls
                                                                .first,
                                                            fit: BoxFit.contain,
                                                          )
                                                        : const SizedBox(
                                                            height: 120,
                                                          )),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                final generated = await Navigator.push<File>(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        BaseballFourCutStudioPage(
                                                          initialTeam:
                                                              teamProvider
                                                                  .findTeamByName(
                                                                    attendance
                                                                        .myTeam,
                                                                  ),
                                                          opponentName:
                                                              attendance
                                                                  .oppTeam,
                                                          stadium: attendance
                                                              .stadium,
                                                          dateText:
                                                              attendance.date,
                                                          myScore:
                                                              _myTeamScore.text,
                                                          oppScore:
                                                              _oppTeamScore
                                                                  .text,
                                                          returnFileOnConfirm:
                                                              true,
                                                        ),
                                                  ),
                                                );
                                                if (generated != null &&
                                                    mounted) {
                                                  intutionProvider.setImages([
                                                    generated,
                                                  ]);
                                                  intutionProvider.setIsFourCut(
                                                    true,
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.auto_awesome_outlined,
                                                size: 17,
                                              ),
                                              label: const Text(
                                                '🎞️ 네컷 스튜디오에서 다시 만들기',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: WHITE,
                                                side: BorderSide(
                                                  color: WHITE.withValues(
                                                    alpha: 0.28,
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 11,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            '일반 앨범 사진 추가 · 개별 삭제는 비활성화됨',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white60,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (intutionProvider.isImagePicking) {
                                return Container(
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: WHITE,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: GRAYSCALE_LABEL_200,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: accentColor,
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          '사진 불러오는 중...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: GRAYSCALE_LABEL_600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              if (intutionProvider.image.isNotEmpty) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        height: 320,
                                        child: PageView.builder(
                                          controller: _newImagesPageController,
                                          onPageChanged: (index) {
                                            _currentImageIndex.value = index;
                                          },
                                          itemCount:
                                              intutionProvider.image.length,
                                          itemBuilder: (context, imgIndex) {
                                            return Image.file(
                                              intutionProvider.image[imgIndex],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 320,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: _currentImageIndex,
                                        builder: (context, currentIdx, _) {
                                          return GestureDetector(
                                            onTap: currentIdx == 0
                                                ? null
                                                : () {
                                                    intutionProvider
                                                        .setRepresentativeImage(
                                                          currentIdx,
                                                        );
                                                    _currentImageIndex.value =
                                                        0;
                                                    if (_newImagesPageController
                                                        .hasClients) {
                                                      _newImagesPageController
                                                          .animateToPage(
                                                            0,
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      250,
                                                                ),
                                                            curve:
                                                                Curves.easeOut,
                                                          );
                                                    }
                                                  },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: currentIdx == 0
                                                    ? accentColor
                                                    : Colors.black.withValues(
                                                        alpha: 0.65,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    currentIdx == 0
                                                        ? Icons.star_rounded
                                                        : Icons
                                                              .star_outline_rounded,
                                                    color: WHITE,
                                                    size: 15,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    currentIdx == 0
                                                        ? '대표 사진'
                                                        : '대표 사진으로 설정',
                                                    style: const TextStyle(
                                                      color: WHITE,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (intutionProvider.image.length > 1)
                                      Positioned(
                                        bottom: 14,
                                        right: 14,
                                        child: ValueListenableBuilder<int>(
                                          valueListenable: _currentImageIndex,
                                          builder: (context, currentIndex, _) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${currentIndex + 1}/${intutionProvider.image.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () {
                                          final currentIdx =
                                              _currentImageIndex.value;
                                          intutionProvider.removeImageAt(
                                            currentIdx,
                                          );
                                          if (currentIdx >=
                                                  intutionProvider
                                                      .image
                                                      .length &&
                                              intutionProvider
                                                  .image
                                                  .isNotEmpty) {
                                            _currentImageIndex.value =
                                                intutionProvider.image.length -
                                                1;
                                          } else if (intutionProvider
                                              .image
                                              .isEmpty) {
                                            _currentImageIndex.value = 0;
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (attendance.imageUrls.isNotEmpty) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        height: 320,
                                        child: PageView.builder(
                                          controller:
                                              _existingImagesPageController,
                                          onPageChanged: (index) {
                                            _currentImageIndex.value = index;
                                          },
                                          itemCount:
                                              attendance.imageUrls.length,
                                          itemBuilder: (context, imgIndex) {
                                            return CachedNetworkImage(
                                              imageUrl: attendance
                                                  .imageUrls[imgIndex],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 320,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: GRAYSCALE_LABEL_100,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: accentColor,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    color: GRAYSCALE_LABEL_100,
                                                    child: const Center(
                                                      child: Text(
                                                        '이미지를 불러올 수 없습니다',
                                                      ),
                                                    ),
                                                  ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (attendance.imageUrls.length > 1)
                                      Positioned(
                                        bottom: 14,
                                        right: 14,
                                        child: ValueListenableBuilder<int>(
                                          valueListenable: _currentImageIndex,
                                          builder: (context, currentIndex, _) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${currentIndex + 1}/${attendance.imageUrls.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () =>
                                            intutionProvider.pickImage(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.edit_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '사진 변경',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Material(
                                color: WHITE,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () => intutionProvider.pickImage(),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: GRAYSCALE_LABEL_200,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: accentColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          '직관 사진 추가하기',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: GRAYSCALE_LABEL_900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('좌석 정보', isOptional: true),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _scanTicketForSeatAndPrice,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.document_scanner_outlined,
                                        size: 14,
                                        color: accentColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '티켓 스캔 자동 입력',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _seatController,
                            cursorColor: BUTTON,
                            style: const TextStyle(fontSize: 15),
                            decoration: _buildInputDecoration(
                              hintText: '예: 1루 네이비석 306블럭 3열 39번',
                              prefixIcon: Icons.event_seat_outlined,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('티켓 금액', isOptional: true),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _ticketPriceController,
                            keyboardType: TextInputType.number,
                            cursorColor: BUTTON,
                            style: const TextStyle(fontSize: 15),
                            decoration: _buildInputDecoration(
                              hintText: '예: 26000',
                              prefixIcon: Icons.confirmation_number_outlined,
                              suffixText: '원',
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('구장 먹거리', isOptional: true),
                          const SizedBox(height: 10),
                          StadiumFoodSelector(
                            selectedItems: _foodItems,
                            itemPrices: _foodPrices,
                            onToggleItem: (item) {
                              setState(() {
                                if (_foodItems.contains(item)) {
                                  _foodItems.remove(item);
                                  _foodPrices.remove(item);
                                  final total = _foodPrices.values.fold<int>(
                                    0,
                                    (sum, v) => sum + v,
                                  );
                                  _foodCostController.text = total > 0
                                      ? '$total'
                                      : '';
                                } else {
                                  _foodItems.add(item);
                                }
                              });
                            },
                            onAddCustomItem: (item) {
                              setState(() {
                                if (!_foodItems.contains(item)) {
                                  _foodItems.add(item);
                                }
                              });
                            },
                            onItemPriceChanged: (item, price) {
                              setState(() {
                                if (price > 0) {
                                  _foodPrices[item] = price;
                                } else {
                                  _foodPrices.remove(item);
                                }
                                final total = _foodPrices.values.fold<int>(
                                  0,
                                  (sum, v) => sum + v,
                                );
                                _foodCostController.text = total > 0
                                    ? '$total'
                                    : '';
                              });
                            },
                            costController: _foodCostController,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle(
                            '유니폼 · 굿즈 · 포토카드',
                            isOptional: true,
                          ),
                          const SizedBox(height: 10),
                          StadiumFoodSelector(
                            selectedItems: _goodsItems,
                            itemPrices: _goodsPrices,
                            tags: kStadiumGoodsTags,
                            defaultEmoji: '🛍️',
                            totalLabel: '유니폼 · 굿즈 합계',
                            hintText: '위 칩을 누르거나 총 굿즈 금액 입력 (예: 139000)',
                            prefixIcon: Icons.shopping_bag_outlined,
                            onToggleItem: (item) {
                              setState(() {
                                if (_goodsItems.contains(item)) {
                                  _goodsItems.remove(item);
                                  _goodsPrices.remove(item);
                                  final total = _goodsPrices.values.fold<int>(
                                    0,
                                    (sum, v) => sum + v,
                                  );
                                  _goodsCostController.text = total > 0
                                      ? '$total'
                                      : '';
                                } else {
                                  _goodsItems.add(item);
                                }
                              });
                            },
                            onAddCustomItem: (item) {
                              setState(() {
                                if (!_goodsItems.contains(item)) {
                                  _goodsItems.add(item);
                                }
                              });
                            },
                            onItemPriceChanged: (item, price) {
                              setState(() {
                                if (price > 0) {
                                  _goodsPrices[item] = price;
                                } else {
                                  _goodsPrices.remove(item);
                                }
                                final total = _goodsPrices.values.fold<int>(
                                  0,
                                  (sum, v) => sum + v,
                                );
                                _goodsCostController.text = total > 0
                                    ? '$total'
                                    : '';
                              });
                            },
                            costController: _goodsCostController,
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('메모', isOptional: true),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _memoController,
                            cursorColor: BUTTON,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            minLines: 4,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                            decoration: _buildInputDecoration(
                              hintText: '오늘 경기에서 기억에 남는 순간을 기록해보세요',
                            ),
                          ),
                          const SizedBox(height: 18),
                          Material(
                            color: WHITE,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: GRAYSCALE_LABEL_200,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SwitchListTile(
                              value: _isPublic,
                              activeThumbColor: accentColor,
                              title: const Text(
                                '다른 팬에게 공개 · 댓글 허용',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GRAYSCALE_LABEL_950,
                                ),
                              ),
                              subtitle: const Text(
                                '끄면 나만 볼 수 있는 비공개 직관기록이 됩니다',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              onChanged: (v) => setState(() => _isPublic = v),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Consumer2<IntutionRecordProvider, TeamProvider>(
            builder: (context, irp, tp, child) {
              if (!irp.saving) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: irp.saveProgress > 0
                                    ? irp.saveProgress / 100
                                    : null,
                                strokeWidth: 5,
                                color: tp.selectedTeam?.color ?? BUTTON,
                                backgroundColor: GRAYSCALE_LABEL_200,
                              ),
                            ),
                            Text(
                              '${irp.saveProgress}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: GRAYSCALE_LABEL_900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          irp.saveStatusText.isNotEmpty
                              ? irp.saveStatusText
                              : '직관기록 저장 중...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GRAYSCALE_LABEL_950,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isOptional = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_950,
          ),
        ),
        if (isOptional) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: GRAYSCALE_LABEL_100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '선택',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: GRAYSCALE_LABEL_500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_400),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: GRAYSCALE_LABEL_700,
      ),
      filled: true,
      fillColor: WHITE,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: GRAYSCALE_LABEL_500)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BUTTON, width: 1.5),
      ),
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  const _RuledPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;
    const step = 28.0;
    for (double y = 42.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledPaperPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
