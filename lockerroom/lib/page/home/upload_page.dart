import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/bottom_tab_bar_provider.dart';
import 'package:lockerroom/provider/post_provider.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final profileProvider = context.watch<ProfileProvider>();
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: Text(
          '새로운 게시물',
          style: TextStyle(
            color: WHITE,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: teamProvider.selectedTeam?.color,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 사용자 프로필 이미지
                  profileProvider.isLoading
                      ? const CircularProgressIndicator()
                      : CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              profileProvider.profileImageUrl != null
                              ? NetworkImage(profileProvider.profileImageUrl!)
                              : null,
                          child: profileProvider.profileImageUrl == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                  SizedBox(width: 12),
                  // 텍스트 필드 영역
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextField(
                          cursorColor: teamProvider.selectedTeam?.color,
                          controller: postProvider.captionController,
                          maxLines: null,
                          minLines: 1,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: '새로운 소식이 있나요?',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[500],
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 선택된 이미지들 표시
              Consumer<PostProvider>(
                builder: (context, postProvider, child) {
                  if (postProvider.imageFiles.isNotEmpty) {
                    return Container(
                      margin: EdgeInsets.only(left: 70.0, top: 10, bottom: 10),
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: postProvider.imageFiles.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    postProvider.imageFiles[index],
                                    width: 100,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: GestureDetector(
                                    onTap: () =>
                                        postProvider.removeImage(index),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  } else if (postProvider.imageFile != null) {
                    // 단일 이미지 표시 (기존 코드와 호환성 유지)
                    return Padding(
                      padding: const EdgeInsets.only(left: 70.0, right: 70.0),
                      child: SizedBox(
                        width: 100,
                        height: 150,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            postProvider.imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              SizedBox(height: 10),
              // 이미지 선택 버튼
              GestureDetector(
                onTap: postProvider.pickImages,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '이미지 추가 (한 장 또는 여러 장)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // 이미지 초기화 버튼 (이미지가 있을 때만 표시)
              Consumer<PostProvider>(
                builder: (context, postProvider, child) {
                  if (postProvider.imageFiles.isNotEmpty ||
                      postProvider.imageFile != null) {
                    return GestureDetector(
                      onTap: postProvider.clearImages,
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red[600],
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '모든 이미지 삭제',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              SizedBox(height: 20),
              // 업로드 상태 표시
              Consumer<PostProvider>(
                builder: (context, postProvider, child) {
                  if (postProvider.isUploading) {
                    return Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  teamProvider.selectedTeam?.color ??
                                      Colors.blue,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              postProvider.uploadStatus,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        await postProvider.uploadPost(context);

                        // 업로드 성공 시에만 피드로 이동
                        if (!postProvider.isUploading &&
                            postProvider.uploadStatus == '업로드 성공!') {
                          context.read<BottomTabBarProvider>().setIndex(
                            1,
                          ); // 피드 탭으로 이동
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BottomTabBar(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teamProvider.selectedTeam?.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '게시하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
