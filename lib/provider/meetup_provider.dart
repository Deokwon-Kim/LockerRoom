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
  Future<bool> joinMeetup(String meetupId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final docRef = _firestore.collection('meetups').doc(meetupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('모임을 찾을 수 없습니다');

        final meetup = MeetupModel.fromFirestore(snapshot);
        if (meetup.isFull) throw Exception('모임이 마감되었습니다');
        if (meetup.participants.contains(userId)) throw Exception('이미 참여중입니다');

        final updatedParticipants = [...meetup.participants, userId];
        transaction.update(docRef, {'participants': updatedParticipants});
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
}
