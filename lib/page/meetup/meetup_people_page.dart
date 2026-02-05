import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class MeetupPeoplePage extends StatelessWidget {
  final MeetupModel meetUp;
  const MeetupPeoplePage({super.key, required this.meetUp});

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: selectedTeam?.color ?? BUTTON,
        scrolledUnderElevation: 0,
        title: Text(
          '참석 명단',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: WHITE,
          ),
        ),
        iconTheme: IconThemeData(color: WHITE),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: WHITE,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${meetUp.stadium} 직관모임',
                  style: TextStyle(color: GRAYSCALE_LABEL_500, fontSize: 15),
                ),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '현재 ${meetUp.participants.length}명이 참석했습니다',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${meetUp.participants.length}/${meetUp.maxParticipants}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: meetUp.participants.length / meetUp.maxParticipants,
                    minHeight: 12,
                    backgroundColor: GRAYSCALE_LABEL_200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      selectedTeam?.color ?? BUTTON,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.people),
                    SizedBox(width: 5),
                    Text(
                      '전체 참여 인원 ${meetUp.maxParticipants}명',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '참석자 목록',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: GRAYSCALE_LABEL_500,
                  ),
                ),
                SizedBox(height: 10),
                Consumer<MeetupProvider>(
                  builder: (context, meetUpProvider, child) {
                    return FutureBuilder<List<UserModel>>(
                      future: meetUpProvider.getParticipantsInfo(
                        meetUp.participants,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: selectedTeam?.color ?? BUTTON,
                            ),
                          );
                        }
                        return SizedBox(
                          height: 410,
                          child: ListView.separated(
                            scrollDirection: Axis.vertical,
                            itemCount: snapshot.data!.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final user = snapshot.data![index];
                              final isHost = user.uid == meetUp.userId;
                              return Card(
                                color: WHITE,

                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border:
                                                  meetUp.attendedParticipants
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
                                                  ? Icon(
                                                      Icons.person,
                                                      size: 30,
                                                      color: WHITE,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          if (isHost)
                                            Positioned(
                                              top: 45,
                                              left: 20,
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
                                          if (meetUp.attendedParticipants
                                              .contains(user.uid))
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
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
                                                child: Row(
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
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Consumer<ProfileProvider>(
                                            builder:
                                                (
                                                  context,
                                                  profileProvider,
                                                  child,
                                                ) {
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
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  );
                                                },
                                          ),
                                          if (meetUp.attendedParticipants
                                              .contains(user.uid))
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 15,
                                                ),
                                                Text(
                                                  '출석완료',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
