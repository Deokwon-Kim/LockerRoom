import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordUploadPage extends StatefulWidget {
  const IntutionRecordUploadPage({super.key});

  @override
  State<IntutionRecordUploadPage> createState() =>
      _IntutionRecordUploadPageState();
}

class _IntutionRecordUploadPageState extends State<IntutionRecordUploadPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDate;
  bool _isTeamSelectorExpanded = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  Future<void> _selectedDate(IntutionRecordProvider provider) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
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
      await provider.loadGamesByDate(pickedDate);
      // 선택한 날짜 기준으로 같은 Provider 인스턴스에 갱신 요청
      // 날짜 변경 시에는 응원팀의 경기로 리셋
      provider.resetTeamSelection();
      await provider.loadByDate(context, pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => IntutionRecordProvider()..init(context),
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
                title: Text(
                  '직관 기록 추가',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                backgroundColor: BACKGROUND_COLOR,
                scrolledUnderElevation: 0,
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // // 날짜 선택
                      // Text(
                      //   '경기날짜',
                      //   style: TextStyle(
                      //     fontSize: 15,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(10),
                        alignment: Alignment.centerLeft,
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일'
                                  : '날짜 선택',
                            ),
                            IconButton(
                              onPressed: () => _selectedDate(intutionProvider),
                              icon: Icon(Icons.date_range_outlined),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      // 팀 선택 (응원팀 외 다른 경기가 있을 때만 표시)
                      if (_hasOtherTeamsThanMyTeam(intutionProvider))
                        _buildTeamSelector(context, intutionProvider),
                      // 경기가 없는 경우 메시지 표시
                      Center(
                        child: Text(
                          '오늘은 경기가 없어요 😢',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: GRAYSCALE_LABEL_600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
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

          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              title: Text(
                '직관 기록 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: BACKGROUND_COLOR,
              scrolledUnderElevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: GestureDetector(
                    onTap: intutionProvider.saving
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            final ok = await intutionProvider.save(context);
                            if (!mounted) return;
                            Navigator.pop(context);
                            toastification.show(
                              context: context,
                              type: ToastificationType.success,
                              alignment: Alignment.bottomCenter,
                              autoCloseDuration: Duration(seconds: 2),
                              title: Text(ok ? '직관 기록이 저장 되었습니다' : '저장 실패'),
                            );
                          },

                    child: intutionProvider.saving
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BUTTON,
                          )
                        : Text(
                            '저장',
                            style: TextStyle(
                              color: teamProvider.selectedTeam?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20.0,
                  left: 16.0,
                  right: 16.0,
                ),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text(
                        '경기날짜',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(10),
                        alignment: Alignment.centerLeft,
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일'
                                  : '날짜 선택',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            IconButton(
                              onPressed: () => _selectedDate(intutionProvider),
                              icon: Icon(Icons.date_range_outlined),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (hasTeamSelector)
                        _buildTeamSelector(context, intutionProvider),
                      if (hasTeamSelector) SizedBox(height: 20),
                      if (hasMultipleGamesForSelectedTeam)
                        _buildGameSlotSelector(
                          context,
                          intutionProvider,
                          gamesForSelectedTeam,
                        ),
                      if (hasMultipleGamesForSelectedTeam) SizedBox(height: 20),
                      Text(
                        '경기정보',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: BACKGROUND_COLOR,
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '응원 팀',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_500,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Image.asset(
                                      myTeamModel?.calenderLogo ??
                                          'assets/images/applogo/app_logo.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      myTeamSymple,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                Padding(
                                  padding: const EdgeInsets.only(top: 30.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'VS',
                                        style: TextStyle(
                                          fontSize: 50,
                                          color: GRAYSCALE_LABEL_500,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        g.stadium,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      // 취소된 경기 표시
                                      if (_isCancelledGame(g)) ...[
                                        SizedBox(height: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: RED_DANGER_SURFACE_5,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: RED_DANGER_BORDER_10,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '경기취소',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: RED_DANGER_TEXT_50,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '상대 팀',
                                      style: TextStyle(
                                        color: GRAYSCALE_LABEL_500,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Image.asset(
                                      oppenentTeamModel?.calenderLogo ??
                                          'assets/images/applogo/app_logo.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      opponentSymple,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      intutionProvider.selectedImage != null
                          ? Container(
                              width: double.infinity,
                              height: 450,
                              decoration: BoxDecoration(
                                border: Border.all(color: GRAYSCALE_LABEL_300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  intutionProvider.selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: () {
                                intutionProvider.pickImage();
                              },
                              child: Container(
                                padding: EdgeInsets.only(left: 10),
                                width: double.infinity,
                                height: 50,
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: BACKGROUND_COLOR,
                                  border: Border.all(
                                    color: GRAYSCALE_LABEL_300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+ 이미지 추가하기',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                      SizedBox(height: 20),
                      Text(
                        '스코어',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              cursorColor: BUTTON,
                              controller: intutionProvider.myScoreController,
                              keyboardType: TextInputType.number,

                              decoration: InputDecoration(
                                focusColor: BUTTON,
                                labelText: '내 팀 스코어',
                                labelStyle: TextStyle(
                                  color: GRAYSCALE_LABEL_500,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: GRAYSCALE_LABEL_300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: GRAYSCALE_LABEL_300,
                                  ),
                                ),
                              ),

                              validator: intutionProvider.validateScore,
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              cursorColor: BUTTON,
                              controller: intutionProvider.oppScoreContreller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: GRAYSCALE_LABEL_300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: GRAYSCALE_LABEL_300,
                                  ),
                                ),
                                labelText: '상대 스코어',
                                labelStyle: TextStyle(
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                              validator: intutionProvider.validateScore,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        '메모(선택)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GRAYSCALE_LABEL_300),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 100, // 최소 높이 지정 가능
                          ),
                          child: TextField(
                            controller: intutionProvider.memoController,
                            cursorColor: BUTTON,
                            maxLines: null,
                            minLines: 1,
                            textAlignVertical: TextAlignVertical.top, // 위쪽 정렬
                            decoration: const InputDecoration(
                              hintStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              isDense: true, // 패딩 최소화
                              contentPadding: EdgeInsets.zero, // 내부 여백 완전히 제거
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // intutionProvider.selectedImage != null
                      //     ? Container(
                      //         width: double.infinity,
                      //         height: 450,
                      //         decoration: BoxDecoration(
                      //           border: Border.all(color: GRAYSCALE_LABEL_300),
                      //           borderRadius: BorderRadius.circular(12),
                      //         ),
                      //         child: ClipRRect(
                      //           borderRadius: BorderRadius.circular(12),
                      //           child: Image.file(
                      //             intutionProvider.selectedImage!,
                      //             fit: BoxFit.cover,
                      //           ),
                      //         ),
                      //       )
                      //     : GestureDetector(
                      //         onTap: () {
                      //           intutionProvider.pickImage();
                      //         },
                      //         child: Container(
                      //           padding: EdgeInsets.only(left: 10),
                      //           width: double.infinity,
                      //           height: 50,
                      //           alignment: Alignment.centerLeft,
                      //           decoration: BoxDecoration(
                      //             color: BACKGROUND_COLOR,
                      //             border: Border.all(
                      //               color: GRAYSCALE_LABEL_300,
                      //             ),
                      //             borderRadius: BorderRadius.circular(12),
                      //           ),
                      //           child: Text(
                      //             '+ 이미지 추가하기',
                      //             style: TextStyle(
                      //               fontSize: 15,
                      //               fontWeight: FontWeight.bold,
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
        Text(
          '팀 선택',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: GRAYSCALE_LABEL_300),
            borderRadius: BorderRadius.circular(12),
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
        Text(
          '경기 선택',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedGameId == game.gameId
                              ? BUTTON
                              : GRAYSCALE_LABEL_300,
                          width: selectedGameId == game.gameId ? 2 : 1,
                        ),
                        color: selectedGameId == game.gameId
                            ? BUTTON.withOpacity(0.08)
                            : Colors.transparent,
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
                                  if (game.doubleHeaderNo != null &&
                                      game.doubleHeaderNo!.isNotEmpty) ...[
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
                                        game.doubleHeaderNo!,
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
