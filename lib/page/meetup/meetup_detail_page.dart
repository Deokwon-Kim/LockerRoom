import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/alert/confirm_diallog.dart';
import 'package:lockerroom/page/alert/delete_diallog.dart';
import 'package:lockerroom/page/feed/feed_upload_page.dart';
import 'package:lockerroom/page/meetup/chat_room_page.dart';
import 'package:lockerroom/page/meetup/meetup_people_page.dart';
import 'package:lockerroom/page/meetup/meetup_upload_page.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/tab_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

class MeetupDetailPage extends StatefulWidget {
  final MeetupModel? meetup;
  final String? meetupId;
  const MeetupDetailPage({super.key, this.meetup, this.meetupId});

  @override
  State<MeetupDetailPage> createState() => _MeetupDetailPageState();
}

class _MeetupDetailPageState extends State<MeetupDetailPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  MeetupModel? _latestMeetup;
  bool _isLoading = false;
  StreamSubscription? _meetupSubscription;

  @override
  void initState() {
    super.initState();
    _latestMeetup = widget.meetup;

    if (_latestMeetup == null && widget.meetupId != null) {
      _loadMeetupData(widget.meetupId!);
    } else if (_latestMeetup != null) {
      _postInit(_latestMeetup!.id);
    }
  }

  Future<void> _postInit(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final viewedKey = 'viewed_meetup_$id';
    final hasViewed = prefs.getBool(viewedKey) ?? false;

    if (!hasViewed && mounted) {
      context.read<MeetupProvider>().incrementViewCount(id);
      await prefs.setBool(viewedKey, true);
    }
    _setupMeetupListener(id);
  }

  Future<void> _loadMeetupData(String id) async {
    setState(() => _isLoading = true);
    try {
      final fetched = await context.read<MeetupProvider>().getMeetupById(id);
      if (fetched != null && mounted) {
        setState(() {
          _latestMeetup = fetched;
        });
      } else if (mounted) {
        // 데이터가 없는 경우 처리
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모임 정보를 찾을 수 없습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMeetup() async {
    if (_latestMeetup == null) return;
    try {
      final updated = await context.read<MeetupProvider>().getMeetupById(
        _latestMeetup!.id,
      );
      if (updated != null && mounted) {
        setState(() {
          _latestMeetup = updated;
        });
      }
    } catch (e) {
      debugPrint('모임 새로고침 오류: $e');
      // 권한 에러 등이 발생할 수 있으므로 무시하거나 적절히 처리
    }
  }

  void _setupMeetupListener(String id) {
    _meetupSubscription = context
        .read<MeetupProvider>()
        .getMeetupStream(id)
        .listen(
          (updated) {
            if (updated != null && mounted) {
              setState(() {
                _latestMeetup = updated;
              });
            }
          },
          onError: (e) {
            debugPrint('모임 구독 오류: $e');
            // 특히 나가기 시 permission-denied가 발생할 수 있음
          },
        );
  }

  @override
  void dispose() {
    _meetupSubscription?.cancel();
    super.dispose();
  }

  void _showAgeVerificationBottomSheet(MeetupModel meetup) {
    final TextEditingController ageController = TextEditingController();
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '연령 확인',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '이 모임은 연령 제한이 있습니다.\n본인의 출생연도를 입력해주세요 (예: 1995)',
              style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '출생연도 4자리 입력',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: teamColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final enteredYear = int.tryParse(ageController.text);
                  if (enteredYear == null || ageController.text.length != 4) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.warning,
                      title: const Text('올바른 출생연도 4자리를 입력해주세요'),
                    );
                    return;
                  }

                  // 연령 체크
                  bool isAllowed = true;
                  if (meetup.minBirthYear != null &&
                      enteredYear < meetup.minBirthYear!) {
                    isAllowed = false;
                  }
                  if (meetup.maxBirthYear != null &&
                      enteredYear > meetup.maxBirthYear!) {
                    isAllowed = false;
                  }

                  if (!isAllowed) {
                    Navigator.pop(context);
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      title: const Text('죄송합니다. 이 모임의 참여 연령대가 아닙니다.'),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _joinProcess(meetup, birthYear: enteredYear);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(color: WHITE, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectReasonDialog(
    String meetupId,
    String userId,
    String userName,
  ) {
    final TextEditingController reasonController = TextEditingController();
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          '참여 거절',
          style: TextStyle(
            color: GRAYSCALE_LABEL_900,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$userName님의 참여를 거절하시겠습니까?',
              style: const TextStyle(
                fontSize: 15,
                color: GRAYSCALE_LABEL_700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '거절 사유 (선택)',
                hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: teamColor, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    overlayColor: Colors.transparent,
                    elevation: 0,
                    backgroundColor: GRAYSCALE_LABEL_100,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: GRAYSCALE_LABEL_950),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.red,
                    overlayColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    Navigator.pop(context);

                    final provider = context.read<MeetupProvider>();
                    final success = await provider.rejectParticipant(
                      meetupId,
                      userId,
                      reason: reason.isNotEmpty ? reason : null,
                    );

                    if (!mounted) return;
                    if (success) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.success,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('참여 신청을 거절했습니다'),
                      );
                      await _refreshMeetup();
                    } else {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        alignment: Alignment.bottomCenter,
                        autoCloseDuration: Duration(seconds: 2),
                        title: Text('거절 처리에 실패했습니다'),
                      );
                    }
                  },
                  child: const Text('거절', style: TextStyle(color: WHITE)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoin() async {
    final targetMeetup = _latestMeetup;
    if (targetMeetup == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('로그인이 필요합니다.'),
      );
      return;
    }

    // 연령 제한이 있는 경우 바텀시트 먼저 표시
    if (targetMeetup.minBirthYear != null ||
        targetMeetup.maxBirthYear != null) {
      _showAgeVerificationBottomSheet(targetMeetup);
    } else {
      _joinProcess(targetMeetup);
    }
  }

  Future<void> _joinProcess(MeetupModel targetMeetup, {int? birthYear}) async {
    final meetupProvider = context.read<MeetupProvider>();
    final success = await meetupProvider.joinMeetup(
      targetMeetup.id,
      birthYear: birthYear,
    );

    if (success) {
      FirebaseAnalytics.instance.logEvent(
        name: 'join_meetup',
        parameters: {
          'meetup_id': targetMeetup.id,
          'title': targetMeetup.title,
          'team': targetMeetup.myTeam,
          'approval_required': targetMeetup.isApprovalRequired ? 1 : 0,
        },
      );
    }

    if (!mounted) return;
    if (success) {
      await _refreshMeetup();
      final msg = targetMeetup.isApprovalRequired
          ? '참여 신청이 완료되었습니다. 방장의 승인을 기다려주세요.'
          : '모임에 참여했습니다';
      toastification.show(
        context: context,
        type: ToastificationType.success,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 3),
        title: Text(msg),
      );
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('모임 참여에 실패했습니다'),
      );
    }
  }

  Widget _buildPendingParticipantsSection(
    MeetupModel meetup,
    MeetupProvider provider,
  ) {
    if (meetup.pendingParticipants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.person_add_alt_1, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              '참여 승인 대기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${meetup.pendingParticipants.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<UserModel>>(
          key: ValueKey(meetup.pendingParticipants.join(',')),
          future: provider.getParticipantsInfo(meetup.pendingParticipants),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final pendingUsers = snapshot.data!;
            return Column(
              children: pendingUsers.map((user) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GRAYSCALE_LABEL_300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: GRAYSCALE_LABEL_300,
                        backgroundImage:
                            (user.profileImage != null &&
                                user.profileImage!.isNotEmpty)
                            ? NetworkImage(user.profileImage!)
                            : null,
                        child:
                            (user.profileImage == null ||
                                user.profileImage!.isEmpty)
                            ? const Icon(Icons.person, size: 20, color: WHITE)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.userNickName}${user.birthYear != null ? ' (${user.birthYear}년생)' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              '참여를 신청했습니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _showRejectReasonDialog(
                              meetup.id,
                              user.uid,
                              user.userNickName,
                            ),
                            child: const Text(
                              '거절',
                              style: TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () async {
                              final success = await provider.approveParticipant(
                                meetup.id,
                                user.uid,
                              );

                              if (!mounted) return;
                              if (success) {
                                toastification.show(
                                  context: context,
                                  type: ToastificationType.success,
                                  alignment: Alignment.bottomCenter,
                                  autoCloseDuration: Duration(seconds: 2),
                                  title: Text(
                                    '${user.userNickName}님의 참여를 승인했습니다',
                                  ),
                                );
                              } else {
                                toastification.show(
                                  context: context,
                                  type: ToastificationType.error,
                                  alignment: Alignment.bottomCenter,
                                  autoCloseDuration: Duration(seconds: 2),
                                  title: Text('승인 처리에 실패했습니다'),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  context
                                      .read<TeamProvider>()
                                      .selectedTeam
                                      ?.color ??
                                  BUTTON,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: const Size(60, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              '승인',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const Divider(height: 32),
      ],
    );
  }

  Future<void> _handleLeave() async {
    final targetMeetup = _latestMeetup;
    if (targetMeetup == null) return;

    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: '모임 나가기',
        content: '정말 모임에서 나가시겠습니까?',
        confirmText: '나가기',
        cancelText: '취소',
        onConfirm: () async {
          final meetupProvider = context.read<MeetupProvider>();
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              alignment: Alignment.bottomCenter,
              autoCloseDuration: const Duration(seconds: 2),
              title: const Text('로그인이 필요합니다.'),
            );
            return;
          }
          final success = await meetupProvider.leaveMeetup(targetMeetup.id);
          if (success) {
            // Firebase Analytics 이벤트 기록
            FirebaseAnalytics.instance.logEvent(
              name: 'leave_meetup',
              parameters: {
                'meetup_id': targetMeetup.id,
                'title': targetMeetup.title,
                'team': targetMeetup.myTeam,
              },
            );
            if (mounted) {
              await _refreshMeetup();
              toastification.show(
                context: context,
                type: ToastificationType.success,
                alignment: Alignment.bottomCenter,
                autoCloseDuration: const Duration(seconds: 2),
                title: const Text('모임에서 나갔습니다'),
              );
            }
          } else {
            if (mounted) {
              toastification.show(
                context: context,
                type: ToastificationType.error,
                alignment: Alignment.bottomCenter,
                autoCloseDuration: const Duration(seconds: 2),
                title: const Text('모임 나가기에 실패했습니다'),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleDelete() async {
    final targetMeetup = _latestMeetup;
    if (targetMeetup == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteDiallog(
        title: '모임 삭제',
        content: '정말 모임을 삭제하시겠습니까?',
        onConfirm: () {},
      ),
    );

    if (confirm == true) {
      final meetupProvider = context.read<MeetupProvider>();
      final success = await meetupProvider.deleteMeetup(targetMeetup.id);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        toastification.show(
          context: context,
          type: ToastificationType.success,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('모임이 삭제되었습니다'),
        );
      }
    }
  }

  // 방장용 QR 다이얼로그
  void _showQRCode(BuildContext context, String meetupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.read<TeamProvider>().selectedTeam?.color,
      builder: (context) => Container(
        width: double.infinity,
        height: 450,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: context.read<TeamProvider>().selectedTeam?.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_rounded, color: WHITE, size: 40),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '출석용 QR 코드',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: WHITE,
                      ),
                    ),
                    Text(
                      '모임 참가자에게 이 QR을 보여주세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: WHITE.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close, color: WHITE, size: 30),
                ),
              ],
            ),
            SizedBox(height: 50),
            Container(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: WHITE,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: meetupId,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            SizedBox(height: 20), // QR과의 간격
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  color: WHITE.withOpacity(0.8),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  '스캔 시 자동으로 출석 처리됩니다.',
                  style: TextStyle(
                    color: WHITE.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 참가자용 스캐너 다이얼로그
  void _openScanner(BuildContext context, String meetupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: MobileScanner(
          onDetect: (capture) async {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue == meetupId) {
                // 스캔한 QR이 해당 모임 ID와 일치하면 출석 처리
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  final meetupProvider = context.read<MeetupProvider>();
                  final success = await meetupProvider.markAttendance(
                    meetupId,
                    userId,
                  );
                  if (!mounted) return;
                  if (success) {
                    Navigator.pop(context);
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      title: Text('출석이 완료되었습니다'),
                    );
                  }
                }
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _shareMeetupViaKakao() async {
    try {
      if (_latestMeetup == null) return;

      final imageUrl = _latestMeetup!.images.isNotEmpty
          ? _latestMeetup!.images[0]
          : '';
      final title = _latestMeetup!.title;
      final description =
          '${_latestMeetup!.homeTeam} vs ${_latestMeetup!.awayTeam} \n ${_latestMeetup!.gameDate} ${_latestMeetup!.stadium}';
      final deepLinkPath = 'meetup/${_latestMeetup!.id}';

      // FeedTemplate 생성
      final template = FeedTemplate(
        content: Content(
          title: title,
          description: description,
          imageUrl: Uri.parse(
            imageUrl.isNotEmpty
                ? imageUrl
                : 'https://github.com/Deokwon-Kim/LockerRoom/blob/dev/ios/Runner/Assets.xcassets/AppIcon.appiconset/256.png?raw=true',
          ),
          link: Link(
            webUrl: Uri.parse('https://lockerroom-e9f39.web.app/$deepLinkPath'),
            mobileWebUrl: Uri.parse(
              'https://lockerroom-e9f39.web.app/$deepLinkPath',
            ),
          ),
        ),
        buttons: [
          Button(
            title: '자세히보기',
            link: Link(
              webUrl: Uri.parse(
                'https://lockerroom-e9f39.web.app/$deepLinkPath',
              ),
              mobileWebUrl: Uri.parse(
                'https://lockerroom-e9f39.web.app/$deepLinkPath',
              ),
              androidExecutionParams: {'meetupId': _latestMeetup!.id},
              iosExecutionParams: {'meetupId': _latestMeetup!.id},
            ),
          ),
        ],
      );

      // 카카오톡 설치 여부 확인 후 공유
      bool isKakaoTalkSharingAvailable = await ShareClient.instance
          .isKakaoTalkSharingAvailable();

      if (isKakaoTalkSharingAvailable) {
        try {
          Uri uri = await ShareClient.instance.shareDefault(template: template);
          await ShareClient.instance.launchKakaoTalk(uri);
        } catch (error) {
          debugPrint('카카오톡 공유 실패 $error');
        }
      } else {
        try {
          Uri shareUrl = await WebSharerClient.instance.makeDefaultUrl(
            template: template,
          );
          await launchBrowserTab(shareUrl);
        } catch (error) {
          debugPrint('카카오톡 공유 실패 $error');
        }
      }
    } catch (e) {
      debugPrint('Kakao share error: $e');
    }
  }

  Future<void> _shareMeetupWithImage() async {
    try {
      if (_latestMeetup == null) return;

      final title = '[더베이스] ${_latestMeetup!.title} 모임 초대';
      final text =
          '$title ⚾\n\n모임 참여하기: https://lockerroom-e9f39.web.app/meetup/${_latestMeetup!.id}';

      // 1. 커스텀 카드 고퀄리티 이미지 생성 (메모리 내 렌더링 및 캡쳐)
      final imageBytes = await _screenshotController.captureFromWidget(
        _buildShareCardWidget(),
        delay: const Duration(milliseconds: 200),
        context: context,
      );

      final directory = await getTemporaryDirectory();
      final imagePath = File('${directory.path}/meetup_share_card.png');
      await imagePath.writeAsBytes(imageBytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(imagePath.path, mimeType: 'image/png')],
        text: text,
        subject: title,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Share card generation error: $e');
      // 실패 시 폴백 (기본 텍스트 공유)
      final text =
          '[더베이스] ${_latestMeetup!.title} 모임 초대 ⚾\n\n모임 참여하기: https://lockerroom-e9f39.web.app/meetup/${_latestMeetup!.id}';
      Share.share(text);
    }
  }

  Widget _buildShareCardWidget() {
    final meetup = _latestMeetup!;
    // 배경 이미지: 모임 사진이 있으면 사용, 없으면 야구장 기본 이미지 사용
    final backgroundImage = meetup.images.isNotEmpty
        ? meetup.images[0]
        : 'https://images.unsplash.com/photo-1508344928928-71641a3fe09c?q=80&w=1000&auto=format&fit=crop';

    return Container(
      width: 400,
      height: 520,
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(backgroundImage),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.darken,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 경기 정보 (팀 vs 팀)
          Text(
            '${meetup.homeTeam} vs ${meetup.awayTeam}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              fontFamily: 'kbo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // 모임 제목 및 "직관 모임!"
          Text(
            meetup.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              fontFamily: 'kbo',
            ),
            textAlign: TextAlign.center,
          ),
          // 하단 일시 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 14),
              Text(
                meetup.gameDate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 하단 장소 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 10),
              Text(
                meetup.stadium,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _moreBottomSheet(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isParticipating =
        _latestMeetup?.participants.contains(currentUserId) ?? false;
    final isMyMeetup = _latestMeetup?.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: BACKGROUND_COLOR,
      builder: (context) => Container(
        width: double.infinity,
        color: BACKGROUND_COLOR,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('공유하기'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(context);
              },
            ),
            if (isMyMeetup) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('게시글 수정'),
                onTap: () {
                  Navigator.pop(context);
                  final meetUpProvider = context.read<MeetupProvider>();
                  if (_latestMeetup == null) return;

                  final latestMeetup = meetUpProvider.meetups.firstWhere(
                    (m) => m.id == _latestMeetup!.id,
                    orElse: () => _latestMeetup!,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MeetupUploadPage(meetupToEdit: latestMeetup),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: RED_DANGER_TEXT_50),
                title: const Text(
                  '모임 삭제',
                  style: TextStyle(
                    fontSize: 15,
                    color: RED_DANGER_TEXT_50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleDelete();
                },
              ),
            ] else if (isParticipating) ...[
              ListTile(
                leading: const Icon(
                  Icons.exit_to_app,
                  color: RED_DANGER_TEXT_50,
                ),
                title: const Text(
                  '모임 나가기',
                  style: TextStyle(
                    fontSize: 15,
                    color: RED_DANGER_TEXT_50,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleLeave();
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 공유 옵션
  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: BACKGROUND_COLOR,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            ListTile(
              leading: Icon(Icons.feed),
              title: Text('피드에 공유'),
              onTap: () {
                Navigator.pop(context);
                final uploadProvider = context.read<UploadProvider>();
                uploadProvider.clearAll();
                if (_latestMeetup == null) return;

                uploadProvider.setMeetupId(_latestMeetup!.id);
                uploadProvider.setInitialCaption(
                  '함께 직관 가요!✨\n${_latestMeetup!.title} 모임 참여하기',
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FeedUploadPage(
                      onUploaded: () {
                        // 모든 스택을 닫고 메인 탭바(루트)로 이동
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                        context.read<TabProvider>().setSelectedIndex(1);
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Image.asset('assets/images/logo/kakao.png', height: 24),
              title: Text('카카오톡으로 공유'),
              onTap: () {
                Navigator.pop(context);
                _shareMeetupViaKakao();
              },
            ),
            ListTile(
              leading: Icon(CupertinoIcons.share_up),
              title: Text('기타 SNS로 공유'),
              onTap: () {
                Navigator.pop(context);
                _shareMeetupWithImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final teamColor =
          context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

      return Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        body: Center(child: CircularProgressIndicator(color: teamColor)),
      );
    }
    if (_latestMeetup == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<MeetupProvider>(
      builder: (context, meetupProvider, child) {
        final meetup = _latestMeetup!;

        final isParticipating =
            currentUserId != null &&
            meetup.participants.contains(currentUserId);
        final isPending =
            currentUserId != null &&
            meetup.pendingParticipants.contains(currentUserId);
        final isMyMeetup = currentUserId == meetup.userId;

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          body: SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Column(
              children: [
                if (meetup.images.isNotEmpty)
                  Stack(
                    children: [
                      SizedBox(
                        height: 320,
                        child: PageView.builder(
                          itemBuilder: (context, index) {
                            return Image.network(
                              meetup.images[index],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),

                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.08),
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      if (isParticipating)
                        Positioned(
                          top: 170,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '참여중',
                              style: TextStyle(
                                color: WHITE,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else if (meetup.isFull)
                        Positioned(
                          top: 170,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '마감',
                              style: TextStyle(color: WHITE, fontSize: 12),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 170,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selectedTeam?.color ?? BUTTON,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '모집중',
                              style: TextStyle(color: WHITE, fontSize: 12),
                            ),
                          ),
                        ),

                      Positioned(
                        top: 210,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${meetup.awayTeam} vs ${meetup.homeTeam}',
                              style: TextStyle(
                                fontSize: 18,
                                color: WHITE,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 4.0,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              meetup.title,
                              style: TextStyle(
                                fontSize: 18,
                                color: WHITE,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 4.0,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 5),
                            Row(
                              children: [
                                Consumer<ProfileProvider>(
                                  builder: (context, profileProvider, child) {
                                    final url = profileProvider
                                        .userProfiles[meetup.userId];
                                    final nickName =
                                        profileProvider.userNicknames[meetup
                                            .userId] ??
                                        meetup.userNickName;

                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundImage: url != null
                                              ? NetworkImage(url)
                                              : null,
                                          backgroundColor: GRAYSCALE_LABEL_300,
                                          child: url == null
                                              ? Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 20,
                                                )
                                              : null,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          '방장:',
                                          style: TextStyle(color: WHITE),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          nickName,
                                          style: TextStyle(color: WHITE),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          '조회',
                                          style: TextStyle(color: WHITE),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${meetup.viewCount}',
                                          style: TextStyle(color: WHITE),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 50.0,
                          left: 15,
                          right: 15,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: WHITE,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (isMyMeetup)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _moreBottomSheet(context);
                                  },
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: WHITE,
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _showShareOptions(context);
                                  },
                                  icon: const Icon(
                                    CupertinoIcons.share,
                                    color: WHITE,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: BACKGROUND_COLOR,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GRAYSCALE_LABEL_300),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: BUTTON.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: selectedTeam?.color ?? BUTTON,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '경기일정',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        Text(
                                          '${DateFormat('MM/dd(E)', 'ko').format(DateTime.parse(meetup.gameDate))} ${meetup.gameTime}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: BLACK,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: BACKGROUND_COLOR,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GRAYSCALE_LABEL_300),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: BUTTON.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: selectedTeam?.color ?? BUTTON,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '장소',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: GRAYSCALE_LABEL_500,
                                          ),
                                        ),
                                        Text(
                                          meetup.stadium,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: BLACK,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 응원팀 안내 섹션
                      if (meetup.myTeam.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                context
                                    .read<TeamProvider>()
                                    .findTeamByName(meetup.myTeam)
                                    ?.color
                                    .withOpacity(0.1) ??
                                BUTTON.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  context
                                      .read<TeamProvider>()
                                      .findTeamByName(meetup.myTeam)
                                      ?.color
                                      .withOpacity(0.3) ??
                                  GRAYSCALE_LABEL_300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      context
                                          .read<TeamProvider>()
                                          .findTeamByName(meetup.myTeam)
                                          ?.color ??
                                      BUTTON,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: WHITE,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: BLACK,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: meetup.myTeam,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              context
                                                  .read<TeamProvider>()
                                                  .findTeamByName(meetup.myTeam)
                                                  ?.color ??
                                              BUTTON,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' 팬과 함께 응원하고 싶어요! ⚾️',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 10),

                      // 연령제한 및 승인필요 안내
                      if (meetup.minBirthYear != null ||
                          meetup.isApprovalRequired) ...[
                        SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: BLACK,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    '참여 조건 및 유의사항',
                                    style: TextStyle(
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Padding(
                                padding: const EdgeInsets.only(left: 30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (meetup.minBirthYear != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.cake,
                                            size: 14,
                                            color: BLACK,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            meetup.minBirthYear ==
                                                    meetup.maxBirthYear
                                                ? '${meetup.maxBirthYear}년생 출생자만 참여 가능'
                                                : '${meetup.minBirthYear}~${meetup.maxBirthYear}년생 출생자만 참여 가능',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: BLACK,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (meetup.isApprovalRequired) ...[
                                      if (meetup.minBirthYear != null)
                                        const SizedBox(height: 4),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.admin_panel_settings,
                                            size: 14,
                                            color: BLACK,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '방장 승인 후 참여 가능',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: BLACK,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 10),
                      if (isMyMeetup && meetup.pendingParticipants.isNotEmpty)
                        _buildPendingParticipantsSection(
                          meetup,
                          meetupProvider,
                        ),
                      SizedBox(height: 10),

                      const Text(
                        '상세 설명',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: BLACK,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        meetup.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: BLACK,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 25),
                      Row(
                        children: [
                          const Text(
                            '참여 멤버',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${meetup.participants.length}/${meetup.maxParticipants}명',
                            style: TextStyle(
                              fontSize: 13,
                              color: meetup.isFull ? Colors.red : BUTTON,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MeetupPeoplePage(meetUp: meetup),
                                ),
                              );
                            },
                            child: const Text(
                              '전체보기',
                              style: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<UserModel>>(
                        future: meetupProvider.getParticipantsInfo(
                          meetup.participants,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: snapshot.data!.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 15),
                              itemBuilder: (context, index) {
                                final user = snapshot.data![index];
                                final isHost = user.uid == meetup.userId;
                                return Column(
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border:
                                                meetup.attendedParticipants
                                                    .contains(user.uid)
                                                ? Border.all(
                                                    color: Colors.green,
                                                    width: 1.5,
                                                  )
                                                : null,
                                          ),
                                          child: CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                GRAYSCALE_LABEL_300,
                                            backgroundImage:
                                                (user
                                                        .profileImage
                                                        ?.isNotEmpty ??
                                                    false)
                                                ? NetworkImage(
                                                    user.profileImage!,
                                                  )
                                                : null,
                                            child:
                                                (user.profileImage?.isEmpty ??
                                                    true)
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 30,
                                                    color: WHITE,
                                                  )
                                                : null,
                                          ),
                                        ),
                                        if (isHost)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    selectedTeam?.color ??
                                                    BUTTON,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: WHITE,
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Text(
                                                'HOST',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: WHITE,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (meetup.attendedParticipants
                                            .contains(user.uid))
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: WHITE,
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check,
                                                    color: WHITE,
                                                    size: 10,
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    '출석완료',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      color: WHITE,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Consumer<ProfileProvider>(
                                      builder:
                                          (context, profileProvider, child) {
                                            profileProvider
                                                .subscribeUserProfile(user.uid);
                                            final nickname =
                                                profileProvider
                                                    .userNicknames[user.uid] ??
                                                user.userNickName;
                                            return Text(
                                              nickname,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: BLACK,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(
              15,
              15,
              15,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: WHITE,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        context.read<MeetupProvider>().toggleLike(meetup.id);
                      },
                      icon: Icon(
                        meetup.likedBy.contains(currentUserId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: meetup.likedBy.contains(currentUserId)
                            ? Colors.red
                            : null,
                      ),
                    ),
                    if (meetup.likeCount > 0)
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Text(
                          '${meetup.likeCount}',
                          style: const TextStyle(fontSize: 10, color: BLACK),
                        ),
                      ),
                  ],
                ),
                if (isMyMeetup || isParticipating) ...[
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (isMyMeetup) {
                            _showQRCode(context, meetup.id);
                          } else {
                            _openScanner(context, meetup.id);
                          }
                        },
                        icon: Icon(
                          isMyMeetup ? Icons.qr_code_2 : Icons.qr_code_scanner,
                          color: selectedTeam?.color ?? BUTTON,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -6),
                        child: Text(
                          'QR',
                          style: TextStyle(fontSize: 10, color: BLACK),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (isPending || (meetup.isFull && !isParticipating))
                        ? null
                        : () {
                            if (isMyMeetup || isParticipating) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: 'ChatRoomPage',
                                  ),
                                  builder: (context) => ChatRoomPage(
                                    meetupId: meetup.id,
                                    meetupTitle: meetup.title,
                                    meetup: meetup,
                                  ),
                                ),
                              );
                            } else {
                              _handleJoin();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isMyMeetup || isParticipating)
                          ? (selectedTeam?.color ?? BUTTON)
                          : (isPending || meetup.isFull
                                ? GRAYSCALE_LABEL_300
                                : (selectedTeam?.color ?? BUTTON)),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      (isMyMeetup || isParticipating)
                          ? '채팅방 입장하기'
                          : (isPending
                                ? '승인 대기 중...'
                                : (meetup.isFull ? '마감되었습니다' : '모임 참여하기')),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: WHITE,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
