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
        title: Text('새 게시물', style: TextStyle(color: WHITE)),
        backgroundColor: teamProvider.selectedTeam?.color,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsGeometry.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: postProvider.pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: GRAYSCALE_LABEL_300,
                  child: postProvider.imageFile != null
                      ? Image.file(postProvider.imageFile!, fit: BoxFit.cover)
                      : Center(child: Text('이미지 선택')),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: postProvider.captionController,
                decoration: InputDecoration(hintText: '내용입력...'),
              ),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  postProvider.upload();
                  context.read<BottomTabBarProvider>().setIndex(0);

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => BottomTabBar()),
                    (route) => false,
                  );
                },
                child: Text('업로드'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
