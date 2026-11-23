import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/bottom_tab_bar/bottom_tab_bar.dart';
import 'package:lockerroom/page/team_select_page.dart';

class TermsGatePage extends StatefulWidget {
  const TermsGatePage({super.key});

  @override
  State<TermsGatePage> createState() => _TermsGatePageState();
}

class _TermsGatePageState extends State<TermsGatePage> {
  bool agreeTerms = false;
  bool agreePolicy = false;
  bool agreeNoTolerance = false;
  bool _isSubmitting = false;

  bool get _allChecked => agreeTerms && agreePolicy && agreeNoTolerance;

  Future<void> _saveAgreements() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'agreedTermsAt': FieldValue.serverTimestamp(),
      'agreedPolicyAt': FieldValue.serverTimestamp(),
      'agreedNoToleranceAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _onSubmit() async {
    if (!_allChecked || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _saveAgreements();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (!mounted || uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final team = doc.data()?['team'] as String?;
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => (team != null && team.isNotEmpty)
              ? const BottomTabBar()
              : const TeamSelectPage(),
        ),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('signIn', (route) => false);
      },
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            '약관 동의',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: GRAYSCALE_LABEL_950,
            ),
          ),
          backgroundColor: BACKGROUND_COLOR,
          foregroundColor: GRAYSCALE_LABEL_950,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ILU 가입을 환영합니다!',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      color: GRAYSCALE_LABEL_950,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '약관에 동의하고\n팬들의 그라운드로 입장하세요 ⚾️',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                      color: GRAYSCALE_LABEL_700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Image.asset(
                              'assets/images/applogo/ilu_app_icon.png',
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // 전체 동의 카드
                        Container(
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _allChecked
                                  ? BUTTON
                                  : GRAYSCALE_LABEL_200,
                              width: _allChecked ? 1.5 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                final next = !_allChecked;
                                setState(() {
                                  agreeTerms = next;
                                  agreePolicy = next;
                                  agreeNoTolerance = next;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    _RoundCheckIcon(checked: _allChecked),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        '약관 전체 동의',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: GRAYSCALE_LABEL_950,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // 개별 약관 카드
                        Container(
                          decoration: BoxDecoration(
                            color: WHITE,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                          child: Column(
                            children: [
                              _buildCheckItem(
                                value: agreeTerms,
                                onToggle: () => setState(
                                  () => agreeTerms = !agreeTerms,
                                ),
                                title: '이용약관 동의',
                                isRequired: true,
                                route: 'terms',
                              ),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: GRAYSCALE_LABEL_100,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _buildCheckItem(
                                value: agreePolicy,
                                onToggle: () => setState(
                                  () => agreePolicy = !agreePolicy,
                                ),
                                title: '개인정보 처리방침 동의',
                                isRequired: true,
                                route: 'policy',
                              ),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: GRAYSCALE_LABEL_100,
                                indent: 16,
                                endIndent: 16,
                              ),
                              _buildCheckItem(
                                value: agreeNoTolerance,
                                onToggle: () => setState(
                                  () => agreeNoTolerance = !agreeNoTolerance,
                                ),
                                title: '무관용 정책 동의 (음란물·혐오·학대 금지)',
                                isRequired: true,
                                subtitle:
                                    '채팅, 모임, 게시물 내 불법/유해 콘텐츠와 학대·혐오 표출, 괴롭힘, 스팸·사기, 저작권 침해에 무관용 정책을 적용합니다. 위반 시 이용 제한, 게시물 삭제, 계정 정지 또는 영구 차단될 수 있습니다.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (_allChecked && !_isSubmitting)
                          ? BUTTON
                          : GRAYSCALE_LABEL_300,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: (_allChecked && !_isSubmitting)
                          ? [
                              BoxShadow(
                                color: BUTTON.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_allChecked && !_isSubmitting)
                            ? _onSubmit
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: Center(
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: WHITE,
                                    ),
                                  )
                                : const Text(
                                    '동의하고 계속',
                                    style: TextStyle(
                                      color: WHITE,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required bool value,
    required VoidCallback onToggle,
    required String title,
    bool isRequired = false,
    String? route,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoundCheckIcon(checked: value),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (isRequired)
                          const TextSpan(
                            text: '[필수] ',
                            style: TextStyle(
                              color: BUTTON,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        TextSpan(
                          text: title,
                          style: const TextStyle(
                            color: GRAYSCALE_LABEL_900,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (route != null)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, route),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '보기',
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_600,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GRAYSCALE_LABEL_50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: GRAYSCALE_LABEL_600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundCheckIcon extends StatelessWidget {
  final bool checked;
  const _RoundCheckIcon({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? BUTTON : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? BUTTON : GRAYSCALE_LABEL_300,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 15, color: WHITE)
          : null,
    );
  }
}
