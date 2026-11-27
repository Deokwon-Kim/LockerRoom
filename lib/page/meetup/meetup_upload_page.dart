import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/mate_checklist_model.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class MeetupUploadPage extends StatefulWidget {
  final MeetupModel? meetupToEdit;
  const MeetupUploadPage({super.key, this.meetupToEdit});

  @override
  State<MeetupUploadPage> createState() => _MeetupUploadPageState();
}

class _MeetupUploadPageState extends State<MeetupUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  List<ScheduleModel> _allSchedules = [];
  ScheduleModel? _selectedSchedules;
  DateTime? _selectedDate;
  String? _selectedMyTeam;
  int _maxParticipants = 5;
  int? _minBirthYear;
  int? _maxBirthYear;
  bool _isApprovalRequired = false;
  final _minYearController = TextEditingController();
  final _maxYearController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  bool _isUploading = false;
  List<String> _existingImageUrls = [];
  bool get _isEditMode => widget.meetupToEdit != null;
  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final meetup = widget.meetupToEdit!;
      _titleController.text = meetup.title;
      _contentController.text = meetup.content;
      _maxParticipants = meetup.maxParticipants;
      _existingImageUrls = List.from(meetup.images);
      _selectedDate = DateTime.parse(meetup.gameDate);
      _selectedMyTeam = meetup.myTeam;
      _minBirthYear = meetup.minBirthYear;
      _maxBirthYear = meetup.maxBirthYear;
      _isApprovalRequired = meetup.isApprovalRequired;
      if (_minBirthYear != null)
        _minYearController.text = _minBirthYear.toString();
      if (_maxBirthYear != null)
        _maxYearController.text = _maxBirthYear.toString();
      // Note: _selectedSchedules will be set in _loadSchedules after it completes
    }
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final scheduleProvider = context.read<ScheduleProvider>();
      if (!scheduleProvider.loaded) {
        await scheduleProvider.load();
      }
      final schedules = scheduleProvider.allSchedules.isNotEmpty
          ? scheduleProvider.allSchedules
          : await ScheduleService().loadSchedules();
      final now = DateTime.now();

      // 미래 경기만 필터링 (오늘 포함)
      if (!mounted) return;

      setState(() {
        _allSchedules = schedules.where((s) {
          if (_isEditMode) {
            final editDate = DateTime.parse(widget.meetupToEdit!.gameDate);
            if (s.dateTimeKst.year == editDate.year &&
                s.dateTimeKst.month == editDate.month &&
                s.dateTimeKst.day == editDate.day) {
              return true;
            }
          }
          return s.dateTimeKst.isAfter(now.subtract(const Duration(days: 1)));
        }).toList();

        // 날짜순 정렬
        _allSchedules.sort((a, b) => a.dateTimeKst.compareTo(b.dateTimeKst));

        if (_isEditMode) {
          final meetup = widget.meetupToEdit!;
          _selectedSchedules = _allSchedules.firstWhere(
            (s) =>
                s.homeTeam == meetup.homeTeam &&
                s.awayTeam == meetup.awayTeam &&
                s.stadium == meetup.stadium &&
                DateFormat('yyyy-MM-dd').format(s.dateTimeKst) ==
                    meetup.gameDate,
            orElse: () => _selectedSchedules!,
          );
        }
      });
    } catch (e) {
      print('경기 일정 로드 실패:$e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _existingImageUrls.clear();
          _selectedImages = [image];
        });
      }
    } catch (e) {
      print('이미지 선택 실패: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];

    List<String> downloadUrls = [];
    try {
      for (var image in _selectedImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('meetup_images')
            .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        downloadUrls.add(url);
      }
    } catch (e) {
      print('이미지 업로드 실패: $e');
      throw Exception('이미지 업로드 중 오류가 발생했습니다');
    }
    return downloadUrls;
  }

  List<ScheduleModel> _getSchedulesForDate(DateTime date) {
    return _allSchedules.where((s) {
      return s.dateTimeKst.year == date.year &&
          s.dateTimeKst.month == date.month &&
          s.dateTimeKst.day == date.day;
    }).toList();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    // 마지막 경기 날짜 찾기 (데이터가 있는 경우)
    final lastDate = _allSchedules.isNotEmpty
        ? _allSchedules.last.dateTimeKst
        : now.add(const Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)), // 어제 경기도 혹시 모르니
      lastDate: lastDate,
      builder: (context, child) {
        final base = Theme.of(context);
        final rawTeamColor =
            context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
        final readableTeam = context.readableColor(rawTeamColor);
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: context.cardColor,
                headerBackgroundColor: context.cardColor,
                headerForegroundColor: context.textPrimary,
                surfaceTintColor: Colors.transparent,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: readableTeam,
                onPrimary:
                    context.isDarkMode && readableTeam.computeLuminance() > 0.5
                    ? BLACK
                    : WHITE,
                surface: context.cardColor,
                onSurface: context.textPrimary,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: readableTeam),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _selectedSchedules = null; // 날짜 바뀌면 경기 선택 초기화
        _selectedMyTeam = null; // 응원팀 선택 초기화
      });
    }
  }

  void _showSchedulePicker() {
    if (_selectedDate == null) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('날짜를 먼저 선택해주세요'),
      );
      return;
    }

    final dailySchedules = _getSchedulesForDate(_selectedDate!);

    showModalBottomSheet(
      backgroundColor: context.cardColor,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${DateFormat('MM월 dd일').format(_selectedDate!)} 경기 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: context.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (dailySchedules.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      '해당 날짜에 예정된 경기가 없습니다',
                      style: TextStyle(color: context.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: dailySchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = dailySchedules[index];
                      return _buildScheduleCard(
                        schedule,
                        setState,
                      ); // 모달 내부 setState 불필요
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(
    ScheduleModel schedule,
    StateSetter? setModalState,
  ) {
    final isSelected = _selectedSchedules?.gameId == schedule.gameId;
    final dateFormat = DateFormat('MM월 dd일 (E)', 'ko_KR');
    final timeFormat = DateFormat('HH:mm');
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final readableTeam = context.readableColor(teamColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? readableTeam.withValues(alpha: 0.16)
          : context.surfaceAltColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? readableTeam : context.borderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedSchedules = schedule;
            _selectedMyTeam = null;
          });
          // setModalState(() {}); // 모달 상태 변경 불필요
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(schedule.dateTimeKst),
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 14, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    timeFormat.format(schedule.dateTimeKst),
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${schedule.awayTeam} vs ${schedule.homeTeam}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: readableTeam),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.stadium, size: 14, color: GRAYSCALE_LABEL_500),
                  SizedBox(width: 4),
                  Text(
                    schedule.stadium,
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _minYearController.dispose();
    _maxYearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 사진 필수 체크
    if (_existingImageUrls.isEmpty && _selectedImages.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('대표 사진을 등록해주세요'),
      );
      return;
    }
    if (_selectedSchedules == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('경기를 선택해주세요'),
      );
      return;
    }
    if (_selectedMyTeam == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: Duration(seconds: 2),
        title: Text('같이 응원하고 싶은 팀을 선택해주세요'),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      // 1. 이미지 업로드
      final imageUrls = await _uploadImages();

      // 2. 사용자 정보 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userNickName = userDoc.data()?['userNickName'] ?? '익명';
      final userProfileImage = userDoc.data()?['profileImage'];

      // 3. MeetupModel 생성/수정
      final schedule = _selectedSchedules!;
      final gameDate = DateFormat('yyyy-MM-dd').format(schedule.dateTimeKst);
      final gameTime = DateFormat('HH:mm').format(schedule.dateTimeKst);

      if (_isEditMode) {
        final existingMeetup = widget.meetupToEdit!;
        final updatedMeetup = {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'gameDate': gameDate,
          'gameTime': gameTime,
          'stadium': schedule.stadium,
          'homeTeam': schedule.homeTeam,
          'awayTeam': schedule.awayTeam,
          'myTeam': _selectedMyTeam!,
          'maxParticipants': _maxParticipants,
          'images': [..._existingImageUrls, ...imageUrls],
          'minBirthYear': int.tryParse(_minYearController.text),
          'maxBirthYear': int.tryParse(_maxYearController.text),
          'isApprovalRequired': _isApprovalRequired,
        };

        final success = await context.read<MeetupProvider>().updateMeetup(
          existingMeetup.id,
          updatedMeetup,
        );

        if (success) {
          // Firebase Analytics 이벤트 기록
          FirebaseAnalytics.instance.logEvent(
            name: 'meetup_updated',
            parameters: {
              'meetup_id': existingMeetup.id,
              'my_team': _selectedMyTeam!,
              'max_participants': _maxParticipants,
            },
          );

          if (!mounted) return;
          Navigator.pop(context);
          toastification.show(
            context: context,
            type: ToastificationType.success,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: const Duration(seconds: 2),
            title: const Text('모임이 수정되었습니다'),
          );
        } else {
          throw Exception('모임 수정 실패');
        }
      } else {
        MateChecklistModel? hostMateTags;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final rawChecklist = userDoc.data()?['mateChecklist'];
          if (rawChecklist is Map<String, dynamic>) {
            hostMateTags = MateChecklistModel.fromMap(rawChecklist);
          }
        } catch (_) {}

        final meetup = MeetupModel(
          id: '',
          userId: user.uid,
          userNickName: userNickName,
          userProfileImage: userProfileImage,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          gameDate: gameDate,
          gameTime: gameTime,
          stadium: schedule.stadium,
          homeTeam: schedule.homeTeam,
          awayTeam: schedule.awayTeam,
          myTeam: _selectedMyTeam!,
          maxParticipants: _maxParticipants,
          participants: [user.uid],
          createdAt: DateTime.now(),
          images: imageUrls,
          minBirthYear: int.tryParse(_minYearController.text),
          maxBirthYear: int.tryParse(_maxYearController.text),
          isApprovalRequired: _isApprovalRequired,
          mateTags: hostMateTags,
        );

        final success = await context.read<MeetupProvider>().createMeetup(
          meetup,
        );

        if (success) {
          // Firebase Analytics 이벤트 기록
          FirebaseAnalytics.instance.logEvent(
            name: 'meetup_created',
            parameters: {
              'max_participants': meetup.maxParticipants,
              'my_team': meetup.myTeam,
              'game_date': meetup.gameDate,
              'stadium': meetup.stadium,
            },
          );

          if (!mounted) return;
          Navigator.pop(context);
          toastification.show(
            context: context,
            type: ToastificationType.success,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: const Duration(seconds: 2),
            title: const Text('모임이 생성되었습니다'),
          );
        } else {
          throw Exception('모임 생성 실패');
        }
      }
    } catch (e) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: Text(e.toString()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  int get _completedStepCount {
    int count = 0;
    if (_selectedDate != null) count++;
    if (_selectedSchedules != null) count++;
    if (_selectedMyTeam != null) count++;
    if (_titleController.text.trim().isNotEmpty) count++;
    if (_contentController.text.trim().isNotEmpty) count++;
    if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;
    final teamColor = selectedTeam?.color ?? BUTTON;
    final readableTeam = context.readableColor(teamColor);
    final completedSteps = _completedStepCount;
    final isReadyToSubmit = completedSteps == 6;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? '직관 모임 수정' : '직관 모임 만들기',
          style: TextStyle(
            fontSize: 18,
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ACCENT_CORAL.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$completedSteps/6 완료',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: ACCENT_CORAL,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: completedSteps / 6,
                minHeight: 4,
                backgroundColor: context.surfaceAltColor,
                valueColor: const AlwaysStoppedAnimation<Color>(ACCENT_CORAL),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              // 1. 경기 · 응원팀 선택 카드
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: '1. 경기 · 응원팀 선택',
                      badgeText: '필수',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceAltColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '경기 날짜',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedDate == null
                                      ? '날짜를 선택해주세요'
                                      : DateFormat(
                                          'yyyy년 MM월 dd일 (E)',
                                          'ko_KR',
                                        ).format(_selectedDate!),
                                  style: TextStyle(
                                    color: _selectedDate == null
                                        ? context.textMuted
                                        : context.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 19,
                              color: readableTeam,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _showSchedulePicker,
                      borderRadius: BorderRadius.circular(16),
                      child: _selectedSchedules == null
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: context.surfaceAltColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '경기 선택',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: context.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedDate == null
                                            ? '날짜를 먼저 선택해주세요'
                                            : '터치하여 경기를 선택해주세요',
                                        style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 15,
                                    color: context.textMuted,
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    teamColor,
                                    Color.lerp(teamColor, BLACK, 0.35) ??
                                        teamColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_selectedSchedules!.awayTeam} vs ${_selectedSchedules!.homeTeam}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: WHITE,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${DateFormat('HH:mm').format(_selectedSchedules!.dateTimeKst)} · ${_selectedSchedules!.stadium}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: WHITE.withValues(
                                              alpha: 0.85,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WHITE.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '변경',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: WHITE,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (_selectedSchedules != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '같이 응원하고 싶은 팀',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children:
                            [
                              _selectedSchedules!.awayTeam,
                              _selectedSchedules!.homeTeam,
                            ].toSet().toList().asMap().entries.map((entry) {
                              final idx = entry.key;
                              final teamName = entry.value;
                              final isSelected = _selectedMyTeam == teamName;
                              final matchedTeam = teamProvider.findTeamByName(
                                teamName,
                              );
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: idx == 0 ? 0 : 8,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => setState(
                                      () => _selectedMyTeam = teamName,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? readableTeam.withValues(
                                                alpha: 0.14,
                                              )
                                            : context.surfaceAltColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? readableTeam
                                              : context.borderColor,
                                          width: isSelected ? 1.8 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (matchedTeam != null &&
                                              matchedTeam
                                                  .logoPath
                                                  .isNotEmpty) ...[
                                            Image.asset(
                                              matchedTeam.logoPath,
                                              width: 22,
                                              height: 22,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Flexible(
                                            child: Text(
                                              '$teamName 응원',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected
                                                    ? readableTeam
                                                    : context.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. 모임 소개 카드
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: '2. 모임 소개',
                      badgeText: '필수',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      cursorColor: readableTeam,
                      controller: _titleController,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: _buildInputDecoration(
                        context: context,
                        hintText: '예) 같이 응원하실 분 구해요!',
                        accentColor: readableTeam,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '제목을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['치맥 직관 🍗', '초보 환영 ⚾', '열정 응원 🔥']
                          .map(
                            (tag) => InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                final current = _titleController.text.trim();
                                if (!current.contains(tag)) {
                                  _titleController.text = current.isEmpty
                                      ? tag
                                      : '$current $tag';
                                  _titleController.selection =
                                      TextSelection.fromPosition(
                                        TextPosition(
                                          offset: _titleController.text.length,
                                        ),
                                      );
                                  setState(() {});
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.surfaceAltColor,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: context.borderColor,
                                  ),
                                ),
                                child: Text(
                                  '+ $tag',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      cursorColor: readableTeam,
                      controller: _contentController,
                      maxLines: 5,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: _buildInputDecoration(
                        context: context,
                        hintText: '좌석 구역이나 모임 분위기를 자유롭게 적어주세요',
                        accentColor: readableTeam,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '설명을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. 인원 및 참여 조건 카드
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3. 인원 및 참여 조건',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          '$_maxParticipants명',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: readableTeam,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [2, 4, 6, 10].map((preset) {
                        final selected = _maxParticipants == preset;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _maxParticipants = preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? readableTeam
                                  : context.surfaceAltColor,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? readableTeam
                                    : context.borderColor,
                              ),
                            ),
                            child: Text(
                              '$preset명',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? (context.isDarkMode &&
                                              readableTeam.computeLuminance() >
                                                  0.5
                                          ? BLACK
                                          : WHITE)
                                    : context.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _maxParticipants > 2
                              ? () => setState(() => _maxParticipants--)
                              : null,
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: _maxParticipants > 2
                                ? readableTeam
                                : context.borderColor,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            activeColor: readableTeam,
                            inactiveColor: context.borderColor,
                            value: _maxParticipants.toDouble(),
                            min: 2,
                            max: 20,
                            onChanged: (value) {
                              setState(() => _maxParticipants = value.toInt());
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _maxParticipants < 20
                              ? () => setState(() => _maxParticipants++)
                              : null,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: _maxParticipants < 20
                                ? readableTeam
                                : context.borderColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '연령 제한 (선택)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textSecondary,
                          ),
                        ),
                        if (_minYearController.text.isNotEmpty ||
                            _maxYearController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _minYearController.clear();
                                _maxYearController.clear();
                              });
                            },
                            child: Text(
                              '초기화',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: readableTeam,
                              ),
                            ),
                          )
                        else
                          Text(
                            '미입력 시 전체',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minYearController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13.5,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: _buildInputDecoration(
                              context: context,
                              hintText: '최소 (예: 1995)',
                              accentColor: readableTeam,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '~',
                            style: TextStyle(
                              color: context.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _maxYearController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13.5,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: _buildInputDecoration(
                              context: context,
                              hintText: '최대 (예: 2005)',
                              accentColor: readableTeam,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfaceAltColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '방장 승인 후 참여',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '신청자 프로필을 확인한 뒤 수락할 수 있어요',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            activeThumbColor: WHITE,
                            activeTrackColor: context.isDarkMode
                                ? (teamColor.computeLuminance() < 0.22
                                      ? ACCENT_CORAL
                                      : teamColor)
                                : teamColor,
                            inactiveThumbColor: context.isDarkMode
                                ? DARK_TEXT_SECONDARY
                                : WHITE,
                            inactiveTrackColor: context.isDarkMode
                                ? DARK_BORDER_COLOR
                                : GRAYSCALE_LABEL_200,
                            value: _isApprovalRequired,
                            onChanged: (value) {
                              setState(() {
                                _isApprovalRequired = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. 대표 사진 카드
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: '4. 대표 사진',
                      badgeText: '필수',
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    if (_existingImageUrls.isNotEmpty)
                      _buildImagePreview(
                        imageProvider: NetworkImage(_existingImageUrls.first),
                        onRemove: () {
                          setState(() {
                            _existingImageUrls.clear();
                          });
                        },
                      )
                    else if (_selectedImages.isNotEmpty)
                      _buildImagePreview(
                        imageProvider: FileImage(
                          File(_selectedImages.first.path),
                        ),
                        onRemove: () {
                          setState(() {
                            _selectedImages.clear();
                          });
                        },
                      )
                    else
                      InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 170,
                          decoration: BoxDecoration(
                            color: context.surfaceAltColor,
                            border: Border.all(color: context.borderColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 38,
                                color: readableTeam,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '탭하여 대표 사진 업로드',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '경기장 또는 응원 사진 1장을 선택해주세요',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.isDarkMode
                ? (teamColor.computeLuminance() < 0.22
                      ? ACCENT_CORAL
                      : teamColor)
                : teamColor,
            foregroundColor: WHITE,
            disabledBackgroundColor: context.borderColor,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: WHITE,
                    strokeWidth: 2.2,
                  ),
                )
              : Text(
                  _isEditMode
                      ? '모임 수정하기'
                      : (isReadyToSubmit
                            ? '모임 등록하기'
                            : '모임 등록하기 ($completedSteps/6)'),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: WHITE,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String badgeText,
    bool isRequired = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isRequired
                ? ACCENT_CORAL.withValues(alpha: 0.14)
                : context.surfaceAltColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isRequired ? ACCENT_CORAL : context.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required BuildContext context,
    required String hintText,
    required Color accentColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: context.textMuted, fontSize: 13.5),
      filled: true,
      fillColor: context.surfaceAltColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: context.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: accentColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: RED_DANGER_TEXT_50),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: RED_DANGER_TEXT_50, width: 1.4),
      ),
    );
  }

  Widget _buildImagePreview({
    required ImageProvider imageProvider,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            children: [
              InkWell(
                onTap: _pickImages,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '변경',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: WHITE,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: WHITE),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
