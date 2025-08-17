import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/login/login_page.dart';
import 'package:lockerroom/provider/profile_provider.dart';
import 'package:lockerroom/provider/user_provider2.dart';
import 'package:provider/provider.dart';

class Mypage extends StatelessWidget {
  const Mypage({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    final email =
        userProvider.email ?? userProvider.currentUser?.email ?? '이메일';
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
            profileProvider.profileImageUrl != null
                ? CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      profileProvider.profileImageUrl!,
                    ),
                  )
                : CircleAvatar(
                    radius: 50,
                    backgroundColor: GRAYSCALE_LABEL_300,
                    child: Icon(Icons.person, size: 50, color: BLACK),
                  ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              email,
              style: TextStyle(
                color: GRAYSCALE_LABEL_500,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );

                  if (picked != null) {
                    await profileProvider.uploadProfileImage(picked);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 15.0,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: GRAYSCALE_LABEL_300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '프로필 편집',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                userProvider.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              },

              child: Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
