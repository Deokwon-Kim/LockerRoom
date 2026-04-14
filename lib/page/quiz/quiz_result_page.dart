import 'dart:io';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lockerroom/bottom_tab_bar/quiz_tab_bar.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/quiz_result_model.dart';
import 'package:lockerroom/page/quiz/quiz_play_page.dart';
import 'package:lockerroom/main.dart';
import 'package:lockerroom/provider/badge_provider.dart';
import 'package:lockerroom/provider/quiz_ranking_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/upload_provider.dart';
import 'package:lockerroom/utils/quiz_season_utils.dart';
import 'package:lockerroom/widgets/quiz_ranking_widget.dart';
import 'package:lockerroom/widgets/team_battle_dialog.dart';
import 'package:lockerroom/widgets/tier_up_overlay.dart';
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
  // _scaleAnimation 제거 (이미 사용되지 않음)
  late ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  // 애니메이션용 상태
  int _animatingScore = 0;
  String _scorePhaseLabel = "";
  bool _showFinalGrade = false;
  double _scoreScale = 1.0;
  bool _isImpactActive = false;

  // 티어 관련 상태
  String _oldTier = "";
  String _newTier = "";
  bool _showTierUpOverlay = false;
  final bool _debugForceTierUp = false; // 티어 상승 디버깅 (필요 시 true로)

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await FirebaseAnalytics.instance.logEvent(
        name: 'quiz_complete',
        parameters: {'score': widget.result.score},
      );
    });

    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _animationController.forward();

    _confettiController = ConfettiController(duration: Duration(seconds: 3));

    if (widget.result.grade == 'S' || widget.result.grade == 'A') {
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
        }
      }

      // 점수 애니메이션 시작
      _startScoreAnimation();

      // 티어 상승 여부 체크를 위한 데이터 준비
      final rankProvider = context.read<QuizRankingProvider>();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        final myRanking = rankProvider.getMyRanking(currentUserId);
        
        // [PATCH] 0점 혹은 기록이 없는 유저(null)를 위한 기본값 처리
        // 먹산곰님 제보: PROSPECT -> MINOR 승급시에만 안뜨는 문제 해결 (null 체크 우회)
        int providerScore = myRanking?.score ?? 0;
        int preQuizScore;
        int postQuizScore;

        // 1. 이미 Provider가 이번 퀴즈 결과를 반영했을 경우 (유추)
        // 200점(MINOR) 경계값에 걸쳐있을 때 신뢰도를 높이기 위해
        // Provider 점수가 0이 아닌데 현재 퀴즈 점수와 같다면, 이미 반영된 것으로 간주
        if (providerScore > 0 && providerScore >= widget.result.score) {
          preQuizScore = providerScore - widget.result.score;
          postQuizScore = providerScore;
        } else {
          // 아직 반영 전이라면
          preQuizScore = providerScore;
          postQuizScore = providerScore + widget.result.score;
        }

        // 0 미만 방지
        if (preQuizScore < 0) preQuizScore = 0;

        _oldTier = QuizSeasonUtils.getTier(preQuizScore);
        _newTier = QuizSeasonUtils.getTier(postQuizScore);
        
        print('--- 티어 승급 체크 (개선됨) ---');
        print('이전 점수: $preQuizScore, 현재 예상 점수: $postQuizScore');
        print('이전 티어: $_oldTier, 현재 티어: $_newTier');
      }
    });
  }

  // 점수 애니메이션 시퀀스 (보너스 개별 노출 -> 최종 합계)
  Future<void> _startScoreAnimation() async {
    await Future.delayed(Duration(milliseconds: 800));

    // 1. 기본 점수 팡!
    if (!mounted) return;
    setState(() {
      _isImpactActive = true;
      _scoreScale = 1.4;
      _animatingScore = widget.result.baseScore;
      _scorePhaseLabel = "기본 점수";
    });
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      _isImpactActive = false;
      _scoreScale = 1.0;
    });

    // 2. 난이도 보너스 팡!
    if (widget.result.difficultyBonus > 0) {
      await Future.delayed(Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() {
        _animatingScore = 0; // 초기화 후 다시 카운트업
      });
      await Future.delayed(Duration(milliseconds: 100));
      setState(() {
        _isImpactActive = true;
        _scoreScale = 1.4;
        _animatingScore = widget.result.difficultyBonus;
        _scorePhaseLabel = "난이도 보너스";
      });
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _isImpactActive = false;
        _scoreScale = 1.0;
      });
    }

    // 3. 콤보 보너스 팡!
    if (widget.result.comboBonus > 0) {
      await Future.delayed(Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() {
        _animatingScore = 0;
      });
      await Future.delayed(Duration(milliseconds: 100));
      setState(() {
        _isImpactActive = true;
        _scoreScale = 1.4;
        _animatingScore = widget.result.comboBonus;
        _scorePhaseLabel = "콤보 보너스";
      });
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _isImpactActive = false;
        _scoreScale = 1.0;
      });
    }

    // 4. 스피드 보너스 팡!
    if (widget.result.speedBonus > 0) {
      await Future.delayed(Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() {
        _animatingScore = 0;
      });
      await Future.delayed(Duration(milliseconds: 100));
      setState(() {
        _isImpactActive = true;
        _scoreScale = 1.4;
        _animatingScore = widget.result.speedBonus;
        _scorePhaseLabel = "스피드 보너스";
      });
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _isImpactActive = false;
        _scoreScale = 1.0;
      });
    }

    // 5. 최종 결과 확정 (페이드로 최종 점수 등장)
    await Future.delayed(Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _animatingScore = widget.result.score; // 최종 합계
      _scorePhaseLabel = "최종 점수";
      _showFinalGrade = true;
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
    final team = context.watch<TeamProvider>().selectedTeam;
    final teamColor = team?.color ?? BLUE_SECONDARY_600;

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      body: Stack(
        children: [
          // 1. 다이나믹 팀 그라데이션 배경
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  teamColor.withOpacity(0.15),
                  BACKGROUND_COLOR,
                  BACKGROUND_COLOR,
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // 2. 메인 컨텐츠
          SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 40),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 10),

                // 상단 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: GRAYSCALE_LABEL_700),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      '퀴즈 리포트',
                      style: TextStyle(
                        fontFamily: 'kbo',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: GRAYSCALE_LABEL_900,
                      ),
                    ),
                    SizedBox(width: 48), // 밸런스용
                  ],
                ),

                SizedBox(height: 10),

                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Colors.transparent, // 스크린샷 시 배경 포함을 위해 처리 필요
                    child: Column(
                      children: [
                        // 최종 점수 히어로 (애니메이션 후 등장)
                        AnimatedOpacity(
                          opacity: _showFinalGrade ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 800),
                          child: _buildScoreHero(),
                        ),

                        SizedBox(height: 24),

                        // 마스코트 피드백 & 랭킹 위젯 (애니메이션 중에는 숨김)
                        AnimatedOpacity(
                          opacity: (_isImpactActive || !_showFinalGrade)
                              ? 0.0
                              : 1.0,
                          duration: Duration(milliseconds: 400),
                          child: Column(
                            children: [
                              // _buildMascotFeedback(team),
                              // SizedBox(height: 24),
                              _buildPerformanceReport(),
                              SizedBox(height: 24),
                              QuizRankingWidget(
                                gainedScore: _showFinalGrade
                                    ? widget.result.score
                                    : null,
                                onRankAnimationComplete: () {
                                  // 랭킹 애니메이션 및 다이얼로그 종료 후 티어 상승 연출 노출
                                  if (_debugForceTierUp) {
                                    setState(() {
                                      if (_newTier.isEmpty) {
                                        _oldTier = "MINOR";
                                        _newTier = "MAJOR";
                                      }
                                      _showTierUpOverlay = true;
                                    });
                                    return;
                                  }

                                  // 최종 승급 여부 판단 (initState에서 계산된 값 또는 실시간 데이터 재검증)
                                  final latestRankProvider = context.read<QuizRankingProvider>();
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  
                                  bool isPromotion = false;
                                  if (_oldTier != _newTier && _oldTier.isNotEmpty && _newTier.isNotEmpty) {
                                    // 1. initState 시점에 이미 승급이 감지된 경우
                                    isPromotion = true;
                                  } else if (uid != null) {
                                    // 2. 혹시나 timing 이슈로 initState에서 놓쳤을 경우 실시간 데이터로 재검증
                                    final currentRanking = latestRankProvider.getMyRanking(uid);
                                    if (currentRanking != null) {
                                      final latestTier = QuizSeasonUtils.getTier(currentRanking.score);
                                      // 위젯 뱃지가 MINOR라면 latestTier는 MINOR일 것.
                                      // 만약 initState 시점의 _oldTier가 PROSPECT였다면 이 시점에서라도 승급 감지 가능.
                                      if (_oldTier.isNotEmpty && latestTier != _oldTier) {
                                        _newTier = latestTier;
                                        isPromotion = true;
                                      }
                                    }
                                  }

                                  if (isPromotion) {
                                    setState(() {
                                      _showTierUpOverlay = true;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 32),

                // 하단 액션 버튼
                if (!_isCapturing)
                  AnimatedOpacity(
                    opacity: (_isImpactActive || !_showFinalGrade) ? 0.0 : 1.0,
                    duration: Duration(milliseconds: 400),
                    child: _buildActionButtons(teamColor),
                  ),
              ],
            ),
          ),

          // 3. 전체 페이지 암전 오버레이 (보너스 연출 시)
          IgnorePointer(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 400),
              color: _isImpactActive
                  ? Colors.black.withOpacity(0.92)
                  : Colors.transparent,
            ),
          ),

          // 4. 중앙 보너스 임팩트 연출
          if (_isImpactActive)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _scorePhaseLabel,
                    style: TextStyle(
                      fontSize: 22,
                      color: WHITE.withOpacity(0.7),
                      fontFamily: 'kbo',
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 20),
                  AnimatedScale(
                    scale: _scoreScale,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_scorePhaseLabel),
                      tween: Tween<double>(
                        begin: 0,
                        end: _animatingScore.toDouble(),
                      ),
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [WHITE, Color(0xffffd700), WHITE],
                          ).createShader(bounds),
                          child: Text(
                            '+${value.round()}',
                            style: TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'kbo',
                              color: WHITE,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 폭죽 효과
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
                colors: [teamColor, Colors.blue, Colors.orange, Colors.white],
              ),
            ),

          // 5. 티어 상승 풀페이지 오버레이
          if (_showTierUpOverlay)
            TierUpOverlay(
              oldTier: _oldTier,
              newTier: _newTier,
              onDismiss: () {
                setState(() {
                  _showTierUpOverlay = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScoreHero() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradeGradient(widget.result.grade),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _getScoreColor(widget.result.grade).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.result.grade,
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
              color: WHITE,
              shadows: [
                Shadow(
                  blurRadius: 20,
                  color: Colors.black.withOpacity(0.2),
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),

          Text(
            '${widget.result.score}점',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'kbo',
              color: WHITE.withOpacity(0.95),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: WHITE.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getScoreMessage(widget.result.grade),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: WHITE,
                fontFamily: 'kbo',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildMascotFeedback(dynamic team) {
  //   // 뱃지 이미지나 마스코트가 있다면 사용 (없으면 기본 아이콘)
  //   final mascotImage = team?.symplename == '한화'
  //       ? 'assets/images/applogo/hanwha_mascot.png' // 예시 경로
  //       : null;

  //   return Container(
  //     width: double.infinity,
  //     padding: EdgeInsets.all(16),
  //     child: Row(
  //       children: [
  //         // 마스코트 영역 (실제 이미지가 있다면 좋음)
  //         Container(
  //           width: 80,
  //           height: 80,
  //           decoration: BoxDecoration(
  //             color: WHITE,
  //             shape: BoxShape.circle,
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black12,
  //                 blurRadius: 10,
  //                 offset: Offset(0, 4),
  //               ),
  //             ],
  //           ),
  //           child: Center(
  //             child: Icon(
  //               Icons.sports_baseball,
  //               size: 40,
  //               color: team?.color ?? BLUE_SECONDARY_600,
  //             ),
  //           ),
  //         ),
  //         SizedBox(width: 16),
  //         // 말풍선
  //         Expanded(
  //           child: Container(
  //             padding: EdgeInsets.all(16),
  //             decoration: BoxDecoration(
  //               color: WHITE,
  //               borderRadius: BorderRadius.only(
  //                 topRight: Radius.circular(16),
  //                 bottomLeft: Radius.circular(16),
  //                 bottomRight: Radius.circular(16),
  //               ),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black12,
  //                   blurRadius: 5,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Text(
  //               '${widget.result.userNickName}님! ${widget.result.score}점이라니 정말 대단해요! ${team?.symplename ?? ''} 팬들의 자랑입니다! 🔥',
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 height: 1.5,
  //                 color: GRAYSCALE_LABEL_800,
  //                 fontWeight: FontWeight.w500,
  //               ),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPerformanceReport() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: GRAYSCALE_LABEL_900),
              SizedBox(width: 8),
              Text(
                '퍼포먼스 리포트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'kbo',
                  color: GRAYSCALE_LABEL_900,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // 핵심 스탯 그리드
          Row(
            children: [
              _buildLargeStatItem(
                '정답률',
                '${((widget.result.correctAnswers / widget.result.totalQuestions) * 100).toInt()}%',
                Icons.check_circle_outline,
                Colors.green,
              ),
              SizedBox(width: 12),
              _buildLargeStatItem(
                '소요 시간',
                widget.result.formattedTime,
                Icons.timer_outlined,
                Colors.blue,
              ),
            ],
          ),

          SizedBox(height: 24),
          Divider(color: GRAYSCALE_LABEL_200),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '점수 상세 내역',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: GRAYSCALE_LABEL_600,
                ),
              ),
              // 600번 라인 부근의 Tooltip 부분을 아래와 같이 보강합니다.
              Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                showDuration: Duration(seconds: 4), // 4초 동안 보여줌
                waitDuration: Duration.zero,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.symmetric(horizontal: 24),
                richMessage: TextSpan(
                  text: '점수 산정 기준 안내\n',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '\n[일반 점수]\n',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '• 기본 점수: 정답당 10점\n• 난이도: 어려움(+10) / 중간(+5)\n• 콤보: 3/5/10연속 정답 시 추가 보너스\n',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: '\n[⚡️ 스피드 보너스]\n',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '문제가 화면에 나타난 순간부터 정답을 클릭할 때까지의 시간을 측정합니다.\n',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    TextSpan(
                      text:
                          '• 5초 이내 정답: +10점 (초광속!)\n• 10초 이내 정답: +5점 (나이스 스피드!)\n',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        height: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: '\n[🏅 등급 기준 (정답률)]\n',
                      style: TextStyle(
                        color: Colors.lightBlueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          '• S: 100%  • A: 90%↑  • B: 80%↑\n• C: 70%↑  • D: 70% 미만',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),

                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.info_outline,
                    color: GRAYSCALE_LABEL_600,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          _buildScoreBreakdownRow(
            '기본 점수',
            '${widget.result.baseScore}',
            Colors.black87,
          ),
          if (widget.result.difficultyBonus > 0)
            _buildScoreBreakdownRow(
              '난이도 보너스',
              '+${widget.result.difficultyBonus}',
              BLUE_SECONDARY_600,
            ),
          if (widget.result.comboBonus > 0)
            _buildScoreBreakdownRow(
              '콤보 보너스',
              '+${widget.result.comboBonus}',
              ORANGE_PRIMARY_600,
            ),
          if (widget.result.speedBonus > 0)
            _buildScoreBreakdownRow(
              '스피드 보너스',
              '+${widget.result.speedBonus}',
              GREEN_SECONDARY_700,
            ),

          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GRAYSCALE_LABEL_100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL SCORE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: GRAYSCALE_LABEL_600,
                  ),
                ),
                Text(
                  '${widget.result.score}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: GRAYSCALE_LABEL_900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: GRAYSCALE_LABEL_600),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'kbo',
                color: GRAYSCALE_LABEL_900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBreakdownRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: GRAYSCALE_LABEL_700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color teamColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showShareBottomSheet,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: teamColor.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: teamColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined, color: teamColor),
                SizedBox(width: 8),
                Text(
                  '결과 공유하기',
                  style: TextStyle(
                    fontFamily: 'kbo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: teamColor,
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
              child: _buildSecondaryButton('홈으로', () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => QuizTabBar()),
                  (route) => false,
                );
              }),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildPrimaryButton('다시하기', teamColor, _handleReplay),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: WHITE,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GRAYSCALE_LABEL_100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: GRAYSCALE_LABEL_800,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'kbo',
          ),
        ),
      ),
    );
  }

  // 퀴즈 다시하기 처리 (팀 배틀 조건부 노출)
  void _handleReplay() {
    final rankingProvider = context.read<QuizRankingProvider>();
    final teamProvider = context.read<TeamProvider>();
    final myTeam = teamProvider.selectedTeam;

    if (myTeam != null) {
      try {
        // 내 팀 랭킹 찾기
        final myTeamRanking = rankingProvider.teamRankings.firstWhere(
          (t) => t.teamName == myTeam.name || t.teamName == myTeam.symplename,
        );

        // 바로 위 순위 팀 찾기
        final myIndex = rankingProvider.teamRankings.indexOf(myTeamRanking);
        if (myIndex > 0) {
          final rivalTeamRanking = rankingProvider.teamRankings[myIndex - 1];
          final scoreDiff =
              rivalTeamRanking.totalScore - myTeamRanking.totalScore;

          // 차이가 1점 ~ 100점 사이면 배틀 다이얼로그 표시
          if (scoreDiff >= 1 && scoreDiff <= 100) {
            showDialog(
              context: context,
              builder: (context) => TeamBattleDialog(onStart: _navigateToQuiz),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('Replay team battle check failed: $e');
      }
    }

    _navigateToQuiz();
  }

  void _navigateToQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPlayPage(category: widget.result.category),
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

      await FirebaseAnalytics.instance.logEvent(
        name: 'quiz_share',
        parameters: {'type': 'gallery', 'grade': widget.result.grade},
      );

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

      // 공유 카운트 증가
      context.read<BadgeProvider>().incrementShareCount();

      await FirebaseAnalytics.instance.logEvent(
        name: 'quiz_share',
        parameters: {'type': 'feed', 'grade': widget.result.grade},
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

    // 공유 카운트 증가
    if (mounted) {
      context.read<BadgeProvider>().incrementShareCount();
      await FirebaseAnalytics.instance.logEvent(
        name: 'quiz_share',
        parameters: {'type': 'other', 'grade': widget.result.grade},
      );
    }
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

  List<Color> _getGradeGradient(String grade) {
    switch (grade) {
      case 'S':
        return [Color(0xffffd700), Color(0xffffa500)]; // Gold
      case 'A':
        return [Color(0xff4a90e2), Color(0xff357abd)]; // blue
      case 'B':
        return [Color(0xff2ecc71), Color(0xff27ae60)]; // Green
      case 'C':
        return [Color(0xffffa500), Color(0xffff8c00)]; // Orange
      default:
        return [Color(0xffe73c3c), Color(0xffc0392b)]; // Red
    }
  }

  String _getScoreMessage(String grade) {
    switch (grade) {
      case 'S':
        return '완벽해요! 야구 박사네요! 🏆';
      case 'A':
        return '대단해요! 진정한 야빠! ⚾';
      case 'B':
        return '최고예요! 지식이 상당하시네요!';
      case 'C':
        return '잘했어요! 조금만 더 공부하면 완벽!';
      default:
        return '다시 도전해보세요! 화이팅! 💪';
    }
  }

  Color _getScoreColor(String grade) {
    switch (grade) {
      case 'S':
        return Color(0xFFFFD700);
      case 'A':
        return BLUE_SECONDARY_600;
      case 'B':
        return GREEN_SUCCESS_TEXT_50;
      case 'C':
        return ORANGE_PRIMARY_500;
      default:
        return RED_DANGER_TEXT_50;
    }
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
