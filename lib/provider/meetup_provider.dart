import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/user_model.dart';

class MeetupProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MeetupModel> _meetups = [];
  bool _isLoading = false;
  String? _selectedStadium;
  String? _selectedTeam;
  DateTime? _selectedDate;

  List<MeetupModel> get meetups => _meetups;
  bool get isLoading => _isLoading;
  String? get selectedStadium => _selectedStadium;
  String? get selecteedTeam => _selectedTeam;
  DateTime? get selectedDate => _selectedDate;

  // 필터링된 모임 목록
  List<MeetupModel> get filteredMeetups {
    var filtered = _meetups;

    if (_selectedStadium != null) {
      filtered = filtered.where((m) => m.stadium == _selectedStadium).toList();
    }

    if (_selectedTeam != null) {
      filtered = filtered
          .where(
            (m) => m.homeTeam == _selectedTeam || m.awayTeam == _selectedTeam,
          )
          .toList();
    }

    if (_selectedDate != null) {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      filtered = filtered.where((m) => m.gameDate == dateStr).toList();
    }

    return filtered;
  }

  // 필터 설정
  void setStadiumFilter(String? stadium) {
    _selectedStadium = stadium;
    notifyListeners();
  }

  void setTeamFilter(String? team) {
    _selectedTeam = team;
    notifyListeners();
  }

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    notifyListeners();
  }

  void clearFileters() {
    _selectedStadium = null;
    _selectedTeam = null;
    _selectedDate = null;
    notifyListeners();
  }

  // 모임 목록 불러오기
  Future<void> fetchMeetups() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('meetups')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _meetups = snapshot.docs
          .map((doc) => MeetupModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('모임 불러오기 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 모임 생성
  Future<bool> createMeetup(MeetupModel meetup) async {
    try {
      await _firestore.collection('meetups').add(meetup.toFirestore());
      await fetchMeetups();
      return true;
    } catch (e) {
      print('모임 생성 실패: $e');
      return false;
    }
  }

  // 모임 참여
  Future<bool> joinMeetup(String meetupId, {int? birthYear}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);
        if (meetup.isFull) throw Exception('모임이 마감되었습니다');
        if (meetup.participants.contains(userId)) throw Exception('이미 참여중입니다');
        if (meetup.pendingParticipants.contains(userId)) {
          throw Exception('이미 승인 대기 중입니다');
        }

        // 생년월일 정보 업데이트 (있는 경우)
        if (birthYear != null) {
          transaction.update(userRef, {'birthYear': birthYear});
        }

        if (meetup.isApprovalRequired) {
          final updatedPending = [...meetup.pendingParticipants, userId];
          transaction.update(docRef, {'pendingParticipants': updatedPending});

          // 방장에게 알림 전송
          final notificationRef = _firestore.collection('notifications').doc();
          transaction.set(notificationRef, {
            'type': 'meetup_request',
            'meetupId': meetupId,
            'fromUserId': userId,
            'fromUserBirthYear': birthYear,
            'toUserId': meetup.userId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'preview':
                '${meetup.title} 모임에 참여 신청이 도착했습니다.${birthYear != null ? ' ($birthYear년생)' : ''}',
          });
        } else {
          final updatedParticipants = [...meetup.participants, userId];
          transaction.update(docRef, {'participants': updatedParticipants});
        }
      });

      await fetchMeetups();
      return true;
    } catch (e) {
      print('모임 참여 실패: $e');
      return false;
    }
  }

  // 모임 나가기
  Future<bool> leaveMeetup(String meetupId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);
        final updateParticipants = meetup.participants
            .where((id) => id != userId)
            .toList();
        transaction.update(docRef, {'participants': updateParticipants});
      });

      // 채팅방 입장 기록 삭제 (다음에 다시 들어오면 입장 메시지가 다시 뜸)
      await _firestore
          .collection('meetups')
          .doc(meetupId)
          .collection('participants')
          .doc(userId)
          .delete();

      await fetchMeetups();
      return true;
    } catch (e) {
      print('모임 나가기 실패: $e');
      return false;
    }
  }

  // 조회수 증가
  Future<void> incrementViewCount(String meetupId) async {
    try {
      await _firestore.collection('meetups').doc(meetupId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('조회수 증가 실패: $e');
    }
  }

  // 모임 삭제
  Future<bool> deleteMeetup(String meetupId) async {
    try {
      await _firestore.collection('meetups').doc(meetupId).delete();
      await fetchMeetups();
      return true;
    } catch (e) {
      print('모임 삭제 실패: $e');
      return false;
    }
  }

  // 모임 수정
  Future<bool> updateMeetup(String meetupId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('meetups').doc(meetupId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchMeetups();
      return true;
    } catch (e) {
      print('모임 수정 실패: $e');
      return false;
    }
  }

  // 참여자 정보 가져오기
  Future<List<UserModel>> getParticipantsInfo(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final futures = userIds.map(
        (uid) => _firestore.collection('users').doc(uid).get(),
      );
      final snapshots = await Future.wait(futures);

      return snapshots
          .where((doc) => doc.exists)
          .map((doc) => UserModel.fromDoc(doc))
          .toList();
    } catch (e) {
      print('참여자 정보 가져오기 실패: $e');
      return [];
    }
  }

  Future<bool> markAttendance(String meetupId, String participantId) async {
    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);
        // 이미 출석했는지 확인
        if (meetup.attendedParticipants.contains(participantId)) {
          throw Exception('이미 출석 처리되었습니다');
        }

        final updatedAttended = [...meetup.attendedParticipants, participantId];
        transaction.update(docRef, {'attendedParticipants': updatedAttended});
      });

      await fetchMeetups();
      return true;
    } catch (e) {
      print('출석 체크 실패: $e');
      return false;
    }
  }

  // 특정 모임 정보 가져오기
  Future<MeetupModel?> getMeetupById(String id) async {
    try {
      final doc = await _firestore.collection('meetups').doc(id).get();
      if (doc.exists) {
        return MeetupModel.fromFirestore(doc);
      }
    } catch (e) {
      print('모임 정보 단일 조회 실패: $e');
    }
    return null;
  }

  // 참여자 강제 퇴장 (방장전용)
  Future<bool> kickParticipant(String meetupId, String targetUserId) async {
    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);

        final updatedParticipants = meetup.participants
            .where((id) => id != targetUserId)
            .toList();

        transaction.update(docRef, {'participants': updatedParticipants});
      });

      // 강퇴당한 유저의 채팅방 입장 기록도 삭제 시도 (권한 부족 시 무시)
      try {
        await _firestore
            .collection('meetups')
            .doc(meetupId)
            .collection('participants')
            .doc(targetUserId)
            .delete();
      } catch (e) {
        debugPrint('참여자 하위 컬렉션 삭제 오류 (무시됨): $e');
      }

      await fetchMeetups();
      return true;
    } catch (e) {
      print('강제 퇴장 실패: $e');
      return false;
    }
  }

  // 참여 승인 (방장전용)
  Future<bool> approveParticipant(String meetupId, String targetUserId) async {
    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);
        if (meetup.isFull) throw Exception('모임이 마감되었습니다');

        final updatedPending = meetup.pendingParticipants
            .where((id) => id != targetUserId)
            .toList();
        final updatedParticipants = [...meetup.participants, targetUserId];

        transaction.update(docRef, {
          'pendingParticipants': updatedPending,
          'participants': updatedParticipants,
        });

        // 신청자에게 승인 알림 전송
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'type': 'meetup_approved',
          'meetupId': meetupId,
          'fromUserId': _auth.currentUser?.uid,
          'toUserId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'preview': '${meetup.title} 모임 참여가 승인되었습니다!',
        });
      });

      await fetchMeetups();
      return true;
    } catch (e) {
      print('참여 승인 실패: $e');
      return false;
    }
  }

  // 참여 거절 (방장전용)
  Future<bool> rejectParticipant(
    String meetupId,
    String targetUserId, {
    String? reason,
  }) async {
    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);

        final updatedPending = meetup.pendingParticipants
            .where((id) => id != targetUserId)
            .toList();

        transaction.update(docRef, {'pendingParticipants': updatedPending});

        // 신청자에게 거절 알림 전송
        final notificationRef = _firestore.collection('notifications').doc();
        String preview = '${meetup.title} 모임 참여가 거절되었습니다.';
        if (reason != null && reason.isNotEmpty) {
          preview += '\n사유: $reason';
        }

        transaction.set(notificationRef, {
          'type': 'meetup_rejected',
          'meetupId': meetupId,
          'fromUserId': _auth.currentUser?.uid,
          'toUserId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'preview': preview,
        });
      });

      await fetchMeetups();
      return true;
    } catch (e) {
      print('참여 거절 실패: $e');
      return false;
    }
  }

  // 모임 정보 실시간 스트림
  Stream<MeetupModel?> getMeetupStream(String id) {
    return _firestore
        .collection('meetups')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? MeetupModel.fromFirestore(doc) : null);
  }

  Stream<List<String>> getChatParticipantIdsStream(String meetupId) {
    return _firestore.collection('meetups').doc(meetupId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['participants'] ?? []);
    });
  }

  // 공지 등록
  Future<void> updateAnnouncement(
    String meetupId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('meetups').doc(meetupId).update({
      'announcement': data['text'],
      'announcementId': data['id'],
      'announcementAuthorId': data['authorId'],
      'announcementCreatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 공지 내리기
  Future<void> clearAnnouncement(String meetupId) async {
    await _firestore.collection('meetups').doc(meetupId).update({
      'announcement': FieldValue.delete(),
      'announcementId': FieldValue.delete(),
      'announcementAuthorId': FieldValue.delete(),
      'announcementCreatedAt': FieldValue.delete(),
    });
  }

  Stream<List<MeetupModel>> getJoinedMeetupStream(String userId) {
    return _firestore
        .collection('meetups')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MeetupModel.fromFirestore(doc))
              .toList(),
        );
  }

  // 알림 음소거 토글
  Future<void> toggleMeetupMute(String meetupId, bool isMuted) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'mutedMeetups.$meetupId': isMuted,
      });
    } catch (e) {
      print('알림 설정 변경 실패: $e');
    }
  }

  // 특정 모임의 음소거 상태 스트림
  Stream<bool> getMuteStatusStream(String meetupId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(false);

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final mutedMeetups = data['mutedMeetups'] as Map<String, dynamic>? ?? {};
      return mutedMeetups[meetupId] == true;
    });
  }
}
