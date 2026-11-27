import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

enum _AttendanceFilter { all, attended, notAttended }

class MeetupPeoplePage extends StatefulWidget {
  final MeetupModel meetUp;
  const MeetupPeoplePage({super.key, required this.meetUp});

  @override
  State<MeetupPeoplePage> createState() => _MeetupPeoplePageState();
}

class _MeetupPeoplePageState extends State<MeetupPeoplePage> {
  _AttendanceFilter _selectedFilter = _AttendanceFilter.all;
  late Future<List<UserModel>> _participantsFuture;

  @override
  void initState() {
    super.initState();
    _participantsFuture = context.read<MeetupProvider>().getParticipantsInfo(
      widget.meetUp.participants,
    );
  }

  @override
  void didUpdateWidget(covariant MeetupPeoplePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetUp.participants != widget.meetUp.participants) {
      _participantsFuture = context.read<MeetupProvider>().getParticipantsInfo(
        widget.meetUp.participants,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final rawTeamColor = selectedTeam?.color ?? BUTTON;
    final accentColor = context.readableColor(rawTeamColor);

    final meetUp = widget.meetUp;
    final participantCount = meetUp.participants.length;
    final maxParticipants = meetUp.maxParticipants;
    final attendedSet = meetUp.attendedParticipants.toSet();
    final attendedCount = meetUp.participants
        .where((uid) => attendedSet.contains(uid))
        .length;
    final notAttendedCount = (participantCount - attendedCount).clamp(
      0,
      participantCount,
    );
    final remainingCount = (maxParticipants - participantCount).clamp(
      0,
      maxParticipants,
    );
    final progress = maxParticipants > 0
        ? (participantCount / maxParticipants).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          '참석 명단',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$participantCount/$maxParticipants명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _SummaryHeroCard(
              meetUp: meetUp,
              accentColor: accentColor,
              participantCount: participantCount,
              attendedCount: attendedCount,
              remainingCount: remainingCount,
              progress: progress,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChipItem(
                  label: '전체 $participantCount',
                  isSelected: _selectedFilter == _AttendanceFilter.all,
                  accentColor: accentColor,
                  onTap: () =>
                      setState(() => _selectedFilter = _AttendanceFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: '출석 완료 $attendedCount',
                  isSelected: _selectedFilter == _AttendanceFilter.attended,
                  accentColor: accentColor,
                  onTap: () => setState(
                    () => _selectedFilter = _AttendanceFilter.attended,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: '미출석 $notAttendedCount',
                  isSelected: _selectedFilter == _AttendanceFilter.notAttended,
                  accentColor: accentColor,
                  onTap: () => setState(
                    () => _selectedFilter = _AttendanceFilter.notAttended,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UserModel>>(
              future: _participantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _EmptyParticipantsView(
                    message: '아직 참여한 멤버가 없습니다.',
                  );
                }

                final sortedUsers = List<UserModel>.from(snapshot.data!)
                  ..sort((a, b) {
                    final aIsHost = a.uid == meetUp.userId;
                    final bIsHost = b.uid == meetUp.userId;
                    if (aIsHost != bIsHost) return aIsHost ? -1 : 1;

                    final aAttended = attendedSet.contains(a.uid);
                    final bAttended = attendedSet.contains(b.uid);
                    if (aAttended != bAttended) return aAttended ? -1 : 1;
                    return 0;
                  });

                final filteredUsers = sortedUsers.where((user) {
                  final isAttended = attendedSet.contains(user.uid);
                  switch (_selectedFilter) {
                    case _AttendanceFilter.all:
                      return true;
                    case _AttendanceFilter.attended:
                      return isAttended;
                    case _AttendanceFilter.notAttended:
                      return !isAttended;
                  }
                }).toList();

                if (filteredUsers.isEmpty) {
                  final emptyMessage =
                      _selectedFilter == _AttendanceFilter.attended
                      ? '아직 출석 완료된 멤버가 없습니다.'
                      : '미출석 멤버가 없습니다.';
                  return _EmptyParticipantsView(message: emptyMessage);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final isHost = user.uid == meetUp.userId;
                    final isAttended = attendedSet.contains(user.uid);
                    return _ParticipantCard(
                      user: user,
                      isHost: isHost,
                      isAttended: isAttended,
                      accentColor: accentColor,
                      hostBadgeColor: rawTeamColor,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeroCard extends StatelessWidget {
  final MeetupModel meetUp;
  final Color accentColor;
  final int participantCount;
  final int attendedCount;
  final int remainingCount;
  final double progress;

  const _SummaryHeroCard({
    required this.meetUp,
    required this.accentColor,
    required this.participantCount,
    required this.attendedCount,
    required this.remainingCount,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenColor = isDark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF16A34A);

    final gameMetaParts = <String>[
      if (meetUp.awayTeam.isNotEmpty && meetUp.homeTeam.isNotEmpty)
        '${meetUp.awayTeam} vs ${meetUp.homeTeam}',
      if (meetUp.gameDate.isNotEmpty || meetUp.gameTime.isNotEmpty)
        '${meetUp.gameDate} ${meetUp.gameTime}'.trim(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🏟️ ${meetUp.stadium} 직관모임',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ),
          if (meetUp.title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              meetUp.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
          ],
          if (gameMetaParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              gameMetaParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '현재 $participantCount명이 참석했습니다',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: context.surfaceAltColor,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: context.surfaceAltColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricColumn(
                    label: '참석 인원',
                    value: '$participantCount명',
                    valueColor: context.textPrimary,
                  ),
                ),
                Container(width: 1, height: 28, color: context.borderColor),
                Expanded(
                  child: _MetricColumn(
                    label: '출석 완료',
                    value: '$attendedCount명',
                    valueColor: greenColor,
                  ),
                ),
                Container(width: 1, height: 28, color: context.borderColor),
                Expanded(
                  child: _MetricColumn(
                    label: '남은 자리',
                    value: remainingCount > 0 ? '$remainingCount자리' : '마감',
                    valueColor: remainingCount > 0
                        ? accentColor
                        : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedTextColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? WHITE
        : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : context.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? selectedTextColor : context.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final UserModel user;
  final bool isHost;
  final bool isAttended;
  final Color accentColor;
  final Color hostBadgeColor;

  const _ParticipantCard({
    required this.user,
    required this.isHost,
    required this.isAttended,
    required this.accentColor,
    required this.hostBadgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenColor = isDark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF16A34A);
    final greenBg = isDark
        ? const Color(0xFF16A34A).withValues(alpha: 0.18)
        : const Color(0xFFDCFCE7);

    final subText = isHost
        ? '모임 방장 · ${isAttended ? '현장 출석 확인' : '출석 대기'}'
        : (isAttended ? '현장 출석 확인' : '출석 대기');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isAttended
                  ? Border.all(color: greenColor, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: GRAYSCALE_LABEL_300,
              backgroundImage: (user.profileImage?.isNotEmpty ?? false)
                  ? NetworkImage(user.profileImage!)
                  : null,
              child: (user.profileImage?.isEmpty ?? true)
                  ? const Icon(Icons.person, size: 26, color: WHITE)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Consumer<ProfileProvider>(
                        builder: (context, profileProvider, child) {
                          profileProvider.subscribeUserProfile(user.uid);
                          final nickname =
                              profileProvider.userNicknames[user.uid] ??
                              user.userNickName;
                          return Text(
                            nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          );
                        },
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hostBadgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: WHITE,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subText,
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAttended ? greenBg : context.surfaceAltColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAttended) ...[
                  Icon(Icons.check, size: 13, color: greenColor),
                  const SizedBox(width: 3),
                ],
                Text(
                  isAttended ? '출석완료' : '미출석',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAttended ? greenColor : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyParticipantsView extends StatelessWidget {
  final String message;

  const _EmptyParticipantsView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 42, color: context.textMuted),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
