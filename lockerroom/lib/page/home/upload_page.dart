import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final captionController = TextEditingController();
    final userProvider = context.read<UserProvider>();
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final teamProvider = context.read<TeamProvider>();
    final profileProvider = context.read<ProfileProvider>();

    // 현재 사용자의 프로필 이미지 로드
    if (userProvider.currentUser != null && profileProvider.imageUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profileProvider.loadProfileImage;
      });
    }

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: Text(
          '새로운 게시물',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: BACKGROUND_COLOR,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                // 프로필 사진
                profileProvider.isLoading
                    ? CircularProgressIndicator(color: BUTTON, strokeWidth: 2)
                    : CircleAvatar(
                        radius: 25,
                        backgroundImage: profileProvider.imageUrl != null
                            ? NetworkImage(profileProvider.imageUrl!)
                            : null,
                        backgroundColor: GRAYSCALE_LABEL_300,
                        child: profileProvider.imageUrl == null
                            ? Icon(Icons.person, color: BLACK, size: 25)
                            : null,
                      ),
                SizedBox(width: 10),
                Text(
                  userName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 50.0),
              child: TextField(
                cursorColor: teamProvider.selectedTeam?.color,
                controller: captionController,
                maxLines: null,
                minLines: 1,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '새로운 소식이 있나요?',
                  hintStyle: TextStyle(fontSize: 15, color: Colors.grey[500]),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(height: 12),
            uploadProvider.mediaFiles.isNotEmpty
                ? Container(
                    margin: EdgeInsets.only(left: 70.0, top: 10, bottom: 10),
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: uploadProvider.mediaFiles.length,
                      itemBuilder: (context, index) {
                        final file = uploadProvider.mediaFiles[index];
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(file.path),
                              width: 100,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : SizedBox.shrink(),
            IconButton(
              onPressed: uploadProvider.pickMultipleMedia,
              icon: Icon(Icons.add_photo_alternate_outlined),
            ),
            SizedBox(height: 12),

            SizedBox(height: 12),
            GestureDetector(
              onTap: uploadProvider.isUploading
                  ? null
                  : () {
                      uploadProvider.uploadPost(captionController.text);
                      captionController.clear();
                    },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BUTTON,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: uploadProvider.isUploading
                    ? CircularProgressIndicator(color: WHITE, strokeWidth: 2)
                    : Text(
                        '업로드',
                        style: TextStyle(
                          color: WHITE,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            // ElevatedButton(
            //   onPressed: uploadProvider.isUploading
            //       ? null
            //       : () {
            //           uploadProvider.uploadPost(captionController.text);
            //           captionController.clear();
            //         },
            //   child: uploadProvider.isUploading
            //       ? CircularProgressIndicator()
            //       : Text('업로드'),
            // ),
          ],
        ),
      ),
    );
  }
}
