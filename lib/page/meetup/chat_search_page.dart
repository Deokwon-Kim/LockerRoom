import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/user_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class ChatSearchPage extends StatefulWidget {
  final List<Message> messages;
  final List<UserModel> participants;

  const ChatSearchPage({
    super.key,
    required this.messages,
    required this.participants,
  });

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Message> _searchResults = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query == _query) return;

    setState(() {
      _query = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults =
            widget.messages.where((m) {
              if (m is TextMessage) {
                return m.text.toLowerCase().contains(query);
              }
              return false;
            }).toList()..sort((a, b) {
              // 최신순 정렬 (createdAt은 DateTime?)
              final aTime = a.createdAt;
              final bTime = b.createdAt;
              // DateTime 비교 핸들링
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR, // 배경색 맞춤
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          cursorColor: teamProvider.selectedTeam?.color,
          decoration: const InputDecoration(
            hintText: '대화 내용 검색',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: BLACK),
        ),
        backgroundColor: WHITE,
        foregroundColor: BLACK,
        elevation: 0.5,
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: _query.isEmpty
          ? const Center(
              child: Text(
                '검색어를 입력하세요',
                style: TextStyle(color: GRAYSCALE_LABEL_400),
              ),
            )
          : _searchResults.isEmpty
          ? const Center(
              child: Text(
                '검색 결과가 없습니다',
                style: TextStyle(color: GRAYSCALE_LABEL_400),
              ),
            )
          : ListView.separated(
              itemCount: _searchResults.length,
              padding: const EdgeInsets.symmetric(vertical: 10),
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: GRAYSCALE_LABEL_200),
              itemBuilder: (context, index) {
                final message = _searchResults[index];
                return _buildResultTile(message);
              },
            ),
    );
  }

  Widget _buildResultTile(Message message) {
    if (message is! TextMessage) return const SizedBox.shrink();

    final date = message.createdAt ?? DateTime.now();
    final dateString = DateFormat('yyyy.MM.dd a h:mm', 'ko').format(date);

    // 참여자 목록에서 유저 정보 찾기 (authorId 이용)
    final user = widget.participants.firstWhere(
      (u) => u.uid == message.authorId,
      orElse: () => UserModel(
        uid: '',
        userNickName: '알 수 없음',
        name: '알 수 없음',
        useremail: '',
        followersCount: 0,
        followingCount: 0,
      ),
    );

    return ListTile(
      tileColor: WHITE,
      leading: CircleAvatar(
        backgroundImage:
            (user.profileImage != null && user.profileImage!.isNotEmpty)
            ? NetworkImage(user.profileImage!)
            : null,
        backgroundColor: GRAYSCALE_LABEL_300,
        child: (user.profileImage == null || user.profileImage!.isEmpty)
            ? const Icon(Icons.person, color: BLACK)
            : null,
      ),
      title: Text(
        user.userNickName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _highlightText(message.text, _query),
          const SizedBox(height: 4),
          Text(
            dateString,
            style: const TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
          ),
        ],
      ),
      onTap: () {
        // TODO: 클릭 시 해당 메시지로 이동 기능 (추후 구현)
        Navigator.pop(context);
        // 이동할 메시지 ID를 반환하려면 Navigator.pop(context, message.id) 사용 가능
      },
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final matches = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    final textLower = text.toLowerCase();

    while (true) {
      final index = textLower.indexOf(matches, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFF176),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(color: BLACK, fontSize: 14),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
