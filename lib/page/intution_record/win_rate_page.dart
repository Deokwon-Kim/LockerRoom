import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/main.dart';
import 'package:lockerroom/page/quiz/quiz_result_page.dart';
import 'package:lockerroom/provider/intution_record_list_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class WinRatePage extends StatefulWidget {
  const WinRatePage({super.key});

  @override
  State<WinRatePage> createState() => _WinRatePageState();
}

class _WinRatePageState extends State<WinRatePage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userNickName =
        userProvider.nickname ?? userProvider.currentUser?.displayName ?? '사용자';
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        title: Row(
          children: [
            Text(
              '승률',
              style: TextStyle(
                fontSize: 24,
                color: BLACK,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 12),
            Consumer<IntutionRecordListProvider>(
              builder: (context, lp, child) {
                return GestureDetector(
                  onTap: () => _showYearPicker(context, lp),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: WHITE,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GRAYSCALE_LABEL_300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lp.selectedYear == null ? '전체' : '${lp.selectedYear}',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 18,
                            color: GRAYSCALE_LABEL_600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Consumer2<IntutionRecordListProvider, TeamProvider>(
        builder: (context, lp, tp, child) {
          if (lp.isLoading) {
            final selectedColor = tp.selectedTeam?.color ?? BUTTON;
            return Center(
              child: CircularProgressIndicator(color: selectedColor),
            );
          }
          final items = lp.records;
          final teamColor = tp.selectedTeam?.color ?? BUTTON;

          // 승리한 경기 수 계산
          int wins = 0;
          int losses = 0;
          int draws = 0;
          int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

          for (final item in items) {
            final int? my = _parseScore(item['myScore']);
            final int? opp = _parseScore(item['opponentScore']);
            if (my != null && opp != null) {
              if (my > opp) {
                wins++;
              } else if (my < opp) {
                losses++;
              } else {
                draws++;
              }
            }
          }

          // 승률 계산
          final int totalGames = items.length;
          final double winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Hero Section (Win Rate & Logo)
                  Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      width: double.infinity,
                      height: 320,
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: WHITE,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: BLACK.withOpacity(0.05),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Logo (Watermark)
                          if (tp.selectedTeam != null)
                            Opacity(
                              opacity: 0.1,
                              child: Transform.scale(
                                scale: 1.5,
                                child: Image.asset(
                                  tp.selectedTeam!.logoPath,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '승률',
                                style: TextStyle(
                                  color: GRAYSCALE_LABEL_500,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    winRate.toStringAsFixed(0),
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 140,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                      color: teamColor,
                                      shadows: [
                                        Shadow(
                                          color: teamColor.withOpacity(0.3),
                                          offset: Offset(0, 10),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Text(
                                      '%',
                                      style: GoogleFonts.blackHanSans(
                                        fontSize: 40,
                                        color: teamColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: _isCapturing
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.only(left: 25.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      userNickName,
                                      style: TextStyle(
                                        color: teamColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (!_isCapturing)
                                      IconButton(
                                        onPressed: () {
                                          _showShareBottomSheet();
                                        },
                                        icon: Icon(
                                          CupertinoIcons.share,
                                          size: 15,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // 2. Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: '경기 수',
                          value: '$totalGames',
                          color: BLACK,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          label: '승',
                          value: '$wins',
                          color: BUTTON,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: '무',
                          value: '$draws',
                          color: GRAYSCALE_LABEL_600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          label: '패',
                          value: '$losses',
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BLACK.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: GRAYSCALE_LABEL_500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 42,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              '공유하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
              ),
            ),
            SizedBox(height: 24),
            ShareOption(
              icon: Icons.download,
              iconColor: GREEN_SUCCESS_TEXT_50,
              title: '이미지로 저장',
              subtitle: '갤러리에 저장',
              onTap: () {
                Navigator.pop(context);
                _saveToGallery();
              },
            ),
            ShareOption(
              icon: Icons.post_add,
              iconColor: BUTTON,
              title: '게시물로 공유',
              subtitle: 'Feed에 올리기',
              onTap: () {
                Navigator.pop(context);
                _shareToFeed();
              },
            ),
            ShareOption(
              icon: Icons.share,
              iconColor: ORANGE_PRIMARY_500,
              title: '다른 앱으로 공유',
              subtitle: 'Instagram, Threads, 카톡 등',
              onTap: () {
                Navigator.pop(context);
                _shareToOtherApps();
              },
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(fontSize: 16, color: GRAYSCALE_LABEL_600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    try {
      // 임시 파일로 저장 후 갤러리에 저장
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(image);

      await Gal.putImage(tempFile.path);
      _showToast('갤러리에 저장되었습니다');

      // 임시 파일 삭제
      await tempFile.delete();
    } catch (e) {
      _showToast('저장 실패');
    }
  }

  // Feed에 공유
  Future<void> _shareToFeed() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    // UploadProvider에 이미지와 캡션 설정
    if (mounted) {
      final uploadProvider = context.read<UploadProvider>();

      // 저장된 이미지 파일 경로 찾기 (ImageGallerySaver는 경로를 직접 반환하지 않을 수 있어서 임시 파일 사용)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/winrate_temp.png');
      await tempFile.writeAsBytes(image);

      final irp = context.read<IntutionRecordListProvider>();
      final records = irp.records;
      int wins = 0;
      int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

      for (final item in records) {
        final int? my = _parseScore(item['myScore']);
        final int? opp = _parseScore(item['opponentScore']);
        if (my != null && opp != null) {
          if (my > opp) {
            wins++;
          }
        }
      }

      final totalGames = records.length;
      final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

      uploadProvider.setImages([tempFile]);
      uploadProvider.setInitialCaption(
        '더베이스 직관 승률 ${winRate.toStringAsFixed(0)}% 달성! 🎉\n\n#직관승률 #승요 #더베이스 #직관러',
      );

      // AuthWrapper를 통해 이동하여 사용자 정보 로드 및 초기화 보장
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AuthWrapper(initialIndex: 2)),
        (route) => false, // 모든 이전 라우트 제거
      );
    }

    _showToast('이미지가 선택되었습니다');
  }

  Future<void> _shareToOtherApps() async {
    setState(() => _isCapturing = true);
    await Future.delayed(Duration(milliseconds: 100));

    final Uint8List? image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image == null) {
      _showToast('이미지 생성 실패');
      return;
    }

    final directory = await getTemporaryDirectory();
    final imagePath =
        '${directory.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(image);

    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    // winRate 계산
    final irp = context.read<IntutionRecordListProvider>();
    final records = irp.records;
    int wins = 0;
    int? _parseScore(dynamic v) => v is int ? v : int.tryParse('$v');

    for (final item in records) {
      final int? my = _parseScore(item['myScore']);
      final int? opp = _parseScore(item['opponentScore']);
      if (my != null && opp != null) {
        if (my > opp) {
          wins++;
        }
      }
    }

    final totalGames = records.length;
    final winRate = totalGames > 0 ? (wins / totalGames) * 100 : 0.0;

    await Share.shareXFiles(
      [XFile(imagePath)],
      text:
          '더베이스 직관 승률 ${winRate.toStringAsFixed(0)}% 달성! 🎉\n\n#직관승률 #승요 #더베이스 #직관러',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  void _showToast(String message) {
    toastification.show(
      context: context,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: Duration(seconds: 2),
      type: ToastificationType.success,
      title: Text(message),
    );
  }

  void _showYearPicker(BuildContext context, IntutionRecordListProvider irp) {
    final years = irp.availableYears;

    if (years.isEmpty) {
      years.add(DateTime.now().year);
    }

    // 전체선택 옵션
    final allYears = [null, ...years];

    int selectedIndex = allYears.indexOf(irp.selectedYear);
    if (selectedIndex == -1) selectedIndex = 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              // 상단 버튼
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: CupertinoColors.systemBackground.resolveFrom(
                    context,
                  ),
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  onSelectedItemChanged: (int index) {
                    irp.setYear(allYears[index]);
                  },
                  children: allYears.map((year) {
                    return Center(
                      child: Text(
                        year == null ? '전체' : '$year년',
                        style: TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
