import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text(
          '개인정보 처리방침',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: Colors.black,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔒 개인정보 처리방침',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '마지막 업데이트: 2026년 2월',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. 개요',
              '더베이스(이하 "회사")는 이용자의 개인정보를 보호하고 개인정보와 관련한 이용자의 고충을 원활하게 처리하기 위하여 다음과 같은 개인정보 처리방침을 수립·공개합니다.',
            ),
            const SizedBox(height: 20),
            _buildSection('2. 수집하는 개인정보의 항목 및 수집 방법', '''회사는 다음과 같은 개인정보를 수집합니다:

• 이메일, 비밀번호(암호화), 닉네임, 이름
• 응원 팀 정보, 프로필 사진, 자기소개
• 게시물(텍스트, 이미지, 영상), 댓글 내용
• 직관모임 채팅 메시지 내용 및 공유 미디어
• 직관모임 개설 및 참여 참여 정보
• 팔로우/팔로워 정보, 좋아요 목록
• FCM 토큰, 기기 정보'''),
            const SizedBox(height: 20),
            _buildSection('3. 개인정보의 이용 목적', '''회사는 수집한 개인정보를 다음의 목적으로만 이용합니다:

• 서비스 제공 및 유지보수
• 사용자 인증 및 서비스 접근 관리
• 푸시 알림, 뉴스레터 등의 공지사항 발송
• 부정 행위 적발 및 예방
• 통계 분석 및 서비스 개선
• 이용자 피드백 수렴 및 불만 처리'''),
            const SizedBox(height: 20),
            _buildSection(
              '4. 개인정보의 제3자 제공',
              '회사는 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 이용자가 사전에 동의한 경우, 법령에 따라 필요한 경우, 또는 서비스 제공을 위해 필요한 경우에는 예외입니다.',
            ),
            const SizedBox(height: 20),
            _buildHighlightedSection(
              '5. 개인정보 보호 조치',
              '''• 암호화: 비밀번호는 암호화되어 저장되며, 통신 구간은 HTTPS로 보호됩니다.
• 접근 제어: 개인정보에 접근 가능한 인원을 제한합니다.
• 정기 점검: 보안 취약점을 정기적으로 점검합니다.
• Firebase 보안: Google Firebase의 보안 정책을 준수합니다.''',
            ),
            const SizedBox(height: 20),
            _buildSection('6. 개인정보 보유 및 이용 기간', '''• 회원정보: 회원 탈퇴 시 즉시 삭제
• 게시물/댓글: 사용자 요청 시 또는 삭제 후 30일 내 완전 삭제'''),
            const SizedBox(height: 20),
            _buildSection('7. 개인정보 주체의 권리', '''이용자는 언제든지 다음의 권리를 행사할 수 있습니다:

• 개인정보 열람 및 수정 요청
• 개인정보 삭제 요청
• 개인정보 처리 정지 요청
• 개인정보 이동권 행사'''),
            const SizedBox(height: 20),
            _buildSection(
              '8. 문의처',
              '''개인정보 처리에 관한 문의사항이 있으시면 아래 연락처로 문의하시기 바랍니다:

이메일: khjs7878@naver.com
또는 앱 내 "고객센터"에서 문의하실 수 있습니다.''',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '본 개인정보 처리방침은 2026년 2월부터 적용됩니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(5),
            border: Border(
              left: BorderSide(color: const Color(0xFFFFC107), width: 4),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}
