import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/mate_checklist_model.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/page/meetup/chat_list_page.dart';
import 'package:lockerroom/page/meetup/mate_checklist_page.dart';
import 'package:lockerroom/page/meetup/meetup_detail_page.dart';
import 'package:lockerroom/page/meetup/meetup_upload_page.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;

enum _MateQuickFilter { all, smallGroup, highMatch, nonSmoke, watchUntilEnd }

class MeetupPage extends StatefulWidget {
  const MeetupPage({super.key});

  @override
  State<MeetupPage> createState() => _MeetupPageState();
}

class _MeetupPageState extends State<MeetupPage> {
  bool _isButtonVisible = true;
  double _lastScrollPosition = 0;
  bool _isMyMeetupsExpanded = true;
  _MateQuickFilter _mateFilter = _MateQuickFilter.all;
  MateChecklistModel? _myChecklist;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetupProvider>().fetchMeetups();
      _loadMyChecklist();
    });
  }

  Future<void> _loadMyChecklist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final raw = doc.data()?['mateChecklist'];
      if (raw is Map<String, dynamic> && mounted) {
        setState(() {
          _myChecklist = MateChecklistModel.fromMap(raw);
        });
      }
    } catch (_) {}
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

    final rawTeamColor = selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(rawTeamColor);
    final fabTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          '함께 직관 가요!',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatListPage()),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Center(
                    child: TotalUnreadBadge(
                      currentUserId:
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                      child: Icon(
                        CupertinoIcons.paperplane_fill,
                        color: context.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _isButtonVisible ? 72 : -100,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isButtonVisible ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MeetupUploadPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: fabTextColor, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '모임 만들기',
                        style: TextStyle(
                          color: fabTextColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          color: context.bgColor,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selectedStadium ?? '구장 전체',
                      isActive: meetUpProvider.selectedStadium != null,
                      onTap: () => _showStadiumFilter(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selecteedTeam ?? '팀 전체',
                      isActive: meetUpProvider.selecteedTeam != null,
                      onTap: () => _showTeamFilter(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      label: meetUpProvider.selectedDate != null
                          ? '${meetUpProvider.selectedDate!.month}/${meetUpProvider.selectedDate!.day}'
                          : '날짜 전체',
                      isActive: meetUpProvider.selectedDate != null,
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
                  child: Text(
                    '필터 초기화',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip({
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final accentColor = context.readableColor(
      context.read<TeamProvider>().selectedTeam?.color ?? BUTTON,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.1)
              : context.cardColor,
          border: Border.all(
            color: isActive ? accentColor : context.borderColor,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? accentColor : context.textPrimary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive ? accentColor : context.textSecondary,
            ),
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

        final rawMeetups = meetUpProvider.filteredMeetups;
        final meetups = rawMeetups.where((m) {
          switch (_mateFilter) {
            case _MateQuickFilter.all:
              return true;
            case _MateQuickFilter.smallGroup:
              return m.isSmallGroup;
            case _MateQuickFilter.highMatch:
              if (_myChecklist == null || m.mateTags == null) return false;
              return _myChecklist!.calculateMatchPercent(m.mateTags!) >= 80;
            case _MateQuickFilter.nonSmoke:
              return m.mateTags?.isNonSmoke ?? false;
            case _MateQuickFilter.watchUntilEnd:
              return m.mateTags?.isWatchUntilEnd ?? false;
          }
        }).toList();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildMateChecklistBanner(teamProvider.selectedTeam?.color),
            const SizedBox(height: 10),
            _buildMateQuickFilterRow(teamProvider.selectedTeam?.color),
            const SizedBox(height: 12),
            if (currentUserId != null)
              StreamBuilder<List<MeetupModel>>(
                stream: meetUpProvider.getAppliedMeetupStream(currentUserId),
                builder: (context, snapshot) {
                  final myMeetups = snapshot.data ?? [];
                  if (myMeetups.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '내 모임',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isMyMeetupsExpanded = !_isMyMeetupsExpanded;
                              });
                            },
                            icon: Icon(
                              _isMyMeetupsExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 18,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                      if (_isMyMeetupsExpanded) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: myMeetups.length,
                            itemBuilder: (context, index) {
                              final meetup = myMeetups[index];
                              final isPending = meetup.pendingParticipants
                                  .contains(currentUserId);
                              return _buildMyMeetupCard(meetup, isPending);
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '모든 모임',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            if (meetups.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('등록된 모임이 없습니다'),
                ),
              )
            else
              ...meetups.map((meetup) => _buildMeetupCard(meetup)),
          ],
        );
      },
    );
  }

  Widget _buildMyMeetupCard(MeetupModel meetup, bool isPending) {
    final teamProvider = context.read<TeamProvider>();
    final teamColor =
        teamProvider.findTeamByName(meetup.myTeam)?.color ?? BUTTON;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'MeetupDetailPage'),
            builder: (context) => MeetupDetailPage(meetup: meetup),
          ),
        );
      },
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 배경 이미지
              if (meetup.images.isNotEmpty)
                Image.network(
                  meetup.images.first,
                  width: 210,
                  height: 140,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  width: 210,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [teamColor, teamColor.withValues(alpha: 0.72)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.stadium_outlined, color: WHITE, size: 32),
                  ),
                ),

              // 그라데이션 오버레이 (텍스트 가독성)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // 카드 내용
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? WHITE.withOpacity(0.9)
                                : teamColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPending ? '대기중' : '참여중',
                            style: TextStyle(
                              color: isPending ? BLACK : WHITE,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${DateFormat('MM/dd(E)', 'ko').format(DateTime.parse(meetup.gameDate))} ${meetup.gameTime}', // MM-DD
                          style: const TextStyle(
                            fontSize: 10,
                            color: WHITE,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      meetup.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: WHITE,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          meetup.awayTeam,
                          style: TextStyle(
                            fontSize: 11,
                            color: WHITE,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          ' vs ',
                          style: TextStyle(fontSize: 11, color: WHITE),
                        ),
                        Text(
                          meetup.homeTeam,
                          style: TextStyle(
                            fontSize: 11,
                            color: WHITE,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetupCard(MeetupModel meetup) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isParticipating =
        currentUserId != null && meetup.participants.contains(currentUserId);
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;

    return Card(
      color: context.cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'MeetupDetailPage'),
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
                          color: context.textPrimary,
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
                                  color: context.readableColor(
                                    teamProvider
                                            .findTeamByName(meetup.awayTeam)
                                            ?.color ??
                                        BUTTON,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: ' vs ',
                                style: TextStyle(color: context.textPrimary),
                              ),
                              TextSpan(
                                text: meetup.homeTeam,
                                style: TextStyle(
                                  color: context.readableColor(
                                    teamProvider
                                            .findTeamByName(meetup.homeTeam)
                                            ?.color ??
                                        BUTTON,
                                  ),
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
              if (meetup.mateTags != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_myChecklist != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '성향 ${_myChecklist!.calculateMatchPercent(meetup.mateTags!)}% 일치',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ...meetup.mateTags!
                        .toSummaryTags(maxTags: 3)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: meetup.maxParticipants > 0
                            ? (meetup.participants.length /
                                      meetup.maxParticipants)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: context.surfaceAltColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          meetup.isFull
                              ? Colors.red
                              : context.readableColor(
                                  selectedTeam?.color ?? BUTTON,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    meetup.isFull
                        ? '${meetup.participants.length}/${meetup.maxParticipants}명 · 모집 마감'
                        : '${meetup.participants.length}/${meetup.maxParticipants}명 · ${meetup.remainingSlots}자리 남음',
                    style: TextStyle(
                      fontSize: 12,
                      color: meetup.isFull ? Colors.red : context.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        meetup.isApprovalRequired
                            ? Icons.lock_outline_rounded
                            : Icons.bolt_rounded,
                        size: 14,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        meetup.isApprovalRequired ? '방장 승인' : '바로 참여',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
      backgroundColor: context.cardColor,
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            ListTile(
              title: Text('전체', style: TextStyle(color: context.textPrimary)),
              onTap: () {
                context.read<MeetupProvider>().setStadiumFilter(null);
                Navigator.pop(context);
              },
            ),
            ...stadium.map((stadium) {
              return ListTile(
                title: Text(
                  stadium,
                  style: TextStyle(color: context.textPrimary),
                ),
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
      backgroundColor: context.cardColor,
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(10),
          children: [
            ListTile(
              title: Text('전체', style: TextStyle(color: context.textPrimary)),
              onTap: () {
                context.read<MeetupProvider>().setTeamFilter(null);
                Navigator.pop(context);
              },
            ),
            ...teams.map((team) {
              return ListTile(
                title: Text(team, style: TextStyle(color: context.textPrimary)),
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final base = Theme.of(context);
        final readableTeam = context.readableColor(teamColor);
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: context.cardColor,
                headerBackgroundColor: context.cardColor,
                headerForegroundColor: context.textPrimary,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: readableTeam,
                onPrimary:
                    context.isDarkMode && readableTeam.computeLuminance() > 0.5
                    ? BLACK
                    : WHITE,
                surface: context.cardColor,
                onSurface: context.textPrimary,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: readableTeam),
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

  Widget _buildMateChecklistBanner(Color? rawTeamColor) {
    final accentColor = context.readableColor(rawTeamColor ?? BUTTON);
    final hasChecklist = _myChecklist != null;
    final hiColor = _myChecklist?.highlightColor ?? accentColor;

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.push<MateChecklistModel>(
          context,
          MaterialPageRoute(
            builder: (_) => MateChecklistPage(initialTab: hasChecklist ? 1 : 0),
          ),
        );
        if (updated != null && mounted) {
          setState(() => _myChecklist = updated);
        } else {
          _loadMyChecklist();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: hiColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.checklist_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasChecklist
                        ? '내 직관메이트 체크리스트 · 공유 카드'
                        : '내 직관메이트 체크리스트 만들기',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasChecklist
                        ? '성향 매칭 활성화됨 · 탭해서 수정 또는 SNS 공유'
                        : '체크해 두면 나와 잘 맞는 직관모임 매칭률(%)을 보여드려요',
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMateQuickFilterRow(Color? rawTeamColor) {
    final accentColor = context.readableColor(rawTeamColor ?? BUTTON);
    final selectedTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;

    const items = <MapEntry<_MateQuickFilter, String>>[
      MapEntry(_MateQuickFilter.all, '전체'),
      MapEntry(_MateQuickFilter.smallGroup, '소수정예 4명 이하'),
      MapEntry(_MateQuickFilter.highMatch, '성향 80%+'),
      MapEntry(_MateQuickFilter.nonSmoke, '비흡연'),
      MapEntry(_MateQuickFilter.watchUntilEnd, '끝까지 봄'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final entry = items[idx];
          final selected = _mateFilter == entry.key;
          return GestureDetector(
            onTap: () => setState(() => _mateFilter = entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? accentColor : context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? accentColor : context.borderColor,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? selectedTextColor : context.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
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
        .listen(
          (readSnapshot) {
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
                .listen(
                  (msgSnapshot) {
                    if (!mounted) return;
                    final docs = msgSnapshot.docs;
                    int unreadCount = docs
                        .where(
                          (doc) =>
                              (doc.data())['authorId'] != widget.currentUserId,
                        )
                        .length;
                    widget.onCountChanged(unreadCount);
                  },
                  onError: (e) {
                    debugPrint('안읽은 메시지 메시지 스트림 오류: $e');
                  },
                );
          },
          onError: (e) {
            debugPrint('안읽은 메시지 읽음상태 스트림 오류: $e');
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
