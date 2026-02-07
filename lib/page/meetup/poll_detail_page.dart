import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final String authorId;
  final DateTime? createdAt;

  const PollDetailPage({
    super.key,
    required this.meetupId,
    required this.messageId,
    required this.question,
    required this.options,
    required this.votes,
    required this.deadLine,
    required this.authorId,
    this.createdAt,
  });

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  late Map<String, List<String>> _currentVotes;
  late String _currentQuestion;
  late List<String> _currentOptions;
  late Timestamp? _currentDeadLine;
  late bool _isClosed;
  late bool _allowMultiple;

  @override
  void initState() {
    super.initState();
    _currentVotes = Map<String, List<String>>.from(
      widget.votes.map((key, value) => MapEntry(key, List<String>.from(value))),
    );
    _currentQuestion = widget.question;
    _currentOptions = List<String>.from(widget.options);
    _currentDeadLine = widget.deadLine;
    _isClosed = widget.votes['isClosed'] ?? false;
    _allowMultiple = widget.votes['allowMultiple'] ?? false;

    // 내가 투표한 항목 찾기
    // _updateMyVote는 더 이상 필요하지 않음 (voters list에서 직접 확인)

    _setupPollStream();
  }

  void _setupPollStream() {
    FirebaseFirestore.instance
        .collection('meetups')
        .doc(widget.meetupId)
        .collection('messages')
        .doc(widget.messageId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data()!;
              final metadata = data['metadata'];
              if (metadata != null) {
                setState(() {
                  _currentQuestion = metadata['question'] ?? _currentQuestion;
                  _currentOptions = List<String>.from(
                    metadata['options'] ?? _currentOptions,
                  );
                  _currentDeadLine =
                      metadata['deadLine'] as Timestamp? ?? _currentDeadLine;
                  _isClosed = metadata['isClosed'] ?? false;
                  _allowMultiple = metadata['allowMultiple'] ?? false;
                  _currentVotes = Map<String, List<String>>.from(
                    (metadata['votes'] as Map? ?? {}).map(
                      (k, v) => MapEntry(
                        k.toString(),
                        List<String>.from(v as List? ?? []),
                      ),
                    ),
                  );
                });
              }
            }
          },
          onError: (e) {
            debugPrint('투표 상세 스트림 오류: $e');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final endTime = _currentDeadLine?.toDate() ?? now;
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
        scrolledUnderElevation: 0,
        actions: [
          if (widget.authorId == FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              onPressed: _showEditPollSheet,
              icon: const Icon(Icons.edit_note),
            ),
          _buildMoreMenu(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildAuthorInfo()],
            ),
          ),

          // 타이머 헤더
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(left: 15, top: 15, right: 15),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentQuestion,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildTimerHeader(endTime, isExpired, totalVotes),
                  ],
                ),

                SizedBox(height: 24),

                // 투표 옵션
                ..._currentOptions.map((option) {
                  final voters = _currentVotes[option] ?? [];
                  final percent = totalVotes > 0
                      ? (voters.length / totalVotes).toDouble()
                      : 0.0;
                  final currentUserId =
                      FirebaseAuth.instance.currentUser?.uid ?? '';
                  final isMyVote = voters.contains(currentUserId);

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

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              isExpired || _isClosed ? '' : '종료까지',
              style: TextStyle(
                color: GRAYSCALE_LABEL_700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 4),
            Text(
              isExpired || _isClosed
                  ? '투표가 마감되었습니다'
                  : _formatDetailedTime(remaining),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isExpired || _isClosed
                    ? RED_DANGER_TEXT_50
                    : GRAYSCALE_LABEL_700,
              ),
            ),
            SizedBox(width: 4),
            Text(
              isExpired || _isClosed ? '$totalVotes명 참여' : '총$totalVotes명 참여 중',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: GRAYSCALE_LABEL_700,
                fontSize: 14,
              ),
            ),
          ],
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
    final bool canVote = !isExpired && !_isClosed;
    final teamProvider = context.read<TeamProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: canVote ? () => _handleVote(option) : null,
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
      if (!_allowMultiple) {
        // 단일 투표: 기존 투표 모두 제거 후 새로 추가
        _currentVotes.forEach((key, value) {
          value.remove(currentUserId);
        });
        if (!_currentVotes.containsKey(option)) {
          _currentVotes[option] = [];
        }
        _currentVotes[option]!.add(currentUserId);
      } else {
        // 복수 투표: 해당 항목 토글
        if (!_currentVotes.containsKey(option)) {
          _currentVotes[option] = [];
        }
        if (_currentVotes[option]!.contains(currentUserId)) {
          _currentVotes[option]!.remove(currentUserId);
        } else {
          _currentVotes[option]!.add(currentUserId);
        }
      }
    });

    // Firestore 업데이트
    context.read<ChatProvider>().votePoll(
      widget.meetupId,
      widget.messageId,
      currentUserId,
      option,
    );
  }

  Widget _buildAuthorInfo() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.authorId)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final nickname = userData?['userNickName'] ?? '탈퇴한 사용자';
        final profileImage = userData?['profileImage'] as String?;

        String dateStr = '';
        if (widget.createdAt != null) {
          final date = widget.createdAt!;
          dateStr =
              '${date.year}. ${date.month}. ${date.day}. ${date.hour > 12 ? '오후' : '오전'} ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')}';
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: GRAYSCALE_LABEL_300,
              backgroundImage: profileImage != null
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage == null
                  ? const Icon(Icons.person, size: 20, color: WHITE)
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: BLACK,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GRAYSCALE_LABEL_500,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showEditPollSheet() {
    final questionController = TextEditingController(text: _currentQuestion);
    final teamProvider = context.read<TeamProvider>();
    final List<TextEditingController> optionControllers = _currentOptions
        .map((opt) => TextEditingController(text: opt))
        .toList();
    DateTime selectedDeadLine =
        _currentDeadLine?.toDate() ??
        DateTime.now().add(const Duration(hours: 24));
    bool allowMultiple = _allowMultiple;

    showModalBottomSheet(
      backgroundColor: BACKGROUND_COLOR,
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '투표 수정하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                cursorColor: teamProvider.selectedTeam?.color,
                controller: questionController,
                decoration: InputDecoration(
                  hintText: '질문을 입력하세요',
                  hintStyle: const TextStyle(color: GRAYSCALE_LABEL_400),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GRAYSCALE_LABEL_400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: teamProvider.selectedTeam?.color ?? BUTTON,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ...optionControllers.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            hintText: '항목 ${entry.key + 1}',
                            hintStyle: const TextStyle(
                              color: GRAYSCALE_LABEL_400,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: GRAYSCALE_LABEL_400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    teamProvider.selectedTeam?.color ?? BUTTON,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (optionControllers.length > 2)
                        IconButton(
                          onPressed: () {
                            setSheetState(() {
                              optionControllers.removeAt(entry.key);
                            });
                          },
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              SwitchListTile(
                title: const Text('복수 투표 허용'),
                value: allowMultiple,
                onChanged: (val) => setSheetState(() => allowMultiple = val),
              ),
              ListTile(
                title: const Text('마감 시간 설정'),
                subtitle: Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(selectedDeadLine),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().isBefore(selectedDeadLine)
                        ? DateTime.now()
                        : selectedDeadLine,
                    lastDate: DateTime(2030),
                    initialDate: selectedDeadLine,
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(selectedDeadLine),
                    );
                    if (time != null) {
                      setSheetState(() {
                        selectedDeadLine = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              if (optionControllers.length < 10)
                TextButton.icon(
                  onPressed: () {
                    setSheetState(() {
                      optionControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: GRAYSCALE_LABEL_500,
                  ),
                  label: const Text(
                    '항목 추가',
                    style: TextStyle(color: GRAYSCALE_LABEL_600),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    final question = questionController.text.trim();
                    final options = optionControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    if (question.isNotEmpty && options.length >= 2) {
                      await context.read<ChatProvider>().updatePoll(
                        widget.meetupId,
                        widget.messageId,
                        question: question,
                        options: options,
                        deadLine: selectedDeadLine,
                        allowMultiple: allowMultiple,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teamProvider.selectedTeam?.color ?? BUTTON,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '수정 완료',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu() {
    final isAuthor = widget.authorId == FirebaseAuth.instance.currentUser?.uid;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        if (value == 'delete') {
          _handleDeletePoll();
        } else if (value == 'toggle_close') {
          _handleToggleClosePoll();
        }
      },
      itemBuilder: (context) => [
        if (isAuthor) ...[
          PopupMenuItem(
            value: 'toggle_close',
            child: Text(_isClosed ? '투표 재개하기' : '투표 강제종료'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('투표 삭제하기', style: TextStyle(color: RED_DANGER_TEXT_50)),
          ),
        ],
        const PopupMenuItem(value: 'report', child: Text('신고하기')),
      ],
    );
  }

  void _handleDeletePoll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('투표 삭제'),
        content: const Text('정말 이 투표를 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: GRAYSCALE_LABEL_600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 다이얼로그 닫기
              await context.read<ChatProvider>().deleteMessage(
                widget.meetupId,
                widget.messageId,
              );
              if (mounted) Navigator.pop(context); // 상세 페이지 닫기
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: RED_DANGER_TEXT_50),
            ),
          ),
        ],
      ),
    );
  }

  void _handleToggleClosePoll() {
    context.read<ChatProvider>().togglePollClosed(
      widget.meetupId,
      widget.messageId,
      !_isClosed,
    );
  }
}
