import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/post_model.dart';
import 'package:lockerroom/utils/media_utils.dart';

class EditableMediaItem {
  final String? remoteUrl;
  final File? localFile;
  final bool isVideo;

  const EditableMediaItem({
    this.remoteUrl,
    this.localFile,
    required this.isVideo,
  });

  bool get isRemote => remoteUrl != null;
}

class FeedEditProvider extends ChangeNotifier {
  static const int maxMediaCount = 5;

  final _postCollection = FirebaseFirestore.instance.collection('posts');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<EditableMediaItem> _items = [];
  List<EditableMediaItem> get items => _items;

  List<String> get editableMediaUrls =>
      _items.where((e) => e.isRemote).map((e) => e.remoteUrl!).toList();

  final List<String> _deletedMediaUrls = [];

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void initializeEdit(PostModel post) {
    _items = post.mediaUrls
        .map(
          (url) => EditableMediaItem(
            remoteUrl: url,
            isVideo: MediaUtils.isVideoUrl(url),
          ),
        )
        .toList();
    _deletedMediaUrls.clear();
    _isUploading = false;
    notifyListeners();
  }

  void addImages(List<File> files) {
    for (final file in files) {
      if (_items.length >= maxMediaCount) break;
      _items.add(EditableMediaItem(localFile: file, isVideo: false));
    }
    notifyListeners();
  }

  void addVideo(File file) {
    if (_items.length >= maxMediaCount) return;
    _items.add(EditableMediaItem(localFile: file, isVideo: true));
    notifyListeners();
  }

  void moveMedia(int from, int to) {
    if (from < 0 || from >= _items.length || to < 0 || to >= _items.length) {
      return;
    }
    final item = _items.removeAt(from);
    _items.insert(to, item);
    notifyListeners();
  }

  void removeMedia(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    if (removed.remoteUrl != null) {
      _deletedMediaUrls.add(removed.remoteUrl!);
    }
    notifyListeners();
  }

  Future<void> _cleanupDeletedMedia() async {
    for (final url in _deletedMediaUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (e) {
        debugPrint('Storage 삭제 실패: $e');
      }
    }
    _deletedMediaUrls.clear();
  }

  Future<String> _uploadLocalItem(
    String userId,
    EditableMediaItem item,
  ) async {
    final file = item.localFile!;
    final ext = item.isVideo ? 'mp4' : 'jpg';
    final path =
        'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref().child(path.endsWith('.$ext') ? path : '$path.$ext');
    final metadata = SettableMetadata(
      contentType: item.isVideo ? 'video/mp4' : 'image/jpeg',
    );
    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  /// 게시물 업데이트 (text + hashtags + 추가/삭제/재정렬된 mediaUrls). 성공 시 최종 mediaUrls 반환.
  Future<List<String>?> updatePost({
    required String postId,
    required String userId,
    required String newText,
    required List<String> hashtags,
  }) async {
    try {
      final finalUrls = <String>[];
      for (final item in _items) {
        if (item.isRemote) {
          finalUrls.add(item.remoteUrl!);
        } else if (item.localFile != null) {
          final uploaded = await _uploadLocalItem(userId, item);
          finalUrls.add(uploaded);
        }
      }

      await _postCollection.doc(postId).update({
        'text': newText,
        'hashtags': hashtags,
        'mediaUrls': finalUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _cleanupDeletedMedia();
      return finalUrls;
    } catch (e) {
      debugPrint('게시물 업데이트 실패: $e');
      return null;
    }
  }

  void reset() {
    _items.clear();
    _deletedMediaUrls.clear();
    _isUploading = false;
    notifyListeners();
  }
}
