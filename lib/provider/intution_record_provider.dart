import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';

class IntutionRecordProvider extends ChangeNotifier {
  final TextEditingController myScoreController = TextEditingController();
  final TextEditingController oppScoreContreller = TextEditingController();
  final TextEditingController memoController = TextEditingController();

  bool _isLoading = false;
  bool _saving = false;

  ScheduleModel? _todayGame;
  String? _myTeamSymple;
  String? _oppTeamSymple;
  String? _todayStr;

  bool get isLoding => _isLoading;
  bool get saving => _saving;
  ScheduleModel? get todayGame => _todayGame;
  String? get myTeamSymple => _myTeamSymple;
  String? get oppTeamSymple => _oppTeamSymple;
  String? get todayStr => _todayStr;

  @override
  void dispose() {
    myScoreController.dispose();
    oppScoreContreller.dispose();
    memoController.dispose();
    super.dispose();
  }

  String _yyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  String? _normalizeToCsvTeamName(BuildContext context, String saved) {
    final tp = context.read<TeamProvider>();
    final teams = tp.getTeam('team');
    for (final t in teams) {
      if (t.symplename == saved || t.name == saved) {
        return t.symplename;
      }
    }
    return null;
  }

  Future<void> init(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    // 컨트롤러 초기화 - 페이지 진입 시마다 빈 상태로 시작
    myScoreController.clear();
    oppScoreContreller.clear();
    memoController.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 응원팀 불러오기
    final teamProvider = context.read<TeamProvider>();
    if (teamProvider.team == null) {
      await teamProvider.loadTeam(user.uid);
    }
    final savedTeam = teamProvider.team;
    final symple = savedTeam == null
        ? null
        : _normalizeToCsvTeamName(context, savedTeam);
    final today = _yyyyMmDd(DateTime.now());
    ScheduleModel? match;

    if (symple != null) {
      final schedules = await ScheduleService().loadSchedules();
      final todays = schedules.where((s) => _yyyyMmDd(s.dateTimeKst) == today);

      final filtered = todays.where(
        (s) => s.homeTeam == symple || s.awayTeam == symple,
      );

      match = filtered.isNotEmpty ? filtered.first : null;
    }

    // 기존기록 있으면 불러오기 (모델 사용)
    if (match != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(match.gameId)
          .get();
      if (doc.exists) {
        final attendance = AttendanceModel.fromDoc(doc);
        myScoreController.text = attendance.myScore.toString();
        oppScoreContreller.text = attendance.opponentScore.toString();
        if (attendance.memo != null && attendance.memo!.isNotEmpty) {
          memoController.text = attendance.memo!;
        }
        // 이미지는 UI에서 별도로 처리 (필요시 추가)
      }
    }

    _todayStr = today;
    _myTeamSymple = symple;
    _todayGame = match;
    _oppTeamSymple = (match != null && symple != null)
        ? (match.homeTeam == symple ? match.awayTeam : match.homeTeam)
        : null;
    _isLoading = false;
    notifyListeners();
  }

  // 선택한 날짜로 경기 정보 갱신
  Future<void> loadByDate(BuildContext context, DateTime date) async {
    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 응원팀 캐시 확인, 없으면 로드
    final teamProvider = context.read<TeamProvider>();
    if (teamProvider.team == null) {
      await teamProvider.loadTeam(user.uid);
    }

    _myTeamSymple ??= (teamProvider.team == null
        ? null
        : _normalizeToCsvTeamName(context, teamProvider.team!));

    final String dateStr = _yyyyMmDd(date);
    ScheduleModel? match;

    if (_myTeamSymple != null) {
      final schedules = await ScheduleService().loadSchedules();
      final inDay = schedules.where((s) => _yyyyMmDd(s.dateTimeKst) == dateStr);
      final filtered = inDay.where(
        (s) => s.homeTeam == _myTeamSymple || s.awayTeam == _myTeamSymple,
      );
      match = filtered.isNotEmpty ? filtered.first : null;
    }

    // 점수 입력값 초기화 후 기존 기록 프리필 (모델 사용)
    myScoreController.clear();
    oppScoreContreller.clear();
    memoController.clear();
    if (match != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(match.gameId)
          .get();
      if (doc.exists) {
        final attendance = AttendanceModel.fromDoc(doc);
        myScoreController.text = attendance.myScore.toString();
        oppScoreContreller.text = attendance.opponentScore.toString();
        if (attendance.memo != null && attendance.memo!.isNotEmpty) {
          memoController.text = attendance.memo!;
        }
        // 이미지는 UI에서 별도로 처리 (필요시 추가)
      }
    }

    _todayStr = dateStr;
    _todayGame = match;
    if (_myTeamSymple != null) {
      _oppTeamSymple = (match != null)
          ? (match.homeTeam == _myTeamSymple ? match.awayTeam : match.homeTeam)
          : null;
    } else {
      _oppTeamSymple = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  String? validateScore(String? v) {
    if (v == null || v.trim().isEmpty) return '필수 입력';
    final n = int.tryParse(v);
    if (n == null || n < 0 || n > 99) return '0~99 사이 숫자';
    return null;
  }

  Future<bool> save(BuildContext context) async {
    if (_todayGame == null || _myTeamSymple == null || _todayStr == null)
      return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    if (validateScore(myScoreController.text) != null ||
        validateScore(oppScoreContreller.text) != null) {
      return false;
    }

    final myScore = int.parse(myScoreController.text);
    final oppScore = int.parse(oppScoreContreller.text);
    final g = _todayGame!;

    _saving = true;
    notifyListeners();

    try {
      // 이미지 업로드
      String? imageUrl;
      if (_selectedImage != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';
          final ref = FirebaseStorage.instance.ref().child(
            'intution_records/${user.uid}/$fileName',
          );

          await ref.putFile(_selectedImage!);
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          print('직관 이미지 업로드 실패: $e');
        }
      }

      // 모델 생성 및 저장
      final attendance = AttendanceModel(
        gameId: g.gameId,
        season: g.season,
        date: _yyyyMmDd(g.dateTimeKst),
        time:
            '${g.dateTimeKst.hour.toString().padLeft(2, '0')}:${g.dateTimeKst.minute.toString().padLeft(2, '0')}',
        stadium: g.stadium,
        homeTeam: g.homeTeam,
        awayTeam: g.awayTeam,
        myTeam: _myTeamSymple!,
        oppTeam: _oppTeamSymple,
        myScore: myScore,
        opponentScore: oppScore,
        imageUrl: imageUrl,
        memo: memoController.text.trim().isNotEmpty
            ? memoController.text.trim()
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(g.gameId)
          .set(attendance.toMap(), SetOptions(merge: true));

      // 저장 완료 후 UploadProvider 초기화

      // 입력 필드 초기화
      myScoreController.clear();
      oppScoreContreller.clear();
      memoController.clear();
      _selectedImage = null;
      notifyListeners();

      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  File? _selectedImage;
  bool _shouldDeleteImage = false;
  final ImagePicker _picker = ImagePicker();

  File? get selectedImage => _selectedImage;
  bool get shouldDeleteImage => _shouldDeleteImage;

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      _shouldDeleteImage = false;
      notifyListeners();
    }
  }

  void removeImage() {
    _selectedImage = null;
    _shouldDeleteImage = true;
    notifyListeners();
  }

  void resetState() {
    _isLoading = false;
    _saving = false;
    _selectedImage = null;
    _shouldDeleteImage = false;
    notifyListeners();
  }

  // 직관기록 수정 업데이트
  Future<bool> updateRecord({
    required String gameId,
    required int newMyscore,
    required int newOppScore,
    String? newMemo,
    File? newImage,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 이미지 업로드
      String? imageUrl;
      if (newImage != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${newImage.path.split('/').last}';
          final ref = FirebaseStorage.instance.ref().child(
            'intution_records/${user.uid}/$fileName',
          );

          await ref.putFile(newImage);
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          print('직관 이미지 업로드 실패: $e');
        }
      }

      // 업데이트할 데이터 준비
      final updateData = <String, dynamic>{
        'myScore': newMyscore,
        'opponentScore': newOppScore,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newMemo != null) {
        updateData['memo'] = newMemo.trim().isNotEmpty ? newMemo.trim() : null;
      }

      if (_shouldDeleteImage) {
        updateData['imageUrl'] = imageUrl;
      }
      // 새 이미지가 있으면 업로드
      else if (newImage != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${newImage.path.split('/').last}';
          final ref = FirebaseStorage.instance.ref().child(
            'intution_records/${user.uid}/$fileName',
          );

          await ref.putFile(newImage);
          final imageUrl = await ref.getDownloadURL();
          updateData['imageUrl'] = imageUrl;
        } catch (e) {
          print('직관 이미지 업로드 실패: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(gameId)
          .update(updateData);

      _isLoading = false;
      _shouldDeleteImage = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('직관기록 업데이트 실패: $e');
      _isLoading = false;
      _shouldDeleteImage = false;
      notifyListeners();
      return false;
    }
  }

  // 직관기록 삭제
  Future<bool> deleteRecord(AttendanceModel attendance) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 이미지가 있으면 Storage에서 삭제
      if (attendance.imageUrl != null && attendance.imageUrl!.isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .refFromURL(attendance.imageUrl!)
              .delete();
          print('직관 이미지 삭제: ${attendance.imageUrl}');
        } catch (e) {
          print('이미지 삭제 실패 ${attendance.imageUrl}: $e');
          // 이미지 삭제 실패해도 Firestore 문서 삭제는 계속 진행
        }
      }

      // Firestore에서 문서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('attendances')
          .doc(attendance.gameId)
          .delete();

      print('직관기록 삭제 완료: ${attendance.gameId}');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('직관기록 삭제 실패: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
