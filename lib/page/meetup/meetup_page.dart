import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_upload_page.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class MeetupPage extends StatefulWidget {
  const MeetupPage({super.key});

  @override
  State<MeetupPage> createState() => _MeetupPageState();
}

class _MeetupPageState extends State<MeetupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetupProvider>().fetchMeetups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: selectedTeam?.color ?? BUTTON,
        scrolledUnderElevation: 0,
        title: Text(
          '함께 직관 가요!',
          style: TextStyle(
            color: WHITE,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: WHITE),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MeetupUploadPage()),
              );
            },
            icon: Icon(Icons.add, color: WHITE),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildMeetupList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Consumer2<MeetupProvider, TeamProvider>(
      builder: (context, meetUpProvider, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam?.color;
        return Container(
          padding: const EdgeInsets.all(16),
          color: WHITE,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selectedStadium ?? '구장 전체',
                      onTap: () => _showStadiumFilter(context),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selecteedTeam ?? '팀 전체',
                      onTap: () => _showTeamFilter(context),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selectedDate != null
                          ? '${meetUpProvider.selectedDate!.month}/${meetUpProvider.selectedDate!.day}'
                          : '날짜 전체',
                      onTap: () =>
                          _showDateFilter(context, selectedTeam ?? BUTTON),
                    ),
                  ),
                ],
              ),
              if (meetUpProvider.selectedStadium != null ||
                  meetUpProvider.selecteedTeam != null ||
                  meetUpProvider.selectedDate != null)
                TextButton(
                  onPressed: () => meetUpProvider.clearFileters(),
                  child: Text('필터 초기화', style: TextStyle(color: BLACK)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: GRAYSCALE_LABEL_300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetupList() {
    return Consumer2<MeetupProvider, TeamProvider>(
      builder: (context, meetUpProvider, teamProvider, child) {
        if (meetUpProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: teamProvider.selectedTeam?.color,
            ),
          );
        }

        final meetups = meetUpProvider.filteredMeetups;

        if (meetups.isEmpty) {
          return Center(child: Text('등록된 모임이 없습니다'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: meetups.length,
          itemBuilder: (context, index) {
            return _buildMeetupCard(meetups[index]);
          },
        );
      },
    );
  }

  Widget _buildMeetupCard(MeetupModel meetup) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isParticipating =
        currentUserId != null && meetup.participants.contains(currentUserId);
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;

    return Card(
      color: WHITE,
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MeetupDetailPage(meetup: meetup),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: GRAYSCALE_LABEL_300,
                    backgroundImage: meetup.userProfileImage != null
                        ? NetworkImage(meetup.userProfileImage!)
                        : null,
                    child: meetup.userProfileImage == null
                        ? const Icon(Icons.person, size: 20, color: WHITE)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    meetup.userNickName,
                    style: const TextStyle(
                      fontSize: 15,
                      color: BLACK,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  if (meetup.isFull)
                    Container(
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
                    )
                  else if (!isParticipating)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTeam?.color ?? BUTTON,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '모집 중',
                        style: TextStyle(color: WHITE, fontSize: 12),
                      ),
                    ),
                  if (isParticipating)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '참여중',
                        style: TextStyle(color: WHITE, fontSize: 12),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: meetup.homeTeam,
                                style: TextStyle(
                                  color:
                                      teamProvider
                                          .findTeamByName(meetup.homeTeam)
                                          ?.color ??
                                      BUTTON,
                                ),
                              ),
                              const TextSpan(
                                text: ' vs ',
                                style: TextStyle(color: BLACK),
                              ),
                              TextSpan(
                                text: meetup.awayTeam,
                                style: TextStyle(
                                  color:
                                      teamProvider
                                          .findTeamByName(meetup.awayTeam)
                                          ?.color ??
                                      BUTTON,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          meetup.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${DateFormat('MM월 dd일 (E)', 'ko').format(DateTime.parse(meetup.gameDate))} ${meetup.gameTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: GRAYSCALE_LABEL_500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: GRAYSCALE_LABEL_500,
                            ),
                            SizedBox(width: 4),
                            Text(
                              meetup.stadium,
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
                  if (meetup.images.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        meetup.images.first,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 18),
                  Text(
                    '${meetup.participants.length}/${meetup.maxParticipants}명',
                    style: TextStyle(
                      fontSize: 13,
                      color: meetup.isFull ? Colors.red : BUTTON,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStadiumFilter(BuildContext context) {
    final stadium = [
      '잠실야구장',
      '고척스카이돔',
      '수원KT위즈파크',
      '인천SSG랜더스필드',
      '대전한화생명볼파크',
      '광주기아챔피언스필드',
      '대구상성라이온즈파크',
      '창원NC파크',
      '사직야구장',
      '도쿄돔',
    ];
    showModalBottomSheet(
      backgroundColor: BACKGROUND_COLOR,
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.all(10),
          children: [
            ListTile(
              title: Text('전체'),
              onTap: () {
                context.read<MeetupProvider>().setStadiumFilter(null);
                Navigator.pop(context);
              },
            ),
            ...stadium.map((stadium) {
              return ListTile(
                title: Text(stadium),
                onTap: () {
                  context.read<MeetupProvider>().setStadiumFilter(stadium);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showTeamFilter(BuildContext context) {
    final teams = [
      '두산',
      'LG',
      '키움',
      'SSG',
      'KT',
      '한화',
      'KIA',
      '삼성',
      'NC',
      '롯데',
    ];
    showModalBottomSheet(
      backgroundColor: BACKGROUND_COLOR,
      context: context,
      builder: (context) {
        return ListView(
          padding: EdgeInsets.all(10),
          children: [
            ListTile(
              title: Text('전체'),
              onTap: () {
                context.read<MeetupProvider>().setTeamFilter(null);
                Navigator.pop(context);
              },
            ),
            ...teams.map((team) {
              return ListTile(
                title: Text(team),
                onTap: () {
                  context.read<MeetupProvider>().setTeamFilter(team);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  void _showDateFilter(BuildContext context, Color teamColor) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        final base = Theme.of(context);
        return Localizations.override(
          context: context,
          locale: Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: BACKGROUND_COLOR,
                headerBackgroundColor: BACKGROUND_COLOR,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: teamColor,
                surface: BACKGROUND_COLOR,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: teamColor),
              ),
            ),
            child: child!,
          ),
        );
      },
    );
    if (date != null) {
      context.read<MeetupProvider>().setDateFilter(date);
    }
  }
}
