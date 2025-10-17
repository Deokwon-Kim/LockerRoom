import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/notice/notice_page.dart';
import 'package:toastification/toastification.dart';

class NoticeListPage extends StatefulWidget {
  const NoticeListPage({super.key});

  @override
  State<NoticeListPage> createState() => _NoticeListPageState();
}

class _NoticeListPageState extends State<NoticeListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDateTime(DateTime datetime) {
    return DateFormat('yyyy-MM-dd').format(datetime);
  }

  // 관리자 여부 확인 메서드
  bool _isAdmin() {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 관리자 이메일 목록
    final adminEmails = ['kdw0032@gmail.com'];

    return adminEmails.contains(user.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WHITE,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: WHITE,
        title: const Text(
          '공지사항',
          style: TextStyle(
            color: GRAYSCALE_LABEL_950,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        foregroundColor: GRAYSCALE_LABEL_950,

        actions: [
          if (_isAdmin())
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NoticePage()),
                );

                if (result != null) {
                  // 공지사항 작성으로 이동 > 작성완료 후 돌아오면 Firestroe에 데이터 저장
                  await _firestore.collection('notices').add({
                    'title': result['title'],
                    'content': result['content'],
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '오류가 발생했습니다.',
                style: TextStyle(color: RED_DANGER_TEXT_50, fontSize: 16),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: ORANGE_PRIMARY_500),
            );
          }

          // 데이터가 없거나 빈 경우
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                '작성된 공지사항이 없습니다.',
                style: TextStyle(color: GRAYSCALE_LABEL_600, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) =>
                Divider(color: GRAYSCALE_LABEL_200, height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['createdAt'] as Timestamp?;

              return InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticePage(
                        initialTitle: data['title'],
                        initialContent: data['content'],
                        noticeId: doc.id,
                        isAdmin: _isAdmin(),
                      ),
                    ),
                  );

                  if (result != null) {
                    if (result['delete'] == true) {
                      // 삭제 처리
                      try {
                        await _firestore
                            .collection('notices')
                            .doc(doc.id)
                            .delete();
                        if (mounted) {
                          toastification.show(
                            context: context,
                            style: ToastificationStyle.flat,
                            type: ToastificationType.success,
                            autoCloseDuration: Duration(seconds: 3),
                            alignment: Alignment.bottomCenter,
                            title: Text('공지사항이 삭제되었습니다.'),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          toastification.show(
                            context: context,
                            style: ToastificationStyle.flat,
                            type: ToastificationType.error,
                            autoCloseDuration: Duration(seconds: 3),
                            alignment: Alignment.bottomCenter,
                            title: Text('공지사항 삭제에 실패했습니다.'),
                          );
                        }
                      }
                    } else {
                      // 수정 처리
                      try {
                        await _firestore
                            .collection('notices')
                            .doc(doc.id)
                            .update({
                              'title': result['title'],
                              'content': result['content'],
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                        if (mounted) {
                          toastification.show(
                            context: context,
                            style: ToastificationStyle.flat,
                            type: ToastificationType.success,
                            autoCloseDuration: Duration(seconds: 3),
                            alignment: Alignment.bottomCenter,
                            title: Text('공지사항이 수정되었습니다.'),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          toastification.show(
                            context: context,
                            style: ToastificationStyle.flat,
                            type: ToastificationType.error,
                            autoCloseDuration: Duration(seconds: 3),
                            alignment: Alignment.bottomCenter,
                            title: Text('공지사항 수정에 실패했습니다.'),
                          );
                        }
                      }
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '제목 없음',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: GRAYSCALE_LABEL_950,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        timestamp != null
                            ? _formatDateTime(timestamp.toDate())
                            : '날짜 없음',
                        style: TextStyle(
                          fontSize: 12,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
