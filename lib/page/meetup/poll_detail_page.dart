import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/chat_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class PollDetailPage extends StatefulWidget {
  final String meetupId;
  final String messageId;
  final String question;
  final List<String> options;
  final Map<String, dynamic> votes;
  final Timestamp? deadLine;

  const PollDetailPage({
    super.key,
    required this.meetupId,
    required this.messageId,
    required this.question,
    required this.options,
    required this.votes,
    required this.deadLine,
  });

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  late Map<String, List<String>> _currentVotes;
  String? _myVote;

  @override
  void initState() {
    super.initState();
    _currentVotes = Map<String, List<String>>.from(
      widget.votes.map((key, value) => MapEntry(key, List<String>.from(value))),
    );

    // 내가 투표한 항목 찾기
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    for (var entry in _currentVotes.entries) {
      if (entry.value.contains(currentUserId)) {
        _myVote = entry.key;
        break;
      }
    }

    _setupPollStream();
  }

  void _setupPollStream() {
    FirebaseFirestore.instance
        .collection('meetups')
        .doc(widget.meetupId)
        .collection('messages')
        .doc(widget.messageId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data()!;
            final metadata = data['metadata'];
            setState(() {
              _currentVotes = Map<String, List<String>>.from(
                metadata['votes'].map(
                  (k, v) => MapEntry(k, List<String>.from(v)),
                ),
              );
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final endTime = widget.deadLine?.toDate() ?? now;
    final isExpired = now.isAfter(endTime);

    int totalVotes = 0;
    _currentVotes.forEach((key, value) {
      totalVotes += value.length;
    });

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: Text(
          '투표',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: context.read<TeamProvider>().selectedTeam?.color,
        foregroundColor: WHITE,
        actions: [IconButton(onPressed: () {}, icon: Icon(Icons.more_horiz))],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Text(
              widget.question,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
          ),
          // 타이머 헤더
          _buildTimerHeader(endTime, isExpired, totalVotes),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(left: 20, top: 30, right: 20),
              children: [
                Text(
                  '투표 선택지',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),

                // 투표 옵션
                ...widget.options.map((option) {
                  final voters = _currentVotes[option] ?? [];
                  final percent = totalVotes > 0
                      ? (voters.length / totalVotes).toDouble()
                      : 0.0;
                  final isMyVote = _myVote == option;

                  return _buildPollOption(
                    option: option,
                    voters: voters,
                    percent: percent,
                    isMyVote: isMyVote,
                    isExpired: isExpired,
                    context: context,
                  );
                }),
                SizedBox(height: 24),
                Center(
                  child: Text(
                    '총 $totalVotes명 참여',
                    style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerHeader(DateTime endTime, bool isExpired, int totalVotes) {
    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = endTime.difference(DateTime.now());

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: isExpired ? GRAYSCALE_LABEL_100 : BACKGROUND_COLOR,
            border: Border(bottom: BorderSide(color: GRAYSCALE_LABEL_200)),
          ),
          child: Row(
            children: [
              Text(
                '종료까지',
                style: TextStyle(
                  color: GRAYSCALE_LABEL_700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 4),
              Text(
                isExpired ? '투표가 마감되었습니다' : _formatDetailedTime(remaining),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isExpired ? RED_DANGER_TEXT_50 : GRAYSCALE_LABEL_700,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '$totalVotes명 참여 중',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: GRAYSCALE_LABEL_700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDetailedTime(Duration duration) {
    if (duration.isNegative) return '마감';
    final hours = duration.inHours;

    if (hours >= 1) {
      return '$hours시간 남음';
    } else {
      return '${duration.inMinutes}분 남음';
    }
  }

  Widget _buildPollOption({
    required BuildContext context,
    required String option,
    required List voters,
    required double percent,
    required bool isMyVote,
    required bool isExpired,
  }) {
    final teamProvider = context.read<TeamProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isExpired ? null : () => _handleVote(option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMyVote ? WHITE : GRAYSCALE_LABEL_50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMyVote
                  ? teamProvider.selectedTeam?.color ?? ORANGE_PRIMARY_500
                  : GRAYSCALE_LABEL_200,
              width: isMyVote ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isMyVote
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: BLACK,
                      ),
                    ),
                  ),
                  Text(
                    '${voters.length}명 (${(percent * 100).toInt()}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isMyVote
                          ? teamProvider.selectedTeam?.color
                          : GRAYSCALE_LABEL_600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: WHITE,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMyVote
                        ? teamProvider.selectedTeam?.color ??
                              teamProvider.selectedTeam?.color ??
                              ORANGE_PRIMARY_500
                        : GRAYSCALE_LABEL_400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleVote(String option) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() {
      _currentVotes.forEach((key, value) {
        value.remove(currentUserId);
      });

      // 새투표 추가
      if (!_currentVotes.containsKey(option)) {
        _currentVotes[option] = [];
      }
      _currentVotes[option]!.add(currentUserId);
      _myVote = option;
    });

    // Firestore 업데이트
    context.read<ChatProvider>().votePoll(
      widget.meetupId,
      widget.messageId,
      currentUserId,
      option,
    );
  }
}
