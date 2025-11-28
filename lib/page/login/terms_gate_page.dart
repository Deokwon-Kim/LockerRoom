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
  bool agreeAll = false;

  Future<void> _saveAgreements() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'agreedTermsAt': FieldValue.serverTimestamp(),
      'agreedPolicyAt': FieldValue.serverTimestamp(),
      'agreedNoToleranceAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = agreeTerms && agreePolicy && agreeNoTolerance;
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 시 회원가입 화면으로 돌아가지 않고 로그인 화면으로 이동
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('signIn', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            '약관 동의',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: BACKGROUND_COLOR,
          foregroundColor: Colors.black,
          scrolledUnderElevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '더베이스 가입을 환영합니다!\n약관에 동의하고\n팬들의 그라운드로 입장하세요 ⚾️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Image.asset(
                    'assets/images/applogo/app_logo.png',
                    height: 100,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: agreeAll,
                    onChanged: (v) {
                      setState(() {
                        agreeAll = v ?? false;
                        agreeTerms = agreeAll;
                        agreePolicy = agreeAll;
                        agreeNoTolerance = agreeAll;
                      });
                    },
                    activeColor: BUTTON,
                    checkColor: WHITE,
                  ),
                  const Expanded(
                    child: Text(
                      '전체 동의',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildCheck(
                value: agreeTerms,
                onChanged: (v) => setState(() {
                  agreeTerms = v ?? false;
                  agreeAll = agreeTerms && agreePolicy && agreeNoTolerance;
                }),
                title: '이용약관 동의 (필수)',
                route: 'terms',
              ),
              _buildCheck(
                value: agreePolicy,
                onChanged: (v) => setState(() {
                  agreePolicy = v ?? false;
                  agreeAll = agreeTerms && agreePolicy && agreeNoTolerance;
                }),
                title: '개인정보 처리방침 동의 (필수)',
                route: 'policy',
              ),
              _buildCheck(
                value: agreeNoTolerance,
                onChanged: (v) => setState(() {
                  agreeNoTolerance = v ?? false;
                  agreeAll = agreeTerms && agreePolicy && agreeNoTolerance;
                }),
                title: '무관용 정책 동의 (음란물·혐오·학대 등 금지, 필수)',
                route: null,
                subtitle:
                    '불법/유해 콘텐츠와 학대·혐오 표출, 괴롭힘, 스팸·사기, 저작권 침해에 무관용. 위반 시 게시물 삭제·계정 정지 또는 영구 차단.',
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: GestureDetector(
                  onTap: () async {
                    if (!allChecked) return;
                    await _saveAgreements();
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (!mounted || uid == null) return;
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get();
                    final team = doc.data()?['team'] as String?;
                    if (!mounted) return;
                    if (team != null && team.isNotEmpty) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const BottomTabBar()),
                        (route) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const TeamSelectPage(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: Container(
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: allChecked ? BUTTON : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '동의하고 계속',
                      style: TextStyle(
                        color: WHITE,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheck({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    String? route,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              checkColor: WHITE,
              activeColor: BUTTON,
            ),
            Expanded(child: Text(title)),
            if (route != null)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, route),
                child: const Text('보기', style: TextStyle(color: BUTTON)),
              ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 48.0, bottom: 8),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
