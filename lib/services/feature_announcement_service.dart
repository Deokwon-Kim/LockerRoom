import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lockerroom/model/feature_announcement_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureAnnouncementService {
  static const String _collection = 'feature_announcements';
  static const String _dismissedKey = 'dismissed_feature_announcement_ids';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static String dismissKeyFor(
    FeatureAnnouncementModel announcement, {
    required bool isOutdated,
  }) {
    if (isOutdated && announcement.targetVersion.isNotEmpty) {
      return '${announcement.id}_update_v${announcement.targetVersion}';
    }
    return announcement.id;
  }

  /// 현재 활성화된 공지 중 사용자가 '다시 보지 않기' 하지 않은 최상위 1건 반환
  Future<FeatureAnnouncementModel?> fetchActiveAnnouncement({
    String? currentVersion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_dismissedKey) ?? const <String>[];
      final appVersion =
          currentVersion ?? (await PackageInfo.fromPlatform()).version;

      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final candidates = snapshot.docs
          .map(FeatureAnnouncementModel.fromFirestore)
          .where((a) {
            final isOutdated = a.needsAppUpdate(appVersion);
            final hasFeatureMedia = a.features.any(
              (f) => f.mediaItems.isNotEmpty,
            );
            // 구버전 유저는 사진이 없어도 업데이트 유도 노출, 최신버전 유저는 미디어가 있는 기능 공지만 노출
            if (!isOutdated && !hasFeatureMedia) return false;
            final key = dismissKeyFor(a, isOutdated: isOutdated);
            return !dismissed.contains(key);
          })
          .toList();

      if (candidates.isEmpty) return null;

      candidates.sort((a, b) {
        final pCmp = b.priority.compareTo(a.priority);
        if (pCmp != 0) return pCmp;
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return candidates.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> dismissAnnouncement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = List<String>.from(
      prefs.getStringList(_dismissedKey) ?? const <String>[],
    );
    if (!dismissed.contains(id)) {
      dismissed.add(id);
      await prefs.setStringList(_dismissedKey, dismissed);
    }
  }

  /// 관리자용 전체 목록 조회
  Future<List<FeatureAnnouncementModel>> fetchAllAnnouncements() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(FeatureAnnouncementModel.fromFirestore).toList();
  }

  /// 사진 또는 동영상 파일을 Firebase Storage에 업로드 후 다운로드 URL 반환
  Future<String> uploadMediaFile(
    File file,
    String folderId, {
    required bool isVideo,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage
        .ref()
        .child('feature_announcements')
        .child(folderId)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: isVideo ? 'video/mp4' : 'image/jpeg',
    );
    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  Future<void> createAnnouncement({
    required String docId,
    required String badge,
    required String title,
    required int priority,
    required bool isActive,
    String targetVersion = '',
    String updateMessage = '',
    required List<FeatureAnnouncementItem> features,
  }) async {
    await _firestore.collection(_collection).doc(docId).set({
      'badge': badge,
      'title': title,
      'priority': priority,
      'isActive': isActive,
      'targetVersion': targetVersion.trim(),
      'updateMessage': updateMessage.trim(),
      'features': features.map((f) => f.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAnnouncement({
    required String docId,
    required String badge,
    required String title,
    required int priority,
    required bool isActive,
    String targetVersion = '',
    String updateMessage = '',
    required List<FeatureAnnouncementItem> features,
  }) async {
    await _firestore.collection(_collection).doc(docId).update({
      'badge': badge,
      'title': title,
      'priority': priority,
      'isActive': isActive,
      'targetVersion': targetVersion.trim(),
      'updateMessage': updateMessage.trim(),
      'features': features.map((f) => f.toMap()).toList(),
    });
  }

  Future<void> toggleActive(String docId, bool isActive) async {
    await _firestore.collection(_collection).doc(docId).update({
      'isActive': isActive,
    });
  }

  Future<void> deleteAnnouncement(String docId) async {
    await _firestore.collection(_collection).doc(docId).delete();
  }
}
