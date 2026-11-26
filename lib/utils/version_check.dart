import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheck {
  static const String _defaultIosStoreUrl =
      'https://apps.apple.com/us/app/%EB%8D%94%EB%B2%A0%EC%9D%B4%EC%8A%A4-%EC%95%BC%EA%B5%AC-%ED%8C%AC%EB%93%A4%EC%9D%98-%EC%9D%BC%EC%83%81%EC%9D%B4-%EB%AA%A8%EC%9D%B4%EB%8A%94-%EA%B3%B3/id6752247698';
  static const String _defaultAndroidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.codegrove.thebase';
  static const String _defaultTitle = '새로운 버전 업데이트';
  static const String _defaultMessage =
      '더 안정적이고 새로워진 ILU를 이용하기 위해 최신 버전으로 업데이트가 필요합니다.';
  static const String _defaultButtonText = '업데이트 하러 가기';
  static const String _defaultLaterText = '나중에';

  static Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. 현재 앱의 버전 가져오기
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Firestore에서 최신/필수 버전 및 안내 문구 가져오기
      final doc = await FirebaseFirestore.instance
          .collection('version')
          .doc('settings')
          .get();
      if (!doc.exists || !context.mounted) return;

      final data = doc.data() ?? <String, dynamic>{};
      final String minVersion =
          (data['min_version'] as String?)?.trim().isNotEmpty == true
          ? (data['min_version'] as String).trim()
          : '1.0.0';
      final bool isForce = data['is_force'] is bool
          ? data['is_force'] as bool
          : true;

      final String title = _readText(data['title'], _defaultTitle);
      final String message = _readText(data['message'], _defaultMessage);
      final String buttonText = _readText(
        data['button_text'],
        _defaultButtonText,
      );
      final String laterButtonText = _readText(
        data['later_button_text'],
        _defaultLaterText,
      );

      final String iosStoreUrl = _readText(
        data['ios_store_url'],
        _defaultIosStoreUrl,
      );
      final String androidStoreUrl = _readText(
        data['android_store_url'],
        _defaultAndroidStoreUrl,
      );
      final String storeUrl = Platform.isIOS ? iosStoreUrl : androidStoreUrl;

      // 3. 버전 비교
      if (_isUpdateRequired(currentVersion, minVersion)) {
        _showUpdateDialog(
          context,
          storeUrl: storeUrl,
          isForce: isForce,
          title: title,
          message: message,
          buttonText: buttonText,
          laterButtonText: laterButtonText,
        );
      }
    } catch (e) {
      debugPrint('VersionCheck error: $e');
    }
  }

  static String _readText(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.replaceAll(r'\n', '\n');
    }
    return fallback;
  }

  // 버전 문자열 비교 로직
  static bool _isUpdateRequired(String current, String min) {
    List<int> parseParts(String version) => version
        .split('+')
        .first
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();

    final List<int> currentParts = parseParts(current);
    final List<int> minParts = parseParts(min);

    for (int i = 0; i < minParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String storeUrl,
    required bool isForce,
    required String title,
    required String message,
    required String buttonText,
    required String laterButtonText,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForce, // 강제 업데이트시 바깥 클릭으로 못 닫게
      builder: (context) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          backgroundColor: WHITE,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(laterButtonText),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                final uri = Uri.tryParse(storeUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                buttonText,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
