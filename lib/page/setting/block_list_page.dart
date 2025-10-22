import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/block_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});

  @override
  State<BlockListPage> createState() => _BlockListPageState();
}

class _BlockListPageState extends State<BlockListPage> {
  late Map<String, String> _userNamesCache;

  @override
  void initState() {
    super.initState();
    _userNamesCache = {};
  }

  Future<String> _getUserName(String userId) async {
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = doc.data()?['username'] ?? '알 수 없음';
      _userNamesCache[userId] = name;
      return name;
    } catch (e) {
      return '알 수 없음';
    }
  }

  Future<DateTime?> _getBlockedDate(String currentUserId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(userId)
          .get();
      final data = doc.data();
      final timestamp = data?['blockedAt'] as Timestamp?;
      return timestamp?.toDate();
    } catch (e) {
      return null;
    }
  }

  String _formatBlockedDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('차단 목록')),
        body: const Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        backgroundColor: WHITE,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '차단 목록',
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<BlockProvider>(
        builder: (context, blockProvider, child) {
          final blockedUserIds = blockProvider.blockedUserIds.toList();

          if (blockedUserIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_flipped,
                    size: 60,
                    color: GRAYSCALE_LABEL_400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '차단한 사용자가 없습니다',
                    style: TextStyle(fontSize: 16, color: GRAYSCALE_LABEL_600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blockedUserIds.length,
            itemBuilder: (context, index) {
              final userId = blockedUserIds[index];
              return FutureBuilder<String>(
                future: _getUserName(userId),
                builder: (context, snapshot) {
                  final userName = snapshot.data ?? '로딩 중...';

                  return FutureBuilder<DateTime?>(
                    future: _getBlockedDate(currentUserId, userId),
                    builder: (context, dateSnapshot) {
                      final blockedDate = dateSnapshot.data;
                      final formattedDate = _formatBlockedDate(blockedDate);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: GRAYSCALE_LABEL_50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: GRAYSCALE_LABEL_950,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        '차단한 날짜: $formattedDate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: GRAYSCALE_LABEL_600,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    _showUnblockDialog(
                                      context,
                                      userName,
                                      userId,
                                      currentUserId,
                                      blockProvider,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: GRAYSCALE_LABEL_400,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '차단 해제',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: GRAYSCALE_LABEL_700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showUnblockDialog(
    BuildContext context,
    String userName,
    String userId,
    String currentUserId,
    BlockProvider blockProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WHITE,
        title: Text('차단 해제'),
        content: Text('${userName}님의 차단을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(color: GRAYSCALE_LABEL_700),
            ),
          ),
          TextButton(
            onPressed: () async {
              await blockProvider.unblockUser(
                currentUserId: currentUserId,
                targetUserId: userId,
              );
              if (!mounted) return;
              Navigator.pop(context);
              toastification.show(
                context: context,
                type: ToastificationType.success,
                alignment: Alignment.bottomCenter,
                autoCloseDuration: const Duration(seconds: 2),
                title: Text('${userName}님의 차단이 해제되었습니다'),
              );
            },
            child: const Text('해제', style: TextStyle(color: BUTTON)),
          ),
        ],
      ),
    );
  }
}
