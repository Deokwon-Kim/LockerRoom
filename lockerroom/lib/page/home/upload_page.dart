import 'package:flutter/material.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/bottom_tab_bar_provider.dart';
import 'package:lockerroom/provider/post_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final teamProvider = Provider.of<TeamProvider>(context);

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: Colors.grey[600],
                        size: 30,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // 텍스트 필드 영역
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'deok_1',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 10,
                            maxHeight: 100,
                          ),
                          child: TextField(
                            cursorColor: teamProvider.selectedTeam?.color,
                            controller: postProvider.captionController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: '새로운 소식이 있나요?',
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[500],
                              ),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (postProvider.imageFile != null)
                Padding(
                  padding: const EdgeInsets.only(left: 60.0, right: 60.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 300,

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        postProvider.imageFile!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 0),
              // 이미지 선택 버튼
              GestureDetector(
                onTap: postProvider.pickImage,
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
                        '이미지 추가',
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
              SizedBox(height: 20),
              // 업로드 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    postProvider.upload();
                    context.read<BottomTabBarProvider>().setIndex(0);

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => BottomTabBar()),
                      (route) => false,
                    );
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
