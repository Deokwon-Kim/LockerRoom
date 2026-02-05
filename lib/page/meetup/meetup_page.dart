import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/chat_list_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_upload_page.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

class MeetupPage extends StatefulWidget {
  const MeetupPage({super.key});

  @override
  State<MeetupPage> createState() => _MeetupPageState();
}

class _MeetupPageState extends State<MeetupPage> {
  bool _isButtonVisible = true;
  double _lastScrollPosition = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetupProvider>().fetchMeetups();
    });
  }

  // 스크롤 방향 감지
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPosition = notification.metrics.pixels;
      final delta = currentPosition - _lastScrollPosition;

      if (delta > 5 && _isButtonVisible) {
        setState(() => _isButtonVisible = false);
      } else if (delta < -5 && !_isButtonVisible) {
        setState(() => _isButtonVisible = true);
      }

      _lastScrollPosition = currentPosition;
    }
    return false;
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
                MaterialPageRoute(builder: (context) => ChatListPage()),
              );
            },
            icon: TotalUnreadBadge(
              currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
              child: Icon(CupertinoIcons.paperplane_fill, color: WHITE),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: Column(
              children: [
                _buildFilterBar(),
                Expanded(child: _buildMeetupList()),
              ],
            ),
          ),

          AnimatedPositioned(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _isButtonVisible ? 70 : -100,
            right: 15,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 200),
              opacity: _isButtonVisible ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MeetupUploadPage()),
                  );
                },
                child: Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  decoration: BoxDecoration(
                    color: teamProvider.selectedTeam?.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.add, color: WHITE, size: 30),
                ),
              ),
            ),
          ),
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
              Consumer<ProfileProvider>(
                builder: (context, profileProvider, child) {
                  profileProvider.subscribeUserProfile(meetup.userId);

                  final url = profileProvider.userProfiles[meetup.userId];
                  final userNickName =
                      profileProvider.userNicknames[meetup.userId] ??
                      meetup.userNickName;
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: url != null ? NetworkImage(url) : null,
                        backgroundColor: GRAYSCALE_LABEL_300,
                        child: url == null
                            ? Icon(Icons.person, color: Colors.black, size: 15)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userNickName,
                        style: TextStyle(
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
                            style: TextStyle(color: WHITE, fontSize: 12),
                          ),
                        ),
                    ],
                  );
                },
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
                                text: meetup.awayTeam,
                                style: TextStyle(
                                  color:
                                      teamProvider
                                          .findTeamByName(meetup.awayTeam)
                                          ?.color ??
                                      BUTTON,
                                ),
                              ),
                              const TextSpan(
                                text: ' vs ',
                                style: TextStyle(color: BLACK),
                              ),
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

class TotalUnreadBadge extends StatelessWidget {
  final String currentUserId;
  final Widget child;

  const TotalUnreadBadge({
    super.key,
    required this.currentUserId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) return child;

    return StreamBuilder<List<MeetupModel>>(
      stream: context.read<MeetupProvider>().getJoinedMeetupStream(
        currentUserId,
      ),
      builder: (context, snapshot) {
        final meetups = snapshot.data ?? [];
        if (meetups.isEmpty) return child;

        return _TotalCountAggregator(
          meetupIds: meetups.map((m) => m.id).toList(),
          currentUserId: currentUserId,
          child: child,
        );
      },
    );
  }
}

class _TotalCountAggregator extends StatefulWidget {
  final List<String> meetupIds;
  final String currentUserId;
  final Widget child;

  const _TotalCountAggregator({
    required this.meetupIds,
    required this.currentUserId,
    required this.child,
  });

  @override
  State<_TotalCountAggregator> createState() => _TotalCountAggregatorState();
}

class _TotalCountAggregatorState extends State<_TotalCountAggregator> {
  final Map<String, int> _unreadCounts = {};

  @override
  Widget build(BuildContext context) {
    int totalUnread = _unreadCounts.values.fold(0, (sum, count) => sum + count);

    return badges.Badge(
      showBadge: totalUnread > 0,
      position: badges.BadgePosition.topEnd(top: -10, end: -10),
      badgeContent: Text(
        totalUnread > 99 ? '99+' : '$totalUnread',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Colors.red,
        padding: EdgeInsets.all(4),
      ),
      child: Stack(
        children: [
          widget.child,
          // 각 채팅방의 읽음 상태를 감시하는 투명한 위젯들
          ...widget.meetupIds.map(
            (id) => _UnreadListener(
              key: ValueKey(id),
              meetupId: id,
              currentUserId: widget.currentUserId,
              onCountChanged: (count) {
                if (_unreadCounts[id] != count) {
                  setState(() {
                    _unreadCounts[id] = count;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadListener extends StatefulWidget {
  final String meetupId;
  final String currentUserId;
  final Function(int) onCountChanged;

  const _UnreadListener({
    super.key,
    required this.meetupId,
    required this.currentUserId,
    required this.onCountChanged,
  });

  @override
  State<_UnreadListener> createState() => _UnreadListenerState();
}

class _UnreadListenerState extends State<_UnreadListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didUpdateWidget(_UnreadListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetupId != widget.meetupId) {
      _subscription?.cancel();
      _startListening();
    }
  }

  void _startListening() {
    // 1. 유저의 마지막 읽은 시간 가져오기
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .collection('readStatus')
        .doc(widget.meetupId)
        .snapshots()
        .listen((readSnapshot) {
          if (!mounted) return;
          final readData = readSnapshot.data();
          final lastReadAt = readData?['lastReadAt'] as Timestamp?;

          _subscription?.cancel();
          // 2. 마지막 읽은 시간 이후의 메시지 개수 감시 (본인 메시지 제외)
          _subscription = FirebaseFirestore.instance
              .collection('meetups')
              .doc(widget.meetupId)
              .collection('messages')
              .where(
                'createdAt',
                isGreaterThan:
                    lastReadAt ?? Timestamp.fromMillisecondsSinceEpoch(0),
              )
              .snapshots()
              .listen((msgSnapshot) {
                if (!mounted) return;
                final docs = msgSnapshot.docs;
                int unreadCount = docs
                    .where(
                      (doc) => (doc.data())['authorId'] != widget.currentUserId,
                    )
                    .length;
                widget.onCountChanged(unreadCount);
              });
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
