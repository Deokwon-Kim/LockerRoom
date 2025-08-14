import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  bool _didRefreshTokenOnce = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후 1회만 토큰 갱신 시도
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      if (userProvider.currentUser != null && !_didRefreshTokenOnce) {
        _didRefreshTokenOnce = true;
        await userProvider.refreshAuthToken();
        if (kDebugMode) {
          debugPrint('FeedPage: token refreshed once');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text('피드', style: TextStyle(color: WHITE, fontSize: 15)),
        backgroundColor: teamProvider.selectedTeam?.color,
      ),
      backgroundColor: BACKGROUND_COLOR,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  teamProvider.selectedTeam?.color ?? Colors.blue,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('게시물 없음', style: TextStyle(color: Colors.grey)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: EdgeInsets.all(10),
            itemCount: docs.length,
            separatorBuilder: (context, index) => SizedBox(height: 20),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildPostItem(data, context: context);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, {BuildContext? context}) {
    // 시간 변환: Firestore Timestamp을 DateTime으로
    DateTime? createdAt;
    if (post['createdAt'] != null) {
      if (post['createdAt'] is Timestamp) {
        createdAt = (post['createdAt'] as Timestamp).toDate();
      } else if (post['createdAt'] is DateTime) {
        createdAt = post['createdAt'];
      }
    }

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post['authorProfileImageUrl'] != null
                      ? NetworkImage(post['authorProfileImageUrl'])
                      : null,
                  child: post['authorProfileImageUrl'] == null
                      ? Icon(Icons.person)
                      : null,
                  onBackgroundImageError: post['authorProfileImageUrl'] != null
                      ? (exception, stackTrace) {
                          print('Profile image load error: $exception');

                          // 403 에러 특별 처리
                          if (exception.toString().contains('403') ||
                              exception.toString().contains('Forbidden')) {
                            print(
                              '403 Forbidden error for profile image: ${post['authorProfileImageUrl']}',
                            );
                          }
                          // 프로필 이미지 로드 실패 시 디폴트 아이콘을 표시
                        }
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['authorName'] ?? '알 수 없는 사용자',
                        style: TextStyle(
                          color: BLACK,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        createdAt != null ? _formatTime(createdAt) : '시간 정보 없음',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.more_horiz_outlined),
                ),
              ],
            ),
            SizedBox(height: 12),

            // 게시물 내용
            Text(
              post['caption'] ?? '',
              style: TextStyle(color: Colors.black, fontSize: 14),
            ),
            SizedBox(height: 12),

            // 이미지들 - 에러 처리 추가
            if (post['imageUrls'] != null &&
                (post['imageUrls'] as List).isNotEmpty)
              _buildImages(post['imageUrls'] as List<dynamic>, context!)
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 40,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '이미지를 불러올 수 없습니다',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 8),

            // 이미지 개수 표시
            if (post['imageUrls'] != null &&
                (post['imageUrls'] as List).length > 1)
              Text(
                '${(post['imageUrls'] as List).length}장의 사진',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImages(List<dynamic> imageUrls, BuildContext context) {
    try {
      if (imageUrls.length == 1) {
        // 단일 이미지
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrls.first as String,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              if (kDebugMode) {
                debugPrint('Image load error: $error');
              }

              // 403 에러 특별 처리
              String errorMessage = '이미지 로드 오류';
              if (error.toString().contains('403') ||
                  error.toString().contains('Forbidden')) {
                errorMessage = '이미지 접근 권한 없음 (로그인 확인 필요)';
                if (kDebugMode) {
                  debugPrint(
                    '403 Forbidden error detected for image: ${imageUrls.first}',
                  );
                  debugPrint(
                    'User auth state: ${userProvider.currentUser != null}',
                  );
                }
              }

              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // 여러 이미지 - 가로 스크롤
        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            itemBuilder: (context, imageIndex) {
              return Container(
                margin: EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrls[imageIndex] as String,
                    height: 200,
                    width: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        width: 150,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      if (kDebugMode) {
                        debugPrint(
                          'Image load error at index $imageIndex: $error',
                        );
                      }
                      return Container(
                        height: 200,
                        width: 150,
                        color: Colors.grey[300],
                        child: Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error building images: $e');
      }
      return Container(
        height: 100,
        width: double.infinity,
        color: Colors.red[100],
        child: Center(
          child: Text('이미지 표시 오류: $e', style: TextStyle(color: Colors.red)),
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM월 dd일').format(dateTime);
    }
  }
}
