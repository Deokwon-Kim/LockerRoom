import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/page/intution_record/ticket_scan_result_page.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:provider/provider.dart';

class TickerCameraScanPage extends StatefulWidget {
  const TickerCameraScanPage({super.key});

  @override
  State<TickerCameraScanPage> createState() => _TickerCameraScanPageState();
}

class _TickerCameraScanPageState extends State<TickerCameraScanPage> {
  bool _isResultRouteActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TicketScanProvider>().initCamera();
      }
    });
  }

  Future<void> _navigateToResultPage(TicketScanProvider scanProvider) async {
    if (!mounted) return;
    setState(() => _isResultRouteActive = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: scanProvider,
          child: const TicketScanResultPage(),
        ),
      ),
    );
    if (mounted) {
      setState(() => _isResultRouteActive = false);
    }
  }

  Future<void> _pickGalleryAndNavigate(
    BuildContext context,
    TicketScanProvider scanProvider,
  ) async {
    final success = await scanProvider.pickGalleryAndScan();
    if (!mounted || !success) return;
    await _navigateToResultPage(scanProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<TicketScanProvider>();
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;

    if (!scanProvider.isCameraInitialized ||
        scanProvider.cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scanProvider.errorMessage != null) ...[
                  const Icon(
                    Icons.error_outline,
                    color: Colors.amber,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scanProvider.errorMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text(
                      '갤러리에서 티켓 선택',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: scanProvider.isProcessing
                        ? null
                        : () => _pickGalleryAndNavigate(context, scanProvider),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        context.read<TicketScanProvider>().initCamera(),
                    child: const Text(
                      '카메라 다시 시도',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ] else ...[
                  CircularProgressIndicator(color: teamColor),
                  const SizedBox(height: 16),
                  const Text(
                    '카메라를 준비하고 있습니다...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 실시간 카메라 화면 (결과 페이지가 열려 있는 동안에는 프리뷰 위젯을 잠시 언마운트하여 키보드 렌더링 충돌 방지)
          if (!_isResultRouteActive)
            Center(child: CameraPreview(scanProvider.cameraController!)),

          // 가이드라인 오버레이
          CustomPaint(
            painter: TicketGuideOverlayPainter(
              guideColor: Colors.white,
              overlayColor: Colors.black.withOpacity(0.55),
              strokeWidth: 3.5,
              cornerRadius: 16.0,
              cornerLength: 32.0,
            ),
          ),

          // 상단 헤더
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      '티켓 스캔',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => scanProvider.toggleFlash(),
                      icon: Icon(
                        scanProvider.isFlashOn
                            ? Icons.flash_on
                            : Icons.flash_off,
                        color: scanProvider.isFlashOn
                            ? Colors.amber
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '글자가 잘 보이도록 가이드라인 안에 맞춰주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // 하단 셔터 및 갤러리 컨트롤 바
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 32, right: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    GestureDetector(
                      onTap: scanProvider.isProcessing
                          ? null
                          : () async {
                              final success = await scanProvider
                                  .takePictureAndScan();
                              if (!mounted || !success) return;
                              await _navigateToResultPage(scanProvider);
                            },
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: scanProvider.isProcessing
                          ? null
                          : () =>
                              _pickGalleryAndNavigate(context, scanProvider),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 스캔 중 로딩 인디케이터
          if (scanProvider.isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    CircularProgressIndicator(color: teamColor),
                    const SizedBox(height: 20),
                    Text(
                      scanProvider.statusMessage.isNotEmpty
                          ? scanProvider.statusMessage
                          : '티켓 정보를 분석하고 있습니다...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TicketGuideOverlayPainter extends CustomPainter {
  final Color guideColor;
  final Color overlayColor;
  final double strokeWidth;
  final double cornerRadius;
  final double cornerLength;
  TicketGuideOverlayPainter({
    required this.guideColor,
    required this.overlayColor,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.cornerLength,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final boxWidth = size.width * 0.86;
    final boxHeight = boxWidth / 1.55;
    final left = (size.width - boxWidth) / 2;
    final top = (size.height - boxHeight) / 2.3;
    final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(rrect);
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(overlayPath, Paint()..color = overlayColor);
    final cornerPaint = Paint()
      ..color = guideColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(left, top + cornerLength);
    path.lineTo(left, top + cornerRadius);
    path.arcToPoint(
      Offset(left + cornerRadius, top),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(left + cornerLength, top);
    path.moveTo(left + boxWidth - cornerLength, top);
    path.lineTo(left + boxWidth - cornerRadius, top);
    path.arcToPoint(
      Offset(left + boxWidth, top + cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(left + boxWidth, top + cornerLength);
    path.moveTo(left + boxWidth, top + boxHeight - cornerLength);
    path.lineTo(left + boxWidth, top + boxHeight - cornerRadius);
    path.arcToPoint(
      Offset(left + boxWidth - cornerRadius, top + boxHeight),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(left + boxWidth, top + boxHeight - cornerLength);
    path.moveTo(left + cornerLength, top + boxHeight);
    path.lineTo(left + cornerRadius, top + boxHeight);
    path.arcToPoint(
      Offset(left, top + boxHeight - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    path.lineTo(left, top + boxHeight - cornerLength);
    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
