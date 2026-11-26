import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/const/color.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

/// 공유 이미지 하단에 들어가는 ILU 앱 전용 워터마크 바
class IluWatermarkFooter extends StatelessWidget {
  final String? subtitle;

  const IluWatermarkFooter({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: BUTTON,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/images/applogo/ilu_playstore_icon_512.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle ?? '1루부터 홈까지 · KBO 직관 커뮤니티',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: WHITE,
              ),
            ),
          ),
          const Text(
            'ILU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// ILU 워터마크가 포함된 위젯을 미리보기 후 갤러리 저장/공유하는 바텀시트
Future<void> showIluWatermarkShareSheet({
  required BuildContext context,
  required Widget shareContent,
  required String shareText,
  String? watermarkSubtitle,
}) async {
  final screenshotController = ScreenshotController();
  bool isBusy = false;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: WHITE,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<String?> captureToFile() async {
            final bytes = await screenshotController.capture(pixelRatio: 2.5);
            if (bytes == null) return null;
            final dir = await getTemporaryDirectory();
            final path =
                '${dir.path}/ilu_share_${DateTime.now().millisecondsSinceEpoch}.png';
            await File(path).writeAsBytes(bytes);
            return path;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GRAYSCALE_LABEL_200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '공유하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: GRAYSCALE_LABEL_950,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Screenshot(
                        controller: screenshotController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              shareContent,
                              IluWatermarkFooter(subtitle: watermarkSubtitle),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    setSheetState(() => isBusy = true);
                                    try {
                                      final path = await captureToFile();
                                      if (path != null) {
                                        await Gal.putImage(path);
                                        if (ctx.mounted) {
                                          toastification.show(
                                            context: ctx,
                                            type: ToastificationType.success,
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                            title: const Text('갤러리에 저장되었습니다'),
                                          );
                                        }
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setSheetState(() => isBusy = false);
                                      }
                                    }
                                  },
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: BUTTON,
                            ),
                            label: const Text(
                              '저장하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: BUTTON,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: GRAYSCALE_LABEL_300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    setSheetState(() => isBusy = true);
                                    try {
                                      final path = await captureToFile();
                                      if (path != null && ctx.mounted) {
                                        final box =
                                            ctx.findRenderObject()
                                                as RenderBox?;
                                        final origin = box != null
                                            ? box.localToGlobal(Offset.zero) &
                                                  box.size
                                            : null;
                                        await Share.shareXFiles(
                                          [XFile(path)],
                                          text: shareText,
                                          sharePositionOrigin: origin,
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setSheetState(() => isBusy = false);
                                      }
                                    }
                                  },
                            icon: const Icon(
                              CupertinoIcons.share,
                              size: 17,
                              color: WHITE,
                            ),
                            label: const Text(
                              '공유하기',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: WHITE,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BUTTON,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
