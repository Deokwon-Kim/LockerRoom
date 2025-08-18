import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/alert/diallog.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class Mypage extends StatefulWidget {
  const Mypage({super.key});

  @override
  State<Mypage> createState() => _MypageState();
}

class _MypageState extends State<Mypage> {
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 프로필 이미지 로드
      Future.microtask(
        () => Provider.of<ProfileProvider>(
          context,
          listen: false,
        ).loadProfileImage(user.uid),
      );
    }
  }

  void _showProfileImageOptions(
    BuildContext context,
    ProfileProvider profileProvider,
    User? user,
  ) {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: GRAYSCALE_LABEL_50,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // Consumer를 사용하여 실시간으로 profileProvider 상태를 반영
        return Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '프로필 사진 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: ORANGE_PRIMARY_500,
                    ),
                    title: Text('사진 선택'),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await provider.pickImage();
                        if (user != null && provider.image != null) {
                          await provider.uploadImage(user.uid);
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            alignment: Alignment.bottomCenter,
                            autoCloseDuration: const Duration(seconds: 2),
                            title: Text('프로필 사진을 업로드했습니다'),
                          );
                        }
                      } catch (e) {
                        toastification.show(
                          context: context,
                          type: ToastificationType.error,
                          alignment: Alignment.bottomCenter,
                          autoCloseDuration: const Duration(seconds: 2),
                          title: Text('업로드 실패: $e'),
                        );
                      }
                    },
                  ),
                  // 실시간으로 imageUrl 상태를 확인
                  if (provider.imageUrl != null &&
                      provider.imageUrl!.isNotEmpty)
                    ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('사진 삭제'),
                      onTap: () async {
                        Navigator.pop(context);
                        // 삭제 확인 대화상자
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return ConfirmationDialog(
                              title: '프로필 사진 삭제',
                              content: '프로필 사진을 삭제하시겠습니까?',
                              cancelText: '취소',
                              confirmText: '삭제',
                              confirmColor: Colors.red,
                              onConfirm: () async {
                                try {
                                  await provider.deleteProfileImage(user!.uid);
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.success,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: const Duration(
                                      seconds: 2,
                                    ),
                                    title: Text('프로필 사진을 삭제했습니다'),
                                  );
                                } catch (e) {
                                  toastification.show(
                                    context: context,
                                    type: ToastificationType.error,
                                    alignment: Alignment.bottomCenter,
                                    autoCloseDuration: const Duration(
                                      seconds: 2,
                                    ),
                                    title: Text('삭제 실패: $e'),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ListTile(
                    leading: Icon(Icons.cancel, color: GRAYSCALE_LABEL_500),
                    title: Text('취소'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final email =
        userProvider.email ?? userProvider.currentUser?.email ?? '이메일';
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: Text(
          '프로필',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: BACKGROUND_COLOR,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 20.0,
                    left: 20.0,
                    right: 20.0,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: GRAYSCALE_LABEL_300,
                        radius: 50,
                        backgroundImage: profileProvider.image != null
                            ? FileImage(profileProvider.image!)
                            : (profileProvider.imageUrl != null
                                  ? NetworkImage(profileProvider.imageUrl!)
                                  : null),
                        child:
                            (profileProvider.image == null &&
                                profileProvider.imageUrl == null)
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: GRAYSCALE_LABEL_500,
                              )
                            : null,
                      ),
                      // 업로드 중일 때 진행률 표시
                      if (profileProvider.isUploading)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: profileProvider.uploadProgress,
                                color: ORANGE_PRIMARY_500,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${(profileProvider.uploadProgress * 100).toInt()}%',
                                style: TextStyle(
                                  color: ORANGE_PRIMARY_500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 60,
                  right: 0,
                  child: GestureDetector(
                    onTap: profileProvider.isUploading
                        ? null // 업로드 중일 때 비활성화
                        : () async {
                            _showProfileImageOptions(
                              context,
                              profileProvider,
                              user,
                            );
                          },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: profileProvider.isUploading
                            ? Colors.grey[400] // 업로드 중일 때 회색
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 20,
                        color: profileProvider.isUploading
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              userName,
              style: TextStyle(
                color: BLACK,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5),
            Text(
              email,
              style: TextStyle(
                color: GRAYSCALE_LABEL_500,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 400,
              child: ContainedTabBarView(
                tabs: [
                  Text('게시글', style: TextStyle(color: BLACK)),
                  Text('댓글', style: TextStyle(color: BLACK)),
                ],
                tabBarProperties: TabBarProperties(
                  indicatorColor: BUTTON,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3.0,
                  unselectedLabelColor: GRAYSCALE_LABEL_500,
                ),
                views: [
                  Container(color: Colors.blue),
                  Container(color: Colors.deepOrange),
                ],

                onChange: (index) => print(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
