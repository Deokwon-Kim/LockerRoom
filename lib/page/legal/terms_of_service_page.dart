import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text(
          '이용약관',
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
              '📋 더베이스 이용약관',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '마지막 업데이트: 2025년 10월',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '서문',
              '본 이용약관은 더베이스가 제공하는 모바일 애플리케이션 및 관련 서비스의 이용에 관하여 회사와 이용자 간의 권리, 의무 및 책임사항을 규정하고 있습니다. 이용자는 본 약관에 동의함으로써 서비스를 이용할 수 있습니다.',
            ),
            const SizedBox(height: 20),
            _buildSection(
              '제1조 서비스의 정의',
              '''"서비스"는 더베이스 모바일 애플리케이션을 통해 제공되는 모든 기능을 의미하며, 다음을 포함합니다:

• 팀 기반 커뮤니티 피드
• 게시물 작성 및 공유
• 댓글 및 상호작용
• 팔로우 및 팔로워 관리
• 중고거래 마켓
• 의견 기록(직관 기록)
• 알림 및 푸시 메시지''',
            ),
            const SizedBox(height: 20),
            _buildSection(
              '제2조 계정 및 비밀번호',
              '''1. 이용자가 회원가입 시 제공한 정보는 정확하고 진실되어야 합니다.
2. 이용자는 자신의 계정과 비밀번호에 대한 모든 책임을 집니다.
3. 계정의 부정 이용, 비밀번호 유출에 대해서는 회사가 책임을 지지 않습니다.''',
            ),
            const SizedBox(height: 20),
            _buildWarningSection('제3조 금지 행위', '''이용자는 다음의 행위를 하지 않아야 합니다:

• 불법적인 콘텐츠 업로드 (아동학대, 폭력, 음란물 등)
• 타인의 개인정보 도용 및 계정 탈취
• 저작권, 초상권, 명예권, 프라이버시권 침해
• 스팸, 광고성 콘텐츠 게시
• 타인에 대한 명예훼손, 모욕, 협박
• 혐오 표현, 차별 발언
• 불법 거래 중개
• 서비스 정상 작동 방해
• 해킹, 악성 소프트웨어 배포

위반 시 경고, 게시물 삭제, 계정 정지, 영구 차단 등의 조치가 취해질 수 있습니다.'''),
            const SizedBox(height: 20),
            _buildSection('제4조 콘텐츠 및 저작권', '''1. 이용자가 게시한 콘텐츠는 이용자의 저작물입니다.
2. 회사는 이용자의 콘텐츠를 서비스 운영 목적으로만 사용할 수 있습니다.
3. 저작권 침해 신고는 이메일 또는 앱 내 고객센터를 통해 제출할 수 있습니다.
4. 타인의 콘텐츠를 무단 도용하면 법적 책임을 질 수 있습니다.'''),
            const SizedBox(height: 20),
            _buildSection('제5조 신고 및 조치', '''1. 이용자는 부적절한 콘텐츠를 신고할 수 있습니다.
2. 회사는 신고된 콘텐츠를 검토하여 필요한 조치를 합니다.
3. 신고자의 정보는 보호되며, 허위 신고는 조치의 대상이 될 수 있습니다.'''),
            const SizedBox(height: 20),
            _buildSection('제6조 중고거래 규정', '''1. 중고거래 마켓에서의 거래는 이용자 간의 개인 거래입니다.
2. 회사는 거래 중개만 하며, 거래 결과에 대해 책임을 지지 않습니다.
3. 거래 관련 분쟁은 이용자 간 협의로 해결합니다.
4. 불법 물품 거래(성인용품, 의약품, 위조품 등)는 엄격히 금지됩니다.'''),
            const SizedBox(height: 20),
            _buildSection(
              '제7조 서비스 중단 및 종료',
              '''1. 회사는 운영상 필요시 서비스를 일시 중단할 수 있습니다.
2. 이용자가 약관을 위반하면, 경고 또는 계정 정지될 수 있습니다.
3. 심각한 위반은 영구 차단 대상이 됩니다.
4. 서비스 종료 시 축적된 데이터는 삭제될 수 있습니다.''',
            ),
            const SizedBox(height: 20),
            _buildSection('제8조 면책 조항', '''1. 회사는 다음의 경우에 대해 책임을 지지 않습니다:
   - 천재지변, 긴급사태 등으로 인한 서비스 중단
   - 이용자의 컴퓨터 오류, 네트워크 문제
   - 서비스 이용으로 인한 간접적 손실
   - 이용자 간의 거래 결과
   - 제3자의 불법 행위로 인한 피해

2. 본 서비스는 "있는 그대로" 제공되며, 회사는 명시적/암묵적 보증을 하지 않습니다.'''),
            const SizedBox(height: 20),
            _buildSection('제9조 분쟁 해결', '''1. 본 약관과 관련된 분쟁은 대한민국 법률에 따라 처리됩니다.
2. 회사와 이용자 간의 분쟁은 협의로 우선 해결합니다.
3. 협의가 불가능한 경우, 한국소비자원 또는 관할 법원에 의뢰합니다.'''),
            const SizedBox(height: 20),
            _buildSection(
              '제10조 약관의 변경',
              '''1. 회사는 법령의 변경이나 서비스 운영상 필요시 약관을 변경할 수 있습니다.
2. 약관 변경 시 최소 30일 전에 공지합니다.
3. 이용자가 변경된 약관에 동의하지 않으면 서비스 이용을 중단할 수 있습니다.
4. 변경된 약관에 계속 이용하는 경우, 동의한 것으로 간주합니다.''',
            ),
            const SizedBox(height: 20),
            _buildSection('제11조 고객 지원', '''고객지원 관련 문의사항은 다음 경로를 통해 해결합니다:

• 앱 내 "고객센터" 메뉴
• 이메일: khjs7878@naver.com
• 공식 웹사이트의 문의 폼'''),
            const SizedBox(height: 20),
            _buildHighlightedSection(
              '📌 중요 안내',
              '본 약관에 동의하지 않으면 서비스를 이용할 수 없습니다. 회사는 이용자의 이해를 위해 약관을 명확하게 작성했으나, 의문사항이 있으면 고객센터로 문의하시기 바랍니다.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '본 이용약관은 2025년 10월부터 적용됩니다.',
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

  Widget _buildWarningSection(String title, String content) {
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
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(5),
            border: Border(
              left: BorderSide(color: const Color(0xFFF44336), width: 4),
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

  Widget _buildHighlightedSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(5),
        border: Border(
          left: BorderSide(color: const Color(0xFFFFC107), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
