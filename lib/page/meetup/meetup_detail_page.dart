import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/page/alert/delete_diallog.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class MeetupDetailPage extends StatefulWidget {
  final MeetupModel meetup;
  const MeetupDetailPage({super.key, required this.meetup});

  @override
  State<MeetupDetailPage> createState() => _MeetupDetailPageState();
}

class _MeetupDetailPageState extends State<MeetupDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeetupProvider>().incrementViewCount(widget.meetup.id);
    });
  }

  Future<void> _handleJoin() async {
    final success = await context.read<MeetupProvider>().joinMeetup(
      widget.meetup.id,
    );
    if (success) {
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
      final success = await context.read<MeetupProvider>().leaveMeetup(
        widget.meetup.id,
      );
      if (success) {
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
      final success = await context.read<MeetupProvider>().deleteMeetup(
        widget.meetup.id,
      );
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

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Consumer<MeetupProvider>(
      builder: (context, meetUpProvider, child) {
        final meetup = meetUpProvider.meetups.firstWhere(
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
                IconButton(onPressed: _handleDelete, icon: Icon(Icons.delete)),
            ],
          ),
          body: ListView(
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
                                  borderRadius: BorderRadiusGeometry.circular(
                                    30,
                                  ),
                                  child: Image.network(
                                    meetup.images[index],
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (meetup.isFull)
                            Positioned(
                              top: 150,
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
                          if (isParticipating)
                            Positioned(
                              top: 170,
                              left: 20,
                              child: Container(
                                padding: EdgeInsets.symmetric(
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
                            ),
                          Positioned(
                            top: 200,
                            left: 20,
                            child: Text(
                              meetup.title,
                              style: TextStyle(
                                fontSize: 18,
                                color: BLACK,
                                fontWeight: FontWeight.bold,
                              ),
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
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: GRAYSCALE_LABEL_300,
                                        backgroundImage:
                                            (user.profileImage?.isNotEmpty ??
                                                false)
                                            ? NetworkImage(user.profileImage!)
                                            : null,
                                        child:
                                            (user.profileImage?.isEmpty ?? true)
                                            ? const Icon(
                                                Icons.person,
                                                size: 30,
                                                color: WHITE,
                                              )
                                            : null,
                                      ),
                                      if (isHost)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedTeam?.color ?? BUTTON,
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
                            : (isParticipating ? _handleLeave : _handleJoin),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
