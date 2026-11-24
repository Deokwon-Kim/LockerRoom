import 'package:cloud_firestore/cloud_firestore.dart';

/// KBO 9개 구장 표준 목록 (좌석 시야 게시판용)
const List<String> kSeatViewStadiums = [
  '잠실야구장',
  '고척스카이돔',
  '인천 SSG 랜더스필드',
  '수원 KT위즈파크',
  '대전 한화생명볼파크',
  '광주-기아 챔피언스필드',
  '대구 삼성라이온즈파크',
  '창원NC파크',
  '부산 사직야구장',
];

const Map<String, String> kStadiumPhotoAssets = {
  '잠실야구장': 'assets/images/stadium/jamsil.jpg',
  '고척스카이돔': 'assets/images/stadium/gocheok.jpg',
  '인천 SSG 랜더스필드': 'assets/images/stadium/landersfelid.jpg',
  '수원 KT위즈파크': 'assets/images/stadium/wizpark.jpg',
  '대전 한화생명볼파크': 'assets/images/stadium/daejeon.jpg',
  '광주-기아 챔피언스필드': 'assets/images/stadium/kia.jpg',
  '대구 삼성라이온즈파크': 'assets/images/stadium/lionspark.jpg',
  '창원NC파크': 'assets/images/stadium/ncpark.jpg',
  '부산 사직야구장': 'assets/images/stadium/sajik.jpg',
};

const Map<String, String> kStadiumShortNames = {
  '전체 구장': '전체',
  '잠실야구장': '잠실',
  '고척스카이돔': '고척',
  '인천 SSG 랜더스필드': '인천',
  '수원 KT위즈파크': '수원',
  '대전 한화생명볼파크': '대전',
  '광주-기아 챔피언스필드': '광주',
  '대구 삼성라이온즈파크': '대구',
  '창원NC파크': '창원',
  '부산 사직야구장': '부산',
};

const List<String> kSeatViewZones = ['전체', '포수뒤', '1루', '3루', '외야', '기타'];

const List<String> kSeatViewTags = [
  '시야 탁트임',
  '그물망 주의',
  '그늘',
  '햇빛 주의',
  '응원단상 근처',
  '테이블석',
];

class SeatViewModel {
  final String id;
  final String userId;
  final String userNickName;
  final String? userProfileImage;
  final String stadium;
  final String zone;
  final String seatText;
  final String blockNumber;
  final List<String> imageUrls;
  final String review;
  final List<String> tags;
  final List<String> likedBy;
  final DateTime createdAt;

  const SeatViewModel({
    required this.id,
    required this.userId,
    required this.userNickName,
    this.userProfileImage,
    required this.stadium,
    required this.zone,
    required this.seatText,
    required this.blockNumber,
    required this.imageUrls,
    required this.review,
    this.tags = const [],
    this.likedBy = const [],
    required this.createdAt,
  });

  int get likeCount => likedBy.length;

  factory SeatViewModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SeatViewModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userNickName: (data['userNickName'] ?? '야구팬').toString(),
      userProfileImage: data['userProfileImage'] as String?,
      stadium: (data['stadium'] ?? '').toString(),
      zone: (data['zone'] ?? '기타').toString(),
      seatText: (data['seatText'] ?? '').toString(),
      blockNumber: (data['blockNumber'] ?? '').toString(),
      imageUrls: data['imageUrls'] is List
          ? List<String>.from(data['imageUrls'])
          : const [],
      review: (data['review'] ?? '').toString(),
      tags: data['tags'] is List ? List<String>.from(data['tags']) : const [],
      likedBy: data['likedBy'] is List
          ? List<String>.from(data['likedBy'])
          : const [],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userNickName': userNickName,
    if (userProfileImage != null) 'userProfileImage': userProfileImage,
    'stadium': stadium,
    'zone': zone,
    'seatText': seatText,
    'blockNumber': blockNumber,
    'imageUrls': imageUrls,
    'review': review,
    'tags': tags,
    'likedBy': likedBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// 좌석 문자열에서 구역(포수뒤/1루/3루/외야/기타) 자동 추정
  static String inferZone(String seatText) {
    final s = seatText.replaceAll(' ', '');
    if (s.contains('포수') || s.contains('중앙') || s.contains('프리미엄')) {
      return '포수뒤';
    }
    if (s.contains('1루')) return '1루';
    if (s.contains('3루')) return '3루';
    if (s.contains('외야')) return '외야';
    return '기타';
  }

  /// 좌석 문자열에서 블럭 번호 추출 (예: '306블럭' -> '306')
  static String extractBlock(String seatText) {
    final m = RegExp(r'(\d{2,4})\s*(?:블럭|블록|구역)').firstMatch(seatText);
    if (m != null) return m.group(1) ?? '';
    final fallback = RegExp(r'\b(\d{3})\b').firstMatch(seatText);
    return fallback?.group(1) ?? '';
  }

  /// 구장명 정규화
  static String normalizeStadium(String raw) {
    final s = raw.trim();
    if (s.contains('잠실')) return '잠실야구장';
    if (s.contains('고척')) return '고척스카이돔';
    if (s.contains('문학') || s.contains('랜더스') || s.contains('SSG')) {
      return '인천 SSG 랜더스필드';
    }
    if (s.contains('수원') || s.contains('위즈')) return '수원 KT위즈파크';
    if (s.contains('대전') || s.contains('한화') || s.contains('볼파크')) {
      return '대전 한화생명볼파크';
    }
    if (s.contains('광주') || s.contains('챔피언')) return '광주-기아 챔피언스필드';
    if (s.contains('대구') || s.contains('라이온즈')) return '대구 삼성라이온즈파크';
    if (s.contains('창원') || s.contains('NC')) return '창원NC파크';
    if (s.contains('사직') || s.contains('부산')) return '부산 사직야구장';
    return s.isNotEmpty ? s : kSeatViewStadiums.first;
  }
}
