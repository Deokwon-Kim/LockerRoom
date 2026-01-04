import 'dart:io';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/bottom_tab_bar/quiz_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/main.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/widgets/quiz_ranking_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class QuizResultPage extends StatefulWidget {
  final QuizResultModel result;
  const QuizResultPage({super.key, required this.result});

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _animationController.forward();

    _confettiController = ConfettiController(duration: Duration(seconds: 3));

    if (widget.result.score >= 80) {
      Future.delayed(Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }

    // 뱃지 획득 체크
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final badgeProvider = context.read<BadgeProvider>();
      final newBadges = await badgeProvider.checkQuizBadges(widget.result);

      if (newBadges.isNotEmpty) {
        for (int i = 0; i < newBadges.length; i++) {
          Future.delayed(Duration(milliseconds: 400 * 1), () {
            if (mounted) {
              _showBadgeUnlockToast('🏆 [${newBadges[i]}] 뱃지를 획득했습니다!');
            }
          });
          // 뱃지 획득 팝업 띄우기
        }
      }
    });
  }

  // 뱃지 획득 축하 다이얼로그
  void _showBadgeUnlockToast(String message) {
    toastification.show(
      context: context,
      alignment: Alignment.topCenter,
      autoCloseDuration: Duration(seconds: 4),
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: Text(message, style: TextStyle(fontWeight: FontWeight.bold)),
      icon: Icon(Icons.military_tech, color: Colors.white),
      showProgressBar: false,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Column(
              children: [
                AppBar(
                  backgroundColor: BACKGROUND_COLOR,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  title: Text(
                    '퀴즈 결과',
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Screenshot 위젯은 공유할 영역만 감싸기
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: BACKGROUND_COLOR,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: _buildScoreCard(),
                        ),
                        SizedBox(height: 24),
                        _buildStatsCard(),
                        SizedBox(height: 24),
                        const QuizRankingWidget(),
                        SizedBox(height: 24),
                        _buildProgressCard(),
                        if (_isCapturing) _buildBranding(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                if (!_isCapturing) _buildButtons(),
              ],
            ),
          ),
          if (!_isCapturing)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradeGradient(widget.result.score),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.result.grade,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
              color: WHITE,
              shadows: [
                Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.3)),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${widget.result.score}점',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
              color: WHITE,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _getScoreMessage(widget.result.score),
            style: TextStyle(fontSize: 18, color: WHITE, fontFamily: 'kbo'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildStatRow('카테고리', widget.result.category, Icons.category),
          Divider(height: 24),
          _buildStatRow(
            '정답',
            '${widget.result.correctAnswers}/${widget.result.totalQuestions}',
            Icons.check_circle,
            GREEN_SUCCESS_TEXT_50,
          ),
          Divider(height: 24),
          _buildStatRow(
            '오답',
            '${widget.result.totalQuestions - widget.result.correctAnswers}/${widget.result.totalQuestions}',
            Icons.cancel,
            RED_DANGER_TEXT_50,
          ),
          Divider(height: 24),
          _buildStatRow('소요 시간', widget.result.formattedTime, Icons.timer),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정답률',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
            ),
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: widget.result.score / 100,
              minHeight: 16,
              backgroundColor: GRAYSCALE_LABEL_200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(widget.result.score),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${widget.result.score}%',
            style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_600),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/applogo/app_logo.png', height: 150),
        Text(
          '더베이스 야구 퀴즈',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'kbo',
            color: GRAYSCALE_LABEL_600,
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildButtons() {
    final selectedTeamColor = context.watch<TeamProvider>().selectedTeam?.color;
    return Column(
      children: [
        GestureDetector(
          onTap: _showShareBottomSheet,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selectedTeamColor!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, color: selectedTeamColor),
                SizedBox(width: 10),
                Text(
                  '공유하기',
                  style: TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 16,
                    color: selectedTeamColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => QuizTabBar()),
                    (route) => false,
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selectedTeamColor),
                  ),
                  child: Text(
                    '홈으로',
                    style: TextStyle(
                      fontFamily: 'kbo',
                      fontSize: 16,
                      color: selectedTeamColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          QuizPlayPage(category: widget.result.category),
                    ),
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: selectedTeamColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '다시하기',
                    style: TextStyle(
                      color: WHITE,
                      fontSize: 16,
                      fontFamily: 'kbo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon, [
    Color? iconColor,
  ]) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? GRAYSCALE_LABEL_600, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 15, color: GRAYSCALE_LABEL_700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
      ],
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
      final tempFile = File('${tempDir.path}/quiz_result_temp.png');
      await tempFile.writeAsBytes(image);

      uploadProvider.setImages([tempFile]);
      uploadProvider.setInitialCaption(
        '더베이스 ${widget.result.category} 퀴즈 ${widget.result.score}점 달성! 🎉\n\n#야구퀴즈 #야빠 #더베이스 #${widget.result.category}',
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

    await Share.shareXFiles(
      [XFile(imagePath)],
      text:
          '더베이스 ${widget.result.category} 퀴즈 ${widget.result.score}점 달성! 🎉\n\n#야구퀴즈 #야빠 #더베이스 #${widget.result.category}',
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

  List<Color> _getGradeGradient(int score) {
    if (score >= 90) return [Color(0xffffd700), Color(0xffffa500)];
    if (score >= 80) return [Color(0xff4a90e2), Color(0xff357abd)];
    if (score >= 60) return [Color(0xffffa500), Color(0xffff8c00)];
    return [Color(0xffe73c3c), Color(0xffc0392b)];
  }

  String _getScoreMessage(int score) {
    if (score >= 90) return '완벽해요! 야구 박사네요! 🏆';
    if (score >= 80) return '대단해요! 진정한 야빠! ⚾';
    if (score >= 70) return '잘했어요! 야구 지식이 풍부해요!';
    if (score >= 60) return '괜찮아요! 조금만 더 공부하면 완벽!';
    return '다시 도전해보세요! 화이팅! 💪';
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Color(0xFFFFD700);
    if (score >= 80) return BLUE_SECONDARY_600;
    if (score >= 70) return GREEN_SUCCESS_TEXT_50;
    if (score >= 60) return ORANGE_PRIMARY_500;
    return RED_DANGER_TEXT_50;
  }
}

class ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ShareOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'kbo',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: GRAYSCALE_LABEL_400),
          ],
        ),
      ),
    );
  }
}
