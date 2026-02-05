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
            if (data['type'] == 'custom') {
              return types.CustomMessage(
                author: types.User(id: data['authorId']),
                createdAt:
                    (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    DateTime.now().millisecondsSinceEpoch,
                updatedAt:
                    (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch,
                id: doc.id,
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
    await _firestore.collection('meetups').doc(meetupId).update({
      'lastMessage': message.text,
      'lastMessageAt': DateTime.now().toIso8601String(),
    });
  }

  // 채팅방 입장 시 호출할 읽음처리 함수
  Future<void> markAsRead(String meetupId, String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('readStatus')
        .doc(meetupId)
        .set({'lastReadAt': FieldValue.serverTimestamp()});
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
    await _firestore.collection('meetups').doc(meetupId).update({
      'lastMessage': '사진을 보냈습니다.',
      'lastMessageAt': DateTime.now().toIso8601String(),
    });
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

  Future<void> updateMessageMetadata(
    String meetupId,
    String messageId,
    Map<String, dynamic> metadata,
  ) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId)
        .update({'metadata': metadata});
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
    // 1. 메시지 삭제
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId)
        .delete();

    // 2. 삭제된 후 가장 최근 메시지 다시 조회 (lastMessage 업데이트용)
    final snapshot = await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final lastMsgDoc = snapshot.docs.first;
      final lastMsgData = lastMsgDoc.data();
      String lastText = '';

      if (lastMsgData['type'] == 'image') {
        lastText = '사진을 보냈습니다.';
      } else if (lastMsgData['type'] == 'custom') {
        lastText = '투표가 올라왔습니다.';
      } else {
        lastText = lastMsgData['text'] ?? '';
      }

      final lastTime =
          (lastMsgData['createdAt'] as Timestamp?)
              ?.toDate()
              .toIso8601String() ??
          DateTime.now().toIso8601String();

      await _firestore.collection('meetups').doc(meetupId).update({
        'lastMessage': lastText,
        'lastMessageAt': lastTime,
      });
    } else {
      // 메시지가 하나도 없는 경우
      await _firestore.collection('meetups').doc(meetupId).update({
        'lastMessage': null,
        'lastMessageAt': null,
      });
    }
  }

  // 투표 메시지 전송
  Future<void> sendPollMessage(
    String meetupId,
    String userId,
    String question,
    List<String> options,
    DateTime deadLine,
    bool allowMultiple,
  ) async {
    final Map<String, List<String>> votes = {for (var opt in options) opt: []};

    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .add({
          'authorId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'custom',
          'metadata': {
            'pollType': 'single',
            'question': question,
            'options': options,
            'votes': votes,
            'deadLine': Timestamp.fromDate(deadLine),
            'isClosed': false,
            'allowMultiple': allowMultiple,
          },
        });
  }

  // 투표 참여
  Future<void> votePoll(
    String meetupId,
    String messageId,
    String userId,
    String pickedOption,
  ) async {
    final docRef = _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(
        data['metadata'] ?? {},
      );
      final Map<String, dynamic> votes = Map<String, dynamic>.from(
        metadata['votes'] ?? {},
      );

      final allowMultiple = metadata['allowMultiple'] ?? false;

      if (!allowMultiple) {
        votes.forEach((key, value) {
          final List<dynamic> userList = List.from(value);
          userList.remove(userId);
          votes[key] = userList;
        });

        // 선택한 항목에 UserId 추가
        final List<dynamic> newUserList = List.from(votes[pickedOption] ?? []);
        newUserList.add(userId);
        votes[pickedOption] = newUserList;
      } else {
        // 복수투표 로직
        final List<dynamic> currentVoters = List.from(
          votes[pickedOption] ?? [],
        );

        if (currentVoters.contains(userId)) {
          // 이미 투표했다면 취소
          currentVoters.remove(userId);
        } else {
          // 투표하지 않았다면 추가
          currentVoters.add(userId);
        }
        votes[pickedOption] = currentVoters;
      }

      metadata['votes'] = votes;
      transaction.update(docRef, {'metadata': metadata});
    });
  }

  // 투표 수정
  Future<void> updatePoll(
    String meetupId,
    String messageId, {
    required String question,
    required List<String> options,
    required DateTime deadLine,
    required bool allowMultiple,
  }) async {
    final docRef = _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(
        data['metadata'] ?? {},
      );
      final Map<String, dynamic> oldVotes = Map<String, dynamic>.from(
        metadata['votes'] ?? {},
      );

      // 새로운 투표 내역 맵 생성
      final Map<String, dynamic> newVotes = {};
      for (var option in options) {
        // 기존에 있던 선택지면 투표 내역 유지, 새로운 선택지면 빈 리스트
        newVotes[option] = oldVotes[option] ?? [];
      }

      metadata['question'] = question;
      metadata['options'] = options;
      metadata['votes'] = newVotes;
      metadata['deadLine'] = Timestamp.fromDate(deadLine);
      metadata['allowMultiple'] = allowMultiple;

      transaction.update(docRef, {'metadata': metadata});
    });
  }

  // 투표 종료/재개
  Future<void> togglePollClosed(
    String meetupId,
    String messageId,
    bool isClosed,
  ) async {
    await _firestore
        .collection('meetups')
        .doc(meetupId)
        .collection('messages')
        .doc(messageId)
        .update({'metadata.isClosed': isClosed});
  }
}
