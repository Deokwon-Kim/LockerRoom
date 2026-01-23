import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_core/flutter_chat_core.dart' show User;
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 특정 모임의 메시지 스트림 가져오기
  Stream<List<types.Message>> getMessagesStream(String meetupId) {
    return _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            if (data['type'] == 'image') {
              return types.ImageMessage(
                author: types.User(id: data['authorId']),
                createdAt:
                    (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    DateTime.now().millisecondsSinceEpoch,
                updatedAt:
                    (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
                id: doc.id,
                name: data['name'] ?? '',
                size: data['size'] ?? 0,
                uri: data['uri'] ?? '',
                metadata: data['metadata'] as Map<String, dynamic>?,
              );
            }
            return types.TextMessage(
              author: types.User(id: data['authorId']),
              createdAt:
                  (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                  DateTime.now().millisecondsSinceEpoch,
              updatedAt:
                  (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
              id: doc.id,
              text: data['text'] ?? '',
              metadata: data['metadata'] as Map<String, dynamic>?,
            );
          }).toList();
        });
  }

  // 유저 정보 가져오기 (flutter_chat_ui 2.x 필수)
  Future<User> resolveUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return User(
          id: userId,
          name: data['userNickName'] ?? '익명',
          imageSource: data['profileImage'],
        );
      }
    } catch (e) {
      debugPrint('Error resolving user: $e');
    }
    return User(id: userId, name: '익명');
  }

  // 메시지 전송 (텍스트)
  Future<void> sendMessage(String meetupId, types.TextMessage message) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .add({
          'authorId': message.author.id,
          'createdAt': FieldValue.serverTimestamp(),
          'text': message.text,
          'type': 'text',
          'metadata': message.metadata,
        });
  }

  // 이미지 업로드 및 메시지 전송 (최대 4장)
  Future<void> sendImageMessages(
    String meetupId,
    String userId,
    List<File> images,
  ) async {
    for (var file in images.take(4)) {
      final fileName = const Uuid().v4();
      final ref = _storage.ref().child('chat_images/$meetupId/$fileName');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore
          .collection('meetups')
          .doc(meetupId)
          .collection('messages')
          .add({
            'authorId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'uri': url, // url -> uri 통일
            'name': fileName,
            'size': await file.length(),
            'type': 'image',
          });
    }
  }

  Future<void> sendSystemMessage(String meetupId, String text) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .add({
          'authorId': 'system',
          'createdAt': FieldValue.serverTimestamp(),
          'text': text,
          'type': 'text',
          'metadata': {'isSystem': true},
        });
  }

  // 유저가 모임 채팅방에 처음 입장했는 여부 확인 후 입장 메시지 전송
  Future<void> sendEntryMessageOnce(
    String meetupId,
    String userId,
    String nickname,
  ) async {
    final participantRef = _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('participants')
        .doc(userId);

    final doc = await participantRef.get();

    if (!doc.exists) {
      // 처음 입장하는 경우에만 데이터 생성 및 시스템 메시지 발송
      await participantRef.set({'joinAt': FieldValue.serverTimestamp()});
      await sendSystemMessage(meetupId, '$nickname님이 입장했습니다');
    }
  }

  // 메시지 수정
  Future<void> updateMessage(
    String meetupId,
    String messageId,
    String newText,
  ) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': newText,
          'updatedAt': FieldValue.serverTimestamp(), // 수정 시간 기록
        });
  }

  // 메시지 삭제
  Future<void> deleteMessage(String meetupId, String messageId) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
