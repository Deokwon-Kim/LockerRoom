import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/seat_view_model.dart';
import 'package:lockerroom/provider/seat_view_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class SeatViewUploadPage extends StatefulWidget {
  final String? initialStadium;

  const SeatViewUploadPage({super.key, this.initialStadium});

  @override
  State<SeatViewUploadPage> createState() => _SeatViewUploadPageState();
}

class _SeatViewUploadPageState extends State<SeatViewUploadPage> {
  late String _selectedStadium;
  String _selectedZone = '1루';
  final TextEditingController _seatController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _selectedTags = [];
  final List<File> _images = [];

  @override
  void initState() {
    super.initState();
    _selectedStadium = widget.initialStadium != null
        ? SeatViewModel.normalizeStadium(widget.initialStadium!)
        : kSeatViewStadiums.first;
  }

  @override
  void dispose() {
    _seatController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _showStadiumPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: WHITE,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '구장 선택',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: GRAYSCALE_LABEL_950,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetCtx).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: kSeatViewStadiums.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final st = kSeatViewStadiums[index];
                      final selected = st == _selectedStadium;
                      final photo = kStadiumPhotoAssets[st];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() => _selectedStadium = st);
                          Navigator.pop(sheetCtx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? ACCENT_CORAL.withValues(alpha: 0.08)
                                : BACKGROUND_COLOR,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? ACCENT_CORAL
                                  : GRAYSCALE_LABEL_200,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: photo != null
                                    ? Image.asset(
                                        photo,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      )
                                    : const SizedBox(width: 44, height: 44),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  st,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? ACCENT_CORAL
                                        : GRAYSCALE_LABEL_950,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: ACCENT_CORAL,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final x in picked) {
          if (_images.length < 5) {
            _images.add(File(x.path));
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('일부 사진을 불러오지 못했습니다. 다른 사진을 선택해주세요.'),
      );
    }
  }

  Future<void> _submit() async {
    if (_seatController.text.trim().isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('좌석 정보(블럭·열)를 입력해주세요'),
      );
      return;
    }
    if (_images.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('시야 사진을 1장 이상 선택해주세요'),
      );
      return;
    }

    final up = context.read<UserProvider>();
    final ok = await context.read<SeatViewProvider>().createPost(
      stadium: _selectedStadium,
      zone: _selectedZone,
      seatText: _seatController.text,
      review: _reviewController.text,
      tags: _selectedTags,
      images: _images,
      userNickName: up.nickname ?? up.currentUser?.displayName,
      userProfileImage: up.currentUser?.photoURL,
    );

    if (!mounted) return;
    if (ok) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('좌석 시야가 공유되었습니다!'),
      );
      Navigator.pop(context);
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('업로드 중 오류가 발생했습니다'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = context.watch<SeatViewProvider>().isUploading;
    final uploadZones = kSeatViewZones.where((z) => z != '전체').toList();

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '좌석 시야 올리기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: GRAYSCALE_LABEL_950,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '구장 선택',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showStadiumPickerSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GRAYSCALE_LABEL_200),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kStadiumPhotoAssets[_selectedStadium] != null
                              ? Image.asset(
                                  kStadiumPhotoAssets[_selectedStadium]!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: GRAYSCALE_LABEL_100,
                                  child: const Icon(
                                    Icons.stadium_rounded,
                                    color: GRAYSCALE_LABEL_500,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStadium,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: GRAYSCALE_LABEL_950,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${kStadiumShortNames[_selectedStadium] ?? ''} · 탭하여 구장 변경',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: GRAYSCALE_LABEL_500,
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
                            color: BACKGROUND_COLOR,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '변경',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: BUTTON,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: BUTTON,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  '구역 선택',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: uploadZones.map((z) {
                    final selected = z == _selectedZone;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedZone = z),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? ACCENT_CORAL : WHITE,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? ACCENT_CORAL
                                : GRAYSCALE_LABEL_200,
                          ),
                        ),
                        child: Text(
                          z,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? WHITE : GRAYSCALE_LABEL_700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                const Text(
                  '좌석명 (블럭·열)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _seatController,
                  cursorColor: BUTTON,
                  decoration: InputDecoration(
                    hintText: '예: 1루 네이비석 306블럭 3열',
                    filled: true,
                    fillColor: WHITE,
                    prefixIcon: const Icon(Icons.event_seat_outlined, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BUTTON, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  '시야 사진 (최대 5장)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 96,
                          height: 96,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GRAYSCALE_LABEL_300),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 26,
                                color: GRAYSCALE_LABEL_600,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '사진 추가',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: GRAYSCALE_LABEL_600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ..._images.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              margin: const EdgeInsets.only(right: 10),
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Image.file(entry.value, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 14,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _images.removeAt(entry.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
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
                const SizedBox(height: 18),

                const Text(
                  '좌석 특징 태그 (선택)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSeatViewTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? BUTTON : WHITE,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? BUTTON : GRAYSCALE_LABEL_200,
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? WHITE : GRAYSCALE_LABEL_700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                const Text(
                  '시야 한줄평 (선택)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  cursorColor: BUTTON,
                  decoration: InputDecoration(
                    hintText: '그물망 가림 여부, 햇빛, 응원 열기 등을 적어주세요',
                    filled: true,
                    fillColor: WHITE,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: GRAYSCALE_LABEL_200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: BUTTON, width: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BUTTON,
                  foregroundColor: WHITE,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: WHITE,
                        ),
                      )
                    : const Text(
                        '좌석 시야 공유하기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
