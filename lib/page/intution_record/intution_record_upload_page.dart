import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockerroom/model/scanned_ticket_data.dart';
import 'package:lockerroom/page/intution_record/intution_record_list_page.dart';
import 'package:lockerroom/widgets/stadium_receipt_card.dart';

class IntutionRecordUploadPage extends StatefulWidget {
  final ScannedTicketData? initialScanData;
  final bool navigateToListOnSave;
  const IntutionRecordUploadPage({
    super.key,
    this.initialScanData,
    this.navigateToListOnSave = false,
  });

  @override
  State<IntutionRecordUploadPage> createState() =>
      _IntutionRecordUploadPageState();
}

class _IntutionRecordUploadPageState extends State<IntutionRecordUploadPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDate;
  bool _isTeamSelectorExpanded = false;
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _hintBounceController;
  late final Animation<Offset> _hintBounceOffset;
  bool _showScrollHint = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialScanData?.gameDate ?? DateTime.now();
    _hintBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _hintBounceOffset =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.18)).animate(
          CurvedAnimation(
            parent: _hintBounceController,
            curve: Curves.easeInOut,
          ),
        );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom =
        pos.maxScrollExtent <= 40 || pos.pixels >= pos.maxScrollExtent - 140;
    if (_showScrollHint == nearBottom && mounted) {
      setState(() => _showScrollHint = !nearBottom);
    }
  }

  void _scrollToShareSection() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _hintBounceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectedDate(IntutionRecordProvider provider) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2027),
      builder: (context, child) {
        final base = Theme.of(context);
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),

          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: BACKGROUND_COLOR,
                headerBackgroundColor: BACKGROUND_COLOR,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: BUTTON,
                surface: BACKGROUND_COLOR,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: BUTTON),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        _isTeamSelectorExpanded = false; // 날짜 변경 시 드롭다운 닫기
      });
      // 선택한 날짜의 모든 경기 가져오기
      await provider.loadGamesByDate(pickedDate, context: context);
      // 선택한 날짜 기준으로 같은 Provider 인스턴스에 갱신 요청
      // 날짜 변경 시에는 응원팀의 경기로 리셋
      provider.resetTeamSelection();
      await provider.loadByDate(context, pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = IntutionRecordProvider()..init(context);

        if (widget.initialScanData != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final data = widget.initialScanData!;
            provider.applyScannedTicketData(
              matchedGame: data.matchedGame,
              gameDate: data.gameDate,
              ticketPrice: data.ticketPrice,
              seat: data.seat,
              ticketImageFile: data.ticketImageFile,
              context: context,
            );
          });
        }
        return provider;
      },
      child: Consumer<IntutionRecordProvider>(
        builder: (context, intutionProvider, child) {
          if (intutionProvider.isLoding) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(title: Text('직관 기록'), scrolledUnderElevation: 0),
              body: Center(child: CircularProgressIndicator(color: BUTTON)),
            );
          }

          if (intutionProvider.myTeamSymple == null) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(title: Text('직관 기록'), scrolledUnderElevation: 0),
              body: Center(child: Text('응원팀이 설정되어 있지 않습니다.')),
            );
          }

          if (intutionProvider.todayGame == null) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(
                title: const Text(
                  '직관 기록 추가',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GRAYSCALE_LABEL_950,
                  ),
                ),
                centerTitle: true,
                backgroundColor: BACKGROUND_COLOR,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('경기 날짜'),
                    const SizedBox(height: 10),
                    _buildDateSelectorCard(intutionProvider),
                    if (_hasOtherTeamsThanMyTeam(intutionProvider)) ...[
                      const SizedBox(height: 22),
                      _buildTeamSelector(context, intutionProvider),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        color: WHITE,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GRAYSCALE_LABEL_200),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.sports_baseball_outlined,
                            size: 40,
                            color: GRAYSCALE_LABEL_400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '선택한 날짜에는 경기가 없어요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: GRAYSCALE_LABEL_800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '다른 날짜를 선택해 직관 기록을 남겨보세요',
                            style: TextStyle(
                              fontSize: 13,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final teamProvider = context.watch<TeamProvider>();
          final g = intutionProvider.todayGame!;
          final selectedTeamSymple =
              intutionProvider.selectedTeamSympleForRecord ??
              intutionProvider.myTeamSymple!;
          final isHome = g.homeTeam == selectedTeamSymple;

          final myTeamSymple = selectedTeamSymple;
          final opponentSymple = isHome ? g.awayTeam : g.homeTeam;

          // 선택한 팀의 TeamModel 찾기 (selectedTeamSympleForRecord 우선)
          final myTeamModel = teamProvider.findTeamByName(myTeamSymple);
          final oppenentTeamModel = teamProvider.findTeamByName(opponentSymple);
          final hasTeamSelector =
              intutionProvider.availableGamesForDate != null &&
              _hasOtherTeamsThanMyTeam(intutionProvider);
          final gamesForSelectedTeam = intutionProvider.gamesForSelectedTeam;
          final hasMultipleGamesForSelectedTeam =
              gamesForSelectedTeam.length > 1;

          final accentColor = teamProvider.selectedTeam?.color ?? BUTTON;
          final isSaveDisabled =
              intutionProvider.saving || intutionProvider.isImagePicking;

          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              title: const Text(
                '직관 기록 추가',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GRAYSCALE_LABEL_950,
                ),
              ),
              centerTitle: true,
              backgroundColor: BACKGROUND_COLOR,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: TextButton(
                    onPressed: isSaveDisabled
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;

                            final capturedStatus =
                                intutionProvider.todayGame?.status ?? 'unknown';
                            final capturedStadium =
                                intutionProvider.todayGame?.stadium ??
                                'unknown';
                            final capturedTeam =
                                intutionProvider.selectedTeamSympleForRecord ??
                                intutionProvider.myTeamSymple ??
                                'unknown';
                            final userNickName =
                                FirebaseAuth
                                    .instance
                                    .currentUser
                                    ?.displayName ??
                                'unknown';

                            final ok = await intutionProvider.save(context);

                            if (ok) {
                              await FirebaseAnalytics.instance.logEvent(
                                name: 'intuition_record_created',
                                parameters: {
                                  'userNickName': userNickName,
                                  'status': capturedStatus,
                                  'stadium': capturedStadium,
                                  'team': capturedTeam,
                                },
                              );
                            }

                            if (!mounted) return;
                            if (ok && widget.navigateToListOnSave) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const IntutionRecordListPage(),
                                ),
                              );
                            } else {
                              Navigator.pop(context);
                            }

                            toastification.show(
                              context: context,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: const Duration(seconds: 2),
                              title: Text(ok ? '직관 기록이 저장 되었습니다' : '저장 실패'),
                            );
                          },
                    style: TextButton.styleFrom(
                      backgroundColor: isSaveDisabled
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
                    child: Text(
                      '저장',
                      style: TextStyle(
                        color: isSaveDisabled ? GRAYSCALE_LABEL_500 : WHITE,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 76),
                      children: [
                        _buildSectionTitle('경기 날짜'),
                        const SizedBox(height: 10),
                        _buildDateSelectorCard(intutionProvider),
                        if (hasTeamSelector) ...[
                          const SizedBox(height: 22),
                          _buildTeamSelector(context, intutionProvider),
                        ],
                        if (hasMultipleGamesForSelectedTeam) ...[
                          const SizedBox(height: 22),
                          _buildGameSlotSelector(
                            context,
                            intutionProvider,
                            gamesForSelectedTeam,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _buildSectionTitle('경기 정보'),
                        const SizedBox(height: 10),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: GRAYSCALE_LABEL_100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${g.stadium} · ${_formatGameTime(g.dateTimeKst)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: GRAYSCALE_LABEL_700,
                                      ),
                                    ),
                                  ),
                                  if (_isCancelledGame(g)) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RED_DANGER_SURFACE_5,
                                        borderRadius: BorderRadius.circular(20),
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
                                          myTeamModel?.calenderLogo ??
                                              'assets/images/applogo/ilu_app_icon.png',
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          myTeamSymple,
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
                                          oppenentTeamModel?.calenderLogo ??
                                              'assets/images/applogo/ilu_app_icon.png',
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          opponentSymple,
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
                                      controller:
                                          intutionProvider.myScoreController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: GRAYSCALE_LABEL_950,
                                      ),
                                      decoration:
                                          _buildInputDecoration(
                                            hintText: myTeamSymple,
                                          ).copyWith(
                                            fillColor: BACKGROUND_COLOR,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                          ),
                                      validator: intutionProvider.validateScore,
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
                                      controller:
                                          intutionProvider.oppScoreContreller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: GRAYSCALE_LABEL_950,
                                      ),
                                      decoration:
                                          _buildInputDecoration(
                                            hintText: opponentSymple,
                                          ).copyWith(
                                            fillColor: BACKGROUND_COLOR,
                                            isDense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                          ),
                                      validator: intutionProvider.validateScore,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('직관 사진', isOptional: true),
                        const SizedBox(height: 10),
                        intutionProvider.isImagePicking
                            ? Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: WHITE,
                                  border: Border.all(
                                    color: GRAYSCALE_LABEL_200,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          color: accentColor,
                                          strokeWidth: 3,
                                        ),
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
                              )
                            : intutionProvider.image.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 360,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: GRAYSCALE_LABEL_200,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Stack(
                                      children: [
                                        PageView.builder(
                                          controller: _pageController,
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentImageIndex = index;
                                            });
                                          },
                                          itemCount:
                                              intutionProvider.image.length,
                                          itemBuilder: (context, index) {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: Image.file(
                                                intutionProvider.image[index],
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                        // 대표 사진 배지 / 대표 사진 설정 버튼
                                        Positioned(
                                          top: 12,
                                          left: 12,
                                          child: GestureDetector(
                                            onTap: _currentImageIndex == 0
                                                ? null
                                                : () {
                                                    intutionProvider
                                                        .setRepresentativeImage(
                                                          _currentImageIndex,
                                                        );
                                                    setState(() {
                                                      _currentImageIndex = 0;
                                                    });
                                                    if (_pageController
                                                        .hasClients) {
                                                      _pageController
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
                                                color: _currentImageIndex == 0
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
                                                    _currentImageIndex == 0
                                                        ? Icons.star_rounded
                                                        : Icons
                                                              .star_outline_rounded,
                                                    color: WHITE,
                                                    size: 15,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _currentImageIndex == 0
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
                                          ),
                                        ),
                                        if (intutionProvider.image.length > 1)
                                          Positioned(
                                            bottom: 14,
                                            right: 14,
                                            child: Container(
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
                                                '${_currentImageIndex + 1}/${intutionProvider.image.length}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                intutionProvider.removeImageAt(
                                                  _currentImageIndex,
                                                );
                                                if (_currentImageIndex >=
                                                        intutionProvider
                                                            .image
                                                            .length &&
                                                    intutionProvider
                                                        .image
                                                        .isNotEmpty) {
                                                  _currentImageIndex =
                                                      intutionProvider
                                                          .image
                                                          .length -
                                                      1;
                                                } else if (intutionProvider
                                                    .image
                                                    .isEmpty) {
                                                  _currentImageIndex = 0;
                                                }
                                              });
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
                                    ),
                                  ),
                                  if (intutionProvider.image.length > 1) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        ...List.generate(
                                          intutionProvider.image.length,
                                          (index) {
                                            final isSelected =
                                                index == _currentImageIndex;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: GestureDetector(
                                                onTap: () {
                                                  _pageController.animateToPage(
                                                    index,
                                                    duration: const Duration(
                                                      milliseconds: 220,
                                                    ),
                                                    curve: Curves.easeOut,
                                                  );
                                                },
                                                child: Container(
                                                  width: 60,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? accentColor
                                                          : GRAYSCALE_LABEL_200,
                                                      width: isSelected
                                                          ? 2.2
                                                          : 1,
                                                    ),
                                                  ),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        child: Image.file(
                                                          intutionProvider
                                                              .image[index],
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      if (index == 0)
                                                        Positioned(
                                                          bottom: 3,
                                                          left: 3,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 5,
                                                                  vertical: 1,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  accentColor,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              '대표',
                                                              style: TextStyle(
                                                                color: WHITE,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
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
                                  ],
                                ],
                              )
                            : Material(
                                color: WHITE,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () => intutionProvider.pickImage(),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
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
                                          width: 42,
                                          height: 42,
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
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '직관 사진 추가하기',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: GRAYSCALE_LABEL_900,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '최대 3장까지 등록할 수 있어요',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: GRAYSCALE_LABEL_500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('좌석 정보', isOptional: true),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: intutionProvider.seatController,
                          cursorColor: BUTTON,
                          style: const TextStyle(fontSize: 15),
                          decoration: _buildInputDecoration(
                            hintText: '예: 1루 네이비석 306블럭 3열 39번',
                            prefixIcon: Icons.event_seat_outlined,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('티켓 금액', isOptional: true),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: intutionProvider.ticketPriceController,
                          keyboardType: TextInputType.number,
                          cursorColor: BUTTON,
                          style: const TextStyle(fontSize: 15),
                          decoration: _buildInputDecoration(
                            hintText: '예: 26000',
                            prefixIcon: Icons.confirmation_number_outlined,
                            suffixText: '원',
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('구장 먹거리', isOptional: true),
                        const SizedBox(height: 10),
                        StadiumFoodSelector(
                          selectedItems: intutionProvider.foodItems,
                          itemPrices: intutionProvider.foodPrices,
                          onToggleItem: intutionProvider.toggleFoodItem,
                          onAddCustomItem: intutionProvider.addFoodItem,
                          onItemPriceChanged: intutionProvider.setFoodItemPrice,
                          costController: intutionProvider.foodCostController,
                        ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('유니폼 · 굿즈 · 포토카드', isOptional: true),
                        const SizedBox(height: 10),
                        StadiumFoodSelector(
                          selectedItems: intutionProvider.goodsItems,
                          itemPrices: intutionProvider.goodsPrices,
                          onToggleItem: intutionProvider.toggleGoodsItem,
                          onAddCustomItem: intutionProvider.addGoodsItem,
                          onItemPriceChanged:
                              intutionProvider.setGoodsItemPrice,
                          costController: intutionProvider.goodsCostController,
                          tags: kStadiumGoodsTags,
                          defaultEmoji: '🛍️',
                          totalLabel: '유니폼 · 굿즈 합계',
                          hintText: '위 칩을 누르거나 총 굿즈 금액 입력 (예: 139000)',
                          prefixIcon: Icons.shopping_bag_outlined,
                        ),
                        const SizedBox(height: 22),
                        _buildSectionTitle('메모', isOptional: true),
                        const SizedBox(height: 10),
                        TextField(
                          controller: intutionProvider.memoController,
                          cursorColor: BUTTON,
                          maxLines: null,
                          minLines: 4,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(fontSize: 15, height: 1.5),
                          decoration: _buildInputDecoration(
                            hintText: '오늘 경기에서 기억에 남는 순간을 기록해보세요',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: ACCENT_CORAL,
                            title: const Text(
                              '👀 좌석 시야 게시판에 공유하기',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: GRAYSCALE_LABEL_950,
                              ),
                            ),
                            subtitle: const Text(
                              '사진과 좌석 정보를 입력하면 다른 팬에게도 시야가 공유됩니다',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                            value: intutionProvider.shareSeatView,
                            onChanged: intutionProvider.setShareSeatView,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: intutionProvider.shareToFeed
                                  ? accentColor
                                  : GRAYSCALE_LABEL_200,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: accentColor,
                            title: const Text(
                              '📢 피드에도 직관 인증 올리기',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: GRAYSCALE_LABEL_950,
                              ),
                            ),
                            subtitle: const Text(
                              '경기 스코어·구장 카드와 함께 피드에 공유되어 댓글 소통이 가능해요',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                            value: intutionProvider.shareToFeed,
                            onChanged: intutionProvider.setShareToFeed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!intutionProvider.saving)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: IgnorePointer(
                      ignoring: !_showScrollHint,
                      child: AnimatedOpacity(
                        opacity: _showScrollHint ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Center(
                          child: SlideTransition(
                            position: _hintBounceOffset,
                            child: GestureDetector(
                              onTap: _scrollToShareSection,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: GRAYSCALE_LABEL_950.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.22,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '👇 아래에 공유 설정이 있어요',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: WHITE,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (intutionProvider.saving)
                  Container(
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
                                    value: intutionProvider.saveProgress > 0
                                        ? intutionProvider.saveProgress / 100
                                        : null,
                                    strokeWidth: 5,
                                    color:
                                        teamProvider.selectedTeam?.color ??
                                        BUTTON,
                                    backgroundColor: GRAYSCALE_LABEL_200,
                                  ),
                                ),
                                Text(
                                  '${intutionProvider.saveProgress}%',
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
                              intutionProvider.saveStatusText.isNotEmpty
                                  ? intutionProvider.saveStatusText
                                  : '직관 기록 저장 중...',
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
                  ),
              ],
            ),
          );
        },
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

  Widget _buildDateSelectorCard(IntutionRecordProvider provider) {
    return Material(
      color: WHITE,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _selectedDate(provider),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: GRAYSCALE_LABEL_200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: GRAYSCALE_LABEL_600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedDate != null
                      ? '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일'
                      : '날짜 선택',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GRAYSCALE_LABEL_900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: GRAYSCALE_LABEL_400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    String? labelText,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_400),
      labelStyle: const TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_500),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  // 취소된 경기인지 확인
  bool _isCancelledGame(ScheduleModel game) {
    final statusUpper = game.status.toUpperCase();
    return game.status == '경기취소' || statusUpper.startsWith('CANCELLED');
  }

  // 응원팀 외 다른 팀의 경기가 있는지 확인
  bool _hasOtherTeamsThanMyTeam(IntutionRecordProvider provider) {
    final myTeamSymple = provider.myTeamSymple;
    if (myTeamSymple == null) return false;

    final availableGames = provider.availableGamesForDate ?? [];
    if (availableGames.isEmpty) return false;

    // 응원팀을 제외한 다른 팀의 경기가 있는지 확인
    final hasOtherTeamGames = availableGames.any(
      (game) => game.homeTeam != myTeamSymple && game.awayTeam != myTeamSymple,
    );

    return hasOtherTeamGames;
  }

  // 팀 선택 UI (드롭다운)
  Widget _buildTeamSelector(
    BuildContext context,
    IntutionRecordProvider provider,
  ) {
    final teamProvider = context.watch<TeamProvider>();
    final allTeams = teamProvider.getTeam('team');

    // 제외할 팀 목록 (국가팀 등)
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
    ];

    // KBO 팀만 필터링
    final kboTeams = allTeams
        .where((t) => !excludedTeamNames.contains(t.name))
        .toList();

    final myTeamSymple = provider.myTeamSymple;
    final availableGames = provider.availableGamesForDate ?? [];

    // 선택한 날짜에 경기가 있는 팀만 표시
    final allTeamsWithGames = kboTeams.where((team) {
      return availableGames.any(
        (game) =>
            game.homeTeam == team.symplename ||
            game.awayTeam == team.symplename,
      );
    }).toList();

    // 응원팀이 경기에 있는지 확인
    final myTeamHasGame =
        myTeamSymple != null &&
        allTeamsWithGames.any((team) => team.symplename == myTeamSymple);

    // 응원팀을 제외한 다른 팀들만 표시
    final teamsWithGames = myTeamHasGame
        ? allTeamsWithGames
        : allTeamsWithGames
              .where((team) => team.symplename != myTeamSymple)
              .toList();

    // 선택된 팀 결정
    // 1. 이미 선택한 팀이 있으면 그것 사용
    // 2. 응원팀이 경기에 있으면 응원팀
    // 3. 응원팀이 경기에 없으면 다른 팀 중 첫 번째
    String? selectedTeamSymple = provider.selectedTeamSympleForRecord;
    if (selectedTeamSymple == null) {
      if (myTeamHasGame) {
        selectedTeamSymple = myTeamSymple;
      } else if (teamsWithGames.isNotEmpty) {
        selectedTeamSymple = teamsWithGames.first.symplename;
      }
    }

    // 선택된 팀 찾기
    final selectedTeam = teamsWithGames.firstWhere(
      (team) => team.symplename == selectedTeamSymple,
      orElse: () =>
          teamsWithGames.isNotEmpty ? teamsWithGames.first : kboTeams.first,
    );

    // 응원팀이 경기에 없고 다른 팀이 있으면 자동으로 첫 번째 팀 선택
    if (!myTeamHasGame &&
        teamsWithGames.isNotEmpty &&
        provider.selectedTeamSympleForRecord == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.selectTeamForRecord(context, teamsWithGames.first.symplename);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('팀 선택'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: WHITE,
            border: Border.all(color: GRAYSCALE_LABEL_200),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // 드롭다운 헤더 (선택된 팀 표시)
              InkWell(
                onTap: () {
                  setState(() {
                    _isTeamSelectorExpanded = !_isTeamSelectorExpanded;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      // 선택된 팀 로고
                      if (selectedTeamSymple != null)
                        Image.asset(
                          selectedTeam.calenderLogo,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      SizedBox(width: 12),
                      // 선택된 팀 이름
                      Expanded(
                        child: Text(
                          selectedTeamSymple ?? '팀 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: GRAYSCALE_LABEL_900,
                          ),
                        ),
                      ),
                      Icon(
                        _isTeamSelectorExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ],
                  ),
                ),
              ),
              // 드롭다운 내용 (팀 목록)
              if (_isTeamSelectorExpanded) ...[
                Divider(height: 1, color: GRAYSCALE_LABEL_200),
                Container(
                  constraints: BoxConstraints(maxHeight: 320, minHeight: 0),
                  child: teamsWithGames.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '선택한 날짜에 경기가 있는 팀이 없습니다.',
                            style: TextStyle(
                              color: GRAYSCALE_LABEL_500,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: teamsWithGames.length,
                              itemBuilder: (context, index) {
                                final team = teamsWithGames[index];
                                final isSelected =
                                    selectedTeamSymple == team.symplename;

                                return InkWell(
                                  onTap: () async {
                                    await provider.selectTeamForRecord(
                                      context,
                                      team.symplename,
                                    );
                                    setState(() {
                                      _isTeamSelectorExpanded = false;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? team.color.withOpacity(0.1)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? team.color
                                            : GRAYSCALE_LABEL_200,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          team.calenderLogo,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          team.symplename,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? team.color
                                                : GRAYSCALE_LABEL_700,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isSelected) ...[
                                          SizedBox(height: 4),
                                          Icon(
                                            Icons.check_circle,
                                            color: team.color,
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameSlotSelector(
    BuildContext context,
    IntutionRecordProvider provider,
    List<ScheduleModel> games,
  ) {
    final selectedGameId =
        provider.selectedGameIdForRecord ?? provider.todayGame?.gameId;
    final teamSymple =
        provider.selectedTeamSympleForRecord ?? provider.myTeamSymple;
    if (teamSymple == null) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('경기 선택'),
        const SizedBox(height: 10),
        Column(
          children: games
              .map(
                (game) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () async {
                      await provider.selectTeamForRecord(
                        context,
                        teamSymple,
                        gameId: game.gameId,
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedGameId == game.gameId
                              ? BUTTON
                              : GRAYSCALE_LABEL_200,
                          width: selectedGameId == game.gameId ? 1.5 : 1,
                        ),
                        color: selectedGameId == game.gameId
                            ? BUTTON.withValues(alpha: 0.06)
                            : WHITE,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatGameTime(game.dateTimeKst),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((game.doubleHeaderNo?.trim() ?? '')
                                      .isNotEmpty) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: BUTTON.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        game.doubleHeaderNo!.trim(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: BUTTON,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                '${game.homeTeam} vs ${game.awayTeam}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: GRAYSCALE_LABEL_700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                game.stadium,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                            ],
                          ),
                          if (selectedGameId == game.gameId)
                            Icon(Icons.check_circle, color: BUTTON),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _formatGameTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
