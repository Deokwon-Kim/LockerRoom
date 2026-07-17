import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheck {
  static Future<void> checkVersion(BuildContext context) async {
    // 1. 현재 앱의 버전 가져오기
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    // 2. Firestore에서 최신/필수 버전 정보 가져오기
    var doc = await FirebaseFirestore.instance
        .collection('version')
        .doc('settings')
        .get();
    if (!doc.exists) return;

    String minVersion = doc.data()?['min_version'] ?? "1.0.0";
    String storeUrl = Platform.isIOS
        ? "https://apps.apple.com/us/app/%EB%8D%94%EB%B2%A0%EC%9D%B4%EC%8A%A4-%EC%95%BC%EA%B5%AC-%ED%8C%AC%EB%93%A4%EC%9D%98-%EC%9D%BC%EC%83%81%EC%9D%B4-%EB%AA%A8%EC%9D%B4%EB%8A%94-%EA%B3%B3/id6752247698"
        : "https://play.google.com/store/apps/details?id=com.codegrove.thebase";

    // 3. 버전 비교
    if (_isUpdateRequired(currentVersion, minVersion)) {
      _showUpdateDialog(context, storeUrl, true);
    }
  }

  // 버전 문자열 비교 로직
  static bool _isUpdateRequired(String current, String min) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> minParts = min.split('.').map(int.parse).toList();

    for (int i = 0; i < minParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String storeUrl,
    bool isForce,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isForce, // 강제 업데이트시 바깥 클릭으로 못 닫게
      builder: (context) => WillPopScope(
        child: AlertDialog(
          backgroundColor: WHITE,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '새로운 버전 업데이트',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('더 안정적이고 새로워진 더베이스를 이용하기 위해 최신 버전으로 업데이트가 필요합니다.'),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('나중에'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => launchUrl(Uri.parse(storeUrl)),
              child: const Text(
                '업데이트 하러 가기',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        onWillPop: () async => !isForce,
      ),
    );
  }
}
