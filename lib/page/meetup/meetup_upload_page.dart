import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/meetup_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/meetup_provider.dart';
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
      // Note: _selectedSchedules will be set in _loadSchedules after it completes
    }
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final schedules = await ScheduleService().loadSchedules();
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
    if (_selectedImages.length >= 4) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        title: const Text('사진은 최대 4장까지 첨부할 수 있습니다'),
      );
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        limit: 4 - _selectedImages.length,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('이미지 선택 실패: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
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
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),
          child: Theme(
            data: base.copyWith(
              datePickerTheme: const DatePickerThemeData(
                backgroundColor: BACKGROUND_COLOR,
                headerBackgroundColor: BACKGROUND_COLOR,
                surfaceTintColor: Colors.transparent,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: context
                    .read<TeamProvider>()
                    .selectedTeam
                    ?.color, // 선택 색상
                onPrimary: WHITE,
                surface: BLACK,
                onSurface: BLACK,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: context
                      .read<TeamProvider>()
                      .selectedTeam
                      ?.color,
                ),
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
      backgroundColor: BACKGROUND_COLOR,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (dailySchedules.isEmpty)
                const Expanded(
                  child: Center(child: Text('해당 날짜에 예정된 경기가 없습니다')),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.shade50 : WHITE,
      child: InkWell(
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
                    color: GRAYSCALE_LABEL_500,
                  ),
                  SizedBox(width: 4),
                  Text(
                    dateFormat.format(schedule.dateTimeKst),
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.access_time, size: 14, color: GRAYSCALE_LABEL_500),
                  SizedBox(width: 4),
                  Text(
                    timeFormat.format(schedule.dateTimeKst),
                    style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_500),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${schedule.homeTeam} vs ${schedule.awayTeam}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: Colors.blue),
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
        title: Text('응원팀을 선택해주세요'),
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

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.read<TeamProvider>();
    final selectedTeam = teamProvider.selectedTeam;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: selectedTeam?.color ?? BUTTON,
        title: Text(
          _isEditMode ? '직관 모임 수정하기' : '직관 모임 만들기',
          style: TextStyle(
            fontSize: 18,
            color: WHITE,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: WHITE),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _submit,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: WHITE,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isEditMode ? '수정' : '등록',
                    style: TextStyle(
                      fontSize: 16,
                      color: WHITE,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                '모임제목',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              // 모임 제목
              TextFormField(
                cursorColor: selectedTeam?.color ?? BUTTON,
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: '예) 같이 응원하실 분 구해요!',
                  hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // 경기 날짜 선택
              InkWell(
                onTap: _selectDate,
                child: Card(
                  color: BACKGROUND_COLOR,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '경기 날짜 *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedDate == null
                                  ? '날짜를 선택해주세요'
                                  : DateFormat(
                                      'yyyy년 MM월 dd일 (E)',
                                      'ko_KR',
                                    ).format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? GRAYSCALE_LABEL_500
                                    : BLACK,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: selectedTeam?.color ?? BUTTON,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 경기 선택 카드
              Card(
                color: selectedTeam?.color,
                child: InkWell(
                  onTap: _showSchedulePicker,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '경기 선택 *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: WHITE,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: WHITE,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ... (표시 부분)
                        if (_selectedSchedules == null)
                          Text(
                            _selectedDate == null
                                ? '날짜를 먼저 선택해주세요'
                                : '경기를 선택해주세요',
                            style: TextStyle(color: WHITE),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedSchedules!.homeTeam} vs ${_selectedSchedules!.awayTeam}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: WHITE,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('HH:mm').format(_selectedSchedules!.dateTimeKst)} | ${_selectedSchedules!.stadium}',
                                style: TextStyle(fontSize: 12, color: WHITE),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // 응원팀 선택
              if (_selectedSchedules != null)
                DropdownButtonFormField<String>(
                  dropdownColor: WHITE,
                  value: _selectedMyTeam,
                  decoration: InputDecoration(
                    labelText: '내가 응원하는 팀',
                    labelStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                    ),
                  ),
                  items:
                      [
                        _selectedSchedules!.homeTeam,
                        _selectedSchedules!.awayTeam,
                      ].toSet().map((team) {
                        return DropdownMenuItem(value: team, child: Text(team));
                      }).toList(),
                  onChanged: (value) => setState(() => _selectedMyTeam = value),
                  validator: (value) => value == null ? '응원팀을 선택해주세요' : null,
                ),
              SizedBox(height: 16),

              // 최대 참여인원
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '모집 인원',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$_maxParticipants명',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _maxParticipants > 2
                            ? () {
                                setState(() {
                                  _maxParticipants--;
                                });
                              }
                            : null,
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: _maxParticipants > 2
                              ? selectedTeam?.color ?? BUTTON
                              : GRAYSCALE_LABEL_300,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          activeColor: selectedTeam?.color ?? BUTTON,
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
                            ? () {
                                setState(() {
                                  _maxParticipants++;
                                });
                              }
                            : null,
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: _maxParticipants < 20
                              ? selectedTeam?.color ?? BUTTON
                              : GRAYSCALE_LABEL_300,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Text(
                    '상세설명',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  // 모임 설명
                  TextFormField(
                    cursorColor: selectedTeam?.color ?? BUTTON,
                    controller: _contentController,
                    decoration: InputDecoration(
                      hintText: '모임에 대한 설명을 입력해주세요',
                      hintStyle: TextStyle(color: GRAYSCALE_LABEL_400),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: GRAYSCALE_LABEL_300),
                      ),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '설명을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 사진 첨부
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '사진 첨부',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_existingImageUrls.length + _selectedImages.length}/4',
                            style: TextStyle(
                              color:
                                  (_existingImageUrls.length +
                                          _selectedImages.length) ==
                                      4
                                  ? Colors.red
                                  : GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 사진 추가 버튼
                            if (_existingImageUrls.length +
                                    _selectedImages.length <
                                4)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: InkWell(
                                  onTap: _pickImages,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: GRAYSCALE_LABEL_300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color:
                                          selectedTeam?.color ??
                                          GRAYSCALE_LABEL_500,
                                    ),
                                  ),
                                ),
                              ),
                            // 기존 이미지 목록
                            ..._existingImageUrls.asMap().entries.map((entry) {
                              final index = entry.key;
                              final url = entry.value;
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(url),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 16,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _existingImageUrls.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: WHITE,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            // 선택된 사진 목록
                            ..._selectedImages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final image = entry.value;
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: FileImage(File(image.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 16,
                                    child: InkWell(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 12,
                                          color: WHITE,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
