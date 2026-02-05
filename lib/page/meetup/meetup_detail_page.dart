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
import 'package:toastification/toastification.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

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

  void _postInit(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetupProvider>().incrementViewCount(id);
    });
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

    final updated = await context.read<MeetupProvider>().getMeetupById(
      _latestMeetup!.id,
    );
    if (updated != null && mounted) {
      setState(() {
        _latestMeetup = updated;
      });
    }
  }

  void _setupMeetupListener(String id) {
    _meetupSubscription = context
        .read<MeetupProvider>()
        .getMeetupStream(id)
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
    final targetMeetup = _latestMeetup;
    if (targetMeetup == null) return;

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
    final success = await meetupProvider.joinMeetup(targetMeetup.id);
    if (success) {
      // Firebase Analytics 이벤트 기록
      FirebaseAnalytics.instance.logEvent(
        name: 'join_meetup',
        parameters: {
          'meetup_id': targetMeetup.id,
          'title': targetMeetup.title,
          'team': targetMeetup.myTeam,
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
    final targetMeetup = _latestMeetup;
    if (targetMeetup == null) return;

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
      final color = context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
      return Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        appBar: AppBar(backgroundColor: color, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: color)),
      );
    }

    if (_latestMeetup == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<MeetupProvider>(
      builder: (context, meetUpProvider, child) {
        // Try to get updated version from provider, else use _latestMeetup
        MeetupModel meetup = _latestMeetup!;
        try {
          meetup = meetUpProvider.meetups.firstWhere(
            (m) => m.id == _latestMeetup!.id,
            orElse: () => _latestMeetup!,
          );
        } catch (_) {}

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
                                      Consumer<ProfileProvider>(
                                        builder:
                                            (context, profileProvider, child) {
                                              profileProvider
                                                  .subscribeUserProfile(
                                                    user.uid,
                                                  );
                                              final nickname =
                                                  profileProvider
                                                      .userNicknames[user
                                                      .uid] ??
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
                        SizedBox(height: 10),
                        if (!isMyMeetup || !isParticipating)
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
