import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/model/ticket_scan_result_model.dart';
import 'package:lockerroom/page/intution_record/intution_record_upload_page.dart';
import 'package:lockerroom/model/scanned_ticket_data.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:lockerroom/services/ticket_parser_service.dart';
import 'package:toastification/toastification.dart';

class TicketScanProvider extends ChangeNotifier {
  static const MethodChannel _visionOcrChannel = MethodChannel(
    'com.lockerroom/vision_ocr',
  );

  final ScheduleProvider? _scheduleProvider;

  TicketScanProvider({ScheduleProvider? scheduleProvider})
    : _scheduleProvider = scheduleProvider;

  final _koreanRecognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );
  final _japaneseRecognizer = TextRecognizer(
    script: TextRecognitionScript.japanese,
  );
  final _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ScheduleService _scheduleService = ScheduleService();
  final ImagePicker _picker = ImagePicker();
  // 1. 카메라 상태 (Provider가 관리)
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isFlashOn => _isFlashOn;
  // 2. OCR 및 분석 상태
  bool _isProcessing = false;
  String _statusMessage = '';
  File? _scannedImageFile;
  TicketScanResultModel? _parsedResult;
  List<ScheduleModel> _matchedGames = [];
  ScheduleModel? _selectedMatchedGame;
  String? _errorMessage;
  bool get isProcessing => _isProcessing;
  String get statusMessage => _statusMessage;
  File? get scannedImageFile => _scannedImageFile;
  TicketScanResultModel? get parsedResult => _parsedResult;
  List<ScheduleModel> get matchedGames => _matchedGames;
  ScheduleModel? get selectedMatchedGame => _selectedMatchedGame;
  String? get errorMessage => _errorMessage;
  // 3. 결과 편집 상태 (컨트롤러 포함)
  DateTime? selectedDate;
  String? selectedTime;
  final TextEditingController seatController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  // --- [카메라 제어 메서드] ---
  Future<void> initCamera() async {
    try {
      _errorMessage = null;
      notifyListeners();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _errorMessage =
            '사용 가능한 카메라를 찾을 수 없습니다.\n(시뮬레이터 환경에서는 갤러리 선택을 이용해 주세요.)';
        notifyListeners();
        return;
      }

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        Platform.isAndroid ? ResolutionPreset.high : ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.jpeg : null,
      );
      await _cameraController!.initialize();
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = '카메라 초기화 실패: $e';
      notifyListeners();
    }
  }

  Future<void> toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      _isFlashOn = !_isFlashOn;
      notifyListeners();
    } catch (e) {
      debugPrint('플래시 설정 실패: $e');
    }
  }

  void disposeCamera() {
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    _isFlashOn = false;
    controller?.dispose();
  }

  // --- [촬영 및 갤러리 스캔 액션] ---
  Future<bool> takePictureAndScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }
    if (_isProcessing) return false;
    try {
      debugPrint('[TicketScan] 촬영 시작');
      final XFile photo = await _cameraController!.takePicture();
      debugPrint('[TicketScan] 촬영 성공: ${photo.path}');
      if (_isFlashOn) await toggleFlash();
      return await scanImageFile(File(photo.path));
    } catch (e, stack) {
      debugPrint('[TicketScan] 촬영 오류: $e\n$stack');
      _errorMessage = '촬영 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pickGalleryAndScan() async {
    if (_isProcessing) return false;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image == null) return false;
      return await scanImageFile(File(image.path));
    } catch (e, stack) {
      debugPrint('[TicketScan] 갤러리 오류: $e\n$stack');
      _errorMessage = '갤러리 선택 실패: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pickCameraAndScan() async {
    if (_isProcessing) return false;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (image == null) return false;
      return await scanImageFile(File(image.path));
    } catch (e, stack) {
      debugPrint('[TicketScan] 카메라 선택 오류: $e\n$stack');
      _errorMessage = '카메라 촬영 실패: $e';
      notifyListeners();
      return false;
    }
  }

  // --- [공통 OCR 분석 및 편집 데이터 세팅] ---
  Future<bool> scanImageFile(File file) async {
    try {
      _scannedImageFile = file;
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = '티켓에서 텍스트를 읽고 있습니다...';
      // 이전 스캔 잔여 상태 완벽 초기화
      _parsedResult = null;
      _selectedMatchedGame = null;
      _matchedGames.clear();
      selectedDate = null;
      selectedTime = null;
      seatController.clear();
      priceController.clear();
      notifyListeners();

      String koText = '';
      String jaText = '';
      String latinText = '';

      if (Platform.isIOS) {
        // iOS: Apple 네이티브 Vision Framework (ko-KR + ja-JP + en-US 고정밀 동시 인식)
        try {
          debugPrint('[TicketScan] iOS Apple Vision OCR 시작');
          final visionText = await _visionOcrChannel.invokeMethod<String>(
            'recognizeText',
            {'path': _scannedImageFile!.path},
          );
          koText = visionText ?? '';
          debugPrint('[TicketScan] Apple Vision OCR 완료 (${koText.length}자)');
          debugPrint('[TicketScan] Vision 인식 텍스트:\n$koText');
        } catch (e) {
          debugPrint('[TicketScan] Apple Vision OCR 오류 (ML Kit 폴백): $e');
        }
      }

      // Android 또는 iOS Vision 실패 시 ML Kit 폴백
      if (koText.trim().isEmpty) {
        final inputImage = InputImage.fromFile(_scannedImageFile!);
        debugPrint('[TicketScan] ML Kit OCR 텍스트 인식 시작');
        try {
          final koResult = await _koreanRecognizer.processImage(inputImage);
          koText = koResult.text;
        } catch (e) {
          debugPrint('[TicketScan] ML Kit 한국어 인식 실패: $e');
        }
        try {
          final jaResult = await _japaneseRecognizer.processImage(inputImage);
          jaText = jaResult.text;
        } catch (e) {
          debugPrint('[TicketScan] ML Kit 일본어 인식 실패: $e');
        }
        try {
          final latinResult = await _latinRecognizer.processImage(inputImage);
          latinText = latinResult.text;
        } catch (e) {
          debugPrint('[TicketScan] ML Kit 라틴 인식 실패: $e');
        }
        debugPrint(
          '[TicketScan] ML Kit OCR 완료 (한국어: ${koText.length}자, 일본어: ${jaText.length}자, 라틴: ${latinText.length}자)',
        );
        debugPrint('[TicketScan] 한국어 텍스트:\n$koText');
        debugPrint('[TicketScan] 일본어 텍스트:\n$jaText');
        debugPrint('[TicketScan] 라틴 텍스트:\n$latinText');
      }

      // 지능형 앙상블 텍스트 파싱
      _statusMessage = '경기일정을 매칭하고 있습니다...';
      notifyListeners();
      _parsedResult = TicketParserService.parseEnsemble(
        koreanText: koText,
        japaneseText: jaText.isNotEmpty ? jaText : null,
        latinText: latinText.isNotEmpty ? latinText : null,
      );
      debugPrint(
        '[TicketScan] 파싱 결과 -> 날짜: ${_parsedResult?.gameDate}, 시간: ${_parsedResult?.gameTime}, 팀: ${_parsedResult?.detectedTeams}, 좌석: ${_parsedResult?.seatType}, 금액: ${_parsedResult?.ticketPrice}',
      );

      // 이번 스캔으로 인식된 날짜 즉시 반영
      selectedDate = _parsedResult?.gameDate ?? selectedDate;

      // 경기 매칭
      await _matchSchedule();

      // 편집 필드 값 주입
      _setupEditFields();

      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('[TicketScan] OCR 오류: $e\n$stack');
      _isProcessing = false;
      _errorMessage = '티켓 인식 오류: $e';
      notifyListeners();
      return false;
    }
  }

  void _setupEditFields() {
    selectedDate = _parsedResult?.gameDate ?? selectedDate;
    // 날짜 기반 공식 일정의 경기 시간 우선 불러오기
    if (_selectedMatchedGame != null) {
      final h = _selectedMatchedGame!.dateTimeKst.hour.toString().padLeft(
        2,
        '0',
      );
      final m = _selectedMatchedGame!.dateTimeKst.minute.toString().padLeft(
        2,
        '0',
      );
      selectedTime = '$h:$m';
    } else if (_matchedGames.isNotEmpty) {
      final h = _matchedGames.first.dateTimeKst.hour.toString().padLeft(2, '0');
      final m = _matchedGames.first.dateTimeKst.minute.toString().padLeft(
        2,
        '0',
      );
      selectedTime = '$h:$m';
    } else {
      selectedTime = _parsedResult?.gameTime;
    }
    seatController.text = _parsedResult?.seatType ?? '';
    priceController.text = '${_parsedResult?.ticketPrice ?? 0}';
  }

  Future<void> _matchSchedule() async {
    _matchedGames.clear();
    _selectedMatchedGame = null;
    final targetDate = selectedDate ?? _parsedResult?.gameDate;
    if (targetDate == null) return;

    // 1) ScheduleProvider(정적 CSV + 실시간 Firestore games 통합 데이터) 우선 사용
    final List<ScheduleModel> allSchedules =
        (_scheduleProvider != null && _scheduleProvider.loaded)
        ? _scheduleProvider.allSchedules
        : await _scheduleService.loadSchedules();

    final sameDayGames = allSchedules.where((g) {
      return g.dateTimeKst.year == targetDate.year &&
          g.dateTimeKst.month == targetDate.month &&
          g.dateTimeKst.day == targetDate.day;
    }).toList();

    // 2) 해당 날짜 경기가 없다면 Firestore 'games' 컬렉션 직접 조회 (우천순연, 잔여경기, 포스트시즌 등)
    if (sameDayGames.isEmpty) {
      try {
        final startOfDay = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));
        final snapshot = await FirebaseFirestore.instance
            .collection('games')
            .where(
              'dateTimeKst',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('dateTimeKst', isLessThan: Timestamp.fromDate(endOfDay))
            .get();
        for (final doc in snapshot.docs) {
          try {
            sameDayGames.add(ScheduleModel.fromFirestore(doc));
          } catch (e) {
            debugPrint('[TicketScan] Firestore 경기 파싱 실패 (${doc.id}): $e');
          }
        }
      } catch (e) {
        debugPrint('[TicketScan] Firestore 경기 조회 실패: $e');
      }
    }

    if (sameDayGames.isEmpty) return;
    final detected = _parsedResult?.detectedTeams ?? [];
    List<ScheduleModel> candidateGames = [];
    if (detected.isNotEmpty) {
      candidateGames = sameDayGames.where((g) {
        return detected.contains(g.homeTeam) || detected.contains(g.awayTeam);
      }).toList();

      // 양쪽 팀이 모두 일치하는 경기를 최우선으로 정렬
      candidateGames.sort((a, b) {
        final aBoth =
            detected.contains(a.homeTeam) && detected.contains(a.awayTeam);
        final bBoth =
            detected.contains(b.homeTeam) && detected.contains(b.awayTeam);
        if (aBoth && !bBoth) return -1;
        if (!aBoth && bBoth) return 1;
        return 0;
      });

      // 양쪽 팀이 모두 일치하는 경기가 1개라면 자동 선택
      final bothMatch = candidateGames
          .where(
            (g) =>
                detected.contains(g.homeTeam) && detected.contains(g.awayTeam),
          )
          .toList();
      if (bothMatch.length == 1) {
        _selectedMatchedGame = bothMatch.first;
      }
    }
    _matchedGames = candidateGames.isNotEmpty ? candidateGames : sameDayGames;
    if (_selectedMatchedGame == null && _matchedGames.length == 1) {
      _selectedMatchedGame = _matchedGames.first;
    }
    // 경기가 선택되었거나 목록이 있으면 공식 경기 시작 시간으로 갱신
    if (_selectedMatchedGame != null) {
      final h = _selectedMatchedGame!.dateTimeKst.hour.toString().padLeft(
        2,
        '0',
      );
      final m = _selectedMatchedGame!.dateTimeKst.minute.toString().padLeft(
        2,
        '0',
      );
      selectedTime = '$h:$m';
    } else if (_matchedGames.isNotEmpty) {
      final h = _matchedGames.first.dateTimeKst.hour.toString().padLeft(2, '0');
      final m = _matchedGames.first.dateTimeKst.minute.toString().padLeft(
        2,
        '0',
      );
      selectedTime = '$h:$m';
    }
  }

  // --- [결과 편집 조작 메서드] ---
  void selectGame(ScheduleModel game) {
    debugPrint('[TicketScan] 경기 선택: ${game.awayTeam} vs ${game.homeTeam}');
    _selectedMatchedGame = game;
    // 선택한 경기의 공식 시작 시간으로 즉시 업데이트
    final h = game.dateTimeKst.hour.toString().padLeft(2, '0');
    final m = game.dateTimeKst.minute.toString().padLeft(2, '0');
    selectedTime = '$h:$m';
    notifyListeners();
  }

  void updateTicketImage(File newImage) {
    _scannedImageFile = newImage;
    notifyListeners();
  }

  Future<void> updateDate(DateTime newDate) async {
    selectedDate = newDate;
    await _matchSchedule();
    notifyListeners();
  }

  void updateTime(String newTime) {
    selectedTime = newTime;
    notifyListeners();
  }

  // --- [직관 기록 화면으로 최종 데이터 전달] ---
  void applyToRecord(BuildContext context) {
    if (_selectedMatchedGame == null || selectedDate == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        title: const Text('일치하는 경기를 선택해 주세요.'),
      );
      return;
    }
    DateTime finalGameDate = selectedDate!;
    if (selectedTime != null) {
      final parts = selectedTime!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          finalGameDate = DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            h,
            m,
          );
        }
      }
    }
    final int price =
        int.tryParse(priceController.text.replaceAll(',', '').trim()) ?? 0;
    final String seat = seatController.text.trim();
    final scannedData = ScannedTicketData(
      matchedGame: _selectedMatchedGame!,
      gameDate: finalGameDate,
      ticketPrice: price,
      seat: (seat.isNotEmpty && seat != '미지정') ? seat : null,
      ticketImageFile: null,
    );

    // 스캔(TickerCameraScanPage) & 결과(TicketScanResultPage) 화면만 닫고
    // 직관기록 리스트 화면 위에 직관 기록 작성 화면을 띄움 (저장 후 리스트 화면으로 복귀)
    int removedCount = 0;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => IntutionRecordUploadPage(initialScanData: scannedData),
      ),
      (route) => removedCount++ >= 2 || route.isFirst,
    );
  }

  @override
  void dispose() {
    _koreanRecognizer.close();
    _japaneseRecognizer.close();
    _latinRecognizer.close();
    seatController.dispose();
    priceController.dispose();
    disposeCamera();
    super.dispose();
  }
}
