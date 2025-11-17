import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordDetailPage extends StatefulWidget {
  final AttendanceModel? attendanceModel;
  final String gameId;
  const IntutionRecordDetailPage({
    super.key,
    required this.gameId,
    this.attendanceModel,
  });

  @override
  State<IntutionRecordDetailPage> createState() =>
      _IntutionRecordDetailPageState();
}

class _IntutionRecordDetailPageState extends State<IntutionRecordDetailPage> {
  Future<AttendanceModel?> _loadAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
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
    return byFull.isNotEmpty
        ? byFull.first.calenderLogo
        : 'assets/images/applogo/app_logo.png';
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
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _myTeamScore.dispose();
    _oppTeamScore.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // FutureBuilder에서 데이터를 불러온 후 컨트롤러 값 업데이트
  void _updateControllers(AttendanceModel attendance) {
    if (!_controllersInitialized) {
      _myTeamScore.text = attendance.myScore.toString();
      _oppTeamScore.text = attendance.opponentScore.toString();
      _memoController.text = attendance.memo ?? '';
      _controllersInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '직관 기록 상세',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        scrolledUnderElevation: 0,
        actions: [
          Consumer2<IntutionRecordProvider, TeamProvider>(
            builder: (context, irp, tp, child) {
              return TextButton(
                onPressed: irp.isLoding
                    ? null
                    : () async {
                        // 점수 검증
                        final myScoreText = _myTeamScore.text.trim();
                        final oppScoreText = _oppTeamScore.text.trim();

                        if (myScoreText.isEmpty || oppScoreText.isEmpty) {
                          toastification.show(
                            context: context,
                            alignment: Alignment.bottomCenter,
                            type: ToastificationType.error,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('점수를 입력해주세요'),
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
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('점수를 입력해주세요'),
                          );
                          return;
                        }

                        final success = await irp.updateRecord(
                          gameId: widget.gameId,
                          newMyscore: myScore,
                          newOppScore: oppScore,
                          newMemo: _memoController.text.trim(),
                          newImage: irp.selectedImage,
                        );

                        if (success) {
                          toastification.show(
                            context: context,
                            alignment: Alignment.bottomCenter,
                            type: ToastificationType.success,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('직관기록이 수정되었습니다'),
                          );
                          Navigator.of(context).pop(true);
                        } else {
                          toastification.show(
                            context: context,
                            alignment: Alignment.bottomCenter,
                            type: ToastificationType.error,
                            autoCloseDuration: Duration(seconds: 2),
                            title: Text('직관기록 수정실패'),
                          );
                        }
                      },
                child: irp.isLoding
                    ? CircularProgressIndicator(color: tp.selectedTeam?.color)
                    : Text(
                        '저장',
                        style: TextStyle(
                          color: tp.selectedTeam?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: FutureBuilder<AttendanceModel?>(
          future: _loadAttendance(),
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
                final myTeamLogo = _logoForTeam(
                  teamProvider,
                  attendance.myTeam,
                );
                final oppTeamLogo = attendance.oppTeam != null
                    ? _logoForTeam(teamProvider, attendance.oppTeam!)
                    : 'assets/images/applogo/app_logo.png';

                return SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '경기날짜',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _formatDate(attendance.date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
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
                                      myTeamLogo,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      attendance.myTeam,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 30.0),
                                  child: FutureBuilder<ScheduleModel?>(
                                    future: _findScheduleByGameId(
                                      widget.gameId,
                                    ),
                                    builder: (context, snapshot) {
                                      final schedule = snapshot.data;
                                      return Column(
                                        children: [
                                          Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: 40,
                                              color: GRAYSCALE_LABEL_500,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                attendance.stadium,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              // DH1, DH2 표시
                                              if (schedule?.doubleHeaderNo !=
                                                      null &&
                                                  schedule!
                                                      .doubleHeaderNo!
                                                      .isNotEmpty) ...[
                                                SizedBox(width: 8),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: BUTTON.withOpacity(
                                                      0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: BUTTON.withOpacity(
                                                        0.3,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${schedule.doubleHeaderNo}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: BUTTON,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          // 경기취소 표시
                                          if (_isCancelledGame(schedule)) ...[
                                            SizedBox(height: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: RED_DANGER_SURFACE_5,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                      );
                                    },
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
                                      oppTeamLogo,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      attendance.oppTeam ?? '',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
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
                              controller: _myTeamScore,
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
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: TextFormField(
                              cursorColor: BUTTON,
                              controller: _oppTeamScore,
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
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        '메모',
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
                            controller: _memoController,
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
                      Consumer<IntutionRecordProvider>(
                        builder: (context, intutionProvider, child) {
                          if (intutionProvider.shouldDeleteImage) {
                            return GestureDetector(
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
                            );
                          }
                          // 새로 선택한 이미지가 있으면 표시
                          if (intutionProvider.selectedImage != null) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    intutionProvider.selectedImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 450,
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () {
                                      intutionProvider.removeImage();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          // 기존 이미지가 있으면 표시
                          if (attendance.imageUrl != null) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: attendance.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 450,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: Text('이미지를 불러올 수 없습니다'),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () {
                                      intutionProvider.removeImage();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          // 새로 추가한 이미지가 있으면 표시
                          else if (intutionProvider.selectedImage != null) {
                            return GestureDetector(
                              onTap: () {
                                intutionProvider.pickImage();
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  intutionProvider.selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 450,
                                ),
                              ),
                            );
                          }
                          // 둘 다 없으면 추가 버튼 표시
                          else {
                            return GestureDetector(
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
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
