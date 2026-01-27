import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/alert/delete_diallog.dart';
import 'package:lockerroom/page/feed/feed_upload_page.dart';
import 'package:lockerroom/page/meetup/chat_room_page.dart';
import 'package:lockerroom/page/meetup/meetup_people_page.dart';
import 'package:lockerroom/page/meetup/meetup_upload_page.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/tab_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';

class MeetupDetailPage extends StatefulWidget {
  final MeetupModel meetup;
  const MeetupDetailPage({super.key, required this.meetup});

  @override
  State<MeetupDetailPage> createState() => _MeetupDetailPageState();
}

class _MeetupDetailPageState extends State<MeetupDetailPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  MeetupModel? _latestMeetup;
  StreamSubscription? _meetupSubscription;

  Future<void> _refreshMeetup() async {
    final updated = await context.read<MeetupProvider>().getMeetupById(
      widget.meetup.id,
    );
    if (updated != null && mounted) {
      setState(() {
        _latestMeetup = updated;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetupProvider>().incrementViewCount(widget.meetup.id);
    });
    _setupMeetupListener();
  }

  void _setupMeetupListener() {
    _meetupSubscription = context
        .read<MeetupProvider>()
        .getMeetupStream(widget.meetup.id)
        .listen((updated) {
          if (updated != null && mounted) {
            setState(() {
              _latestMeetup = updated;
            });
          }
        });
  }

  @override
  void dispose() {
    _meetupSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final meetupProvider = context.read<MeetupProvider>();
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
    final success = await meetupProvider.joinMeetup(widget.meetup.id);
    if (success) {
      // Firebase Analytics 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'join_meetup',
        parameters: {
          'meetup_id': widget.meetup.id,
          'title': widget.meetup.title,
          'team': widget.meetup.myTeam,
        },
      );
    }
    if (!mounted) return;
    if (success) {
      await _refreshMeetup();
      toastification.show(
        context: context,
        type: ToastificationType.success,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('모임에 참여했습니다'),
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

  Future<void> _handleLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('모임 나가기'),
        content: Text('정말 모임에서 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('나가기'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final meetupProvider = context.read<MeetupProvider>();
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
      final success = await meetupProvider.leaveMeetup(widget.meetup.id);
      if (success) {
        // Firebase Analytics 이벤트 기록
        FirebaseAnalytics.instance.logEvent(
          name: 'leave_meetup',
          parameters: {
            'meetup_id': widget.meetup.id,
            'title': widget.meetup.title,
            'team': widget.meetup.myTeam,
          },
        );
      }
      if (!mounted) return;
      if (success) {
        await _refreshMeetup();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          alignment: Alignment.bottomCenter,
          autoCloseDuration: Duration(seconds: 2),
          title: Text('모임에서 나갔습니다'),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
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
      final success = await meetupProvider.deleteMeetup(widget.meetup.id);
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

  Future<void> _shareScreenshot() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/meetup_share.png',
      ).create();
      await imagePath.writeAsBytes(image);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: '[Locker Room] ${widget.meetup.title} 모임에 함께해요! ⚾',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Screenshot share error: $e');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('공유하기에 실패했습니다'),
          autoCloseDuration: Duration(seconds: 2),
        );
      }
    }
  }

  void _moreBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: BACKGROUND_COLOR,
      builder: (context) => Container(
        width: double.infinity,
        height: 200,
        color: BACKGROUND_COLOR,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share),
              title: Text('공유하기'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('게시글 수정'),
              onTap: () {
                Navigator.pop(context);
                final meetUpProvider = context.read<MeetupProvider>();
                final latestMeetup = meetUpProvider.meetups.firstWhere(
                  (m) => m.id == widget.meetup.id,
                  orElse: () => widget.meetup,
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
              leading: Icon(Icons.delete, color: RED_DANGER_TEXT_50),
              title: Text(
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
                uploadProvider.setMeetupId(widget.meetup.id);
                uploadProvider.setInitialCaption(
                  '함께 직관 가요!✨\n${widget.meetup.title} 모임 참여하기',
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
              leading: Icon(CupertinoIcons.share_up),
              title: Text('SNS로 공유'),
              onTap: () {
                Navigator.pop(context);
                _shareScreenshot();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<MeetupProvider>(
      builder: (context, meetUpProvider, child) {
        final meetup =
            _latestMeetup ??
            meetUpProvider.meetups.firstWhere(
              (m) => m.id == widget.meetup.id,
              orElse: () => widget.meetup,
            );

        final isParticipating =
            currentUserId != null &&
            meetup.participants.contains(currentUserId);
        final isMyMeetup = currentUserId == meetup.userId;

        return Scaffold(
          backgroundColor: BACKGROUND_COLOR,
          appBar: AppBar(
            backgroundColor: selectedTeam?.color ?? BUTTON,
            scrolledUnderElevation: 0,
            title: Text(
              '모임 상세',
              style: TextStyle(
                color: WHITE,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            iconTheme: IconThemeData(color: WHITE),
            actions: [
              if (isMyMeetup)
                IconButton(
                  onPressed: () {
                    _moreBottomSheet(context);
                  },
                  icon: Icon(Icons.more_horiz),
                )
              else
                IconButton(
                  onPressed: () {
                    _showShareOptions(context);
                  },
                  icon: Icon(Icons.share_rounded),
                ),
              // if (isMyMeetup)
              //   IconButton(onPressed: _handleDelete, icon: Icon(Icons.delete)),
            ],
          ),
          body: Screenshot(
            controller: _screenshotController,
            child: Container(
              color: BACKGROUND_COLOR,
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (meetup.images.isNotEmpty)
                          Stack(
                            children: [
                              SizedBox(
                                height: 250,
                                child: PageView.builder(
                                  itemCount: meetup.images.length,
                                  itemBuilder: (context, index) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: Image.network(
                                        meetup.images[index],
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
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
                                  top: 150,
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
                                    child: const Text(
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
                                  top: 150,
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
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  top: 150,
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
                                      style: TextStyle(
                                        color: WHITE,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                              Positioned(
                                top: 180,
                                left: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${meetup.homeTeam} vs ${meetup.awayTeam}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: WHITE,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 4.0,
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
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
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: GRAYSCALE_LABEL_300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: BUTTON.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: selectedTeam?.color ?? BUTTON,
                                ),
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '경기 일정',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTeam?.color ?? BUTTON,
                                    ),
                                  ),
                                  Text(
                                    '${DateFormat('MM월 dd일 (E)', 'ko').format(DateTime.parse(meetup.gameDate))} ${meetup.gameTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: GRAYSCALE_LABEL_300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: BUTTON.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: selectedTeam?.color ?? BUTTON,
                                ),
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '장소',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: selectedTeam?.color ?? BUTTON,
                                    ),
                                  ),
                                  Text(
                                    meetup.stadium,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GRAYSCALE_LABEL_300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description,
                                    color: selectedTeam?.color ?? BUTTON,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '상세 설명',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: BLACK,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(meetup.content),
                            ],
                          ),
                        ),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Text(
                              '참여 멤버',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 5),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: WHITE,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${meetup.participants.length}/${meetup.maxParticipants}명',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: meetup.isFull ? Colors.red : BUTTON,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Spacer(),
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
                              child: Text(
                                '전체보기',
                                style: TextStyle(color: GRAYSCALE_LABEL_500),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        FutureBuilder<List<UserModel>>(
                          future: meetUpProvider.getParticipantsInfo(
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
                                                      width: 2,
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                      Text(
                                        user.userNickName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: BLACK,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        if (!isMyMeetup)
                          GestureDetector(
                            onTap: meetup.isFull
                                ? null
                                : (isParticipating
                                      ? _handleLeave
                                      : _handleJoin),
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isParticipating
                                    ? Colors.grey
                                    : selectedTeam?.color ?? BUTTON,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                meetup.isFull
                                    ? '모집 마감'
                                    : (isParticipating ? '모임 나가기' : '참여하기'),
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            if (!isParticipating) {
                              toastification.show(
                                context: context,
                                type: ToastificationType.warning,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: const Duration(seconds: 2),
                                title: const Text('모임에 참여해야 채팅방 입장이 가능합니다.'),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomPage(
                                  meetupId: meetup.id,
                                  meetupTitle: meetup.title,
                                  meetup: meetup,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: 58,
                            decoration: BoxDecoration(
                              color: isParticipating
                                  ? Colors.green
                                  : GRAYSCALE_LABEL_400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble, color: WHITE, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  '채팅방 입장하기',
                                  style: TextStyle(
                                    color: WHITE,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isMyMeetup)
                          GestureDetector(
                            onTap: () => _showQRCode(context, meetup.id),
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: selectedTeam?.color ?? BUTTON,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '출석용 QR 보여주기',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else if (isParticipating)
                          GestureDetector(
                            onTap: () => _openScanner(context, meetup.id),
                            child: Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: selectedTeam?.color ?? BUTTON,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '출석하기',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
