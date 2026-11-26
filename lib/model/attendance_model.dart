import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String gameId;
  final int season;
  final String date;
  final String time;
  final String stadium;
  final String homeTeam;
  final String awayTeam;
  final String myTeam;
  final String? oppTeam;
  final int myScore;
  final int opponentScore;
  final List<String> imageUrls;
  final String? memo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? ticketPrice;
  final String? seat;
  final String? seatType;
  final int? foodCost;
  final List<String> foodItems;
  final Map<String, int> foodPrices;
  final int? goodsCost;
  final List<String> goodsItems;
  final Map<String, int> goodsPrices;
  final bool isPublic;
  final int commentsCount;

  AttendanceModel({
    required this.gameId,
    required this.season,
    required this.date,
    required this.time,
    required this.stadium,
    required this.homeTeam,
    required this.awayTeam,
    required this.myTeam,
    this.oppTeam,
    required this.myScore,
    required this.opponentScore,
    this.imageUrls = const [],
    this.memo,
    this.createdAt,
    this.updatedAt,
    this.ticketPrice,
    this.seat,
    this.seatType,
    this.foodCost,
    this.foodItems = const [],
    this.foodPrices = const {},
    this.goodsCost,
    this.goodsItems = const [],
    this.goodsPrices = const {},
    this.isPublic = true,
    this.commentsCount = 0,
  });

  // Firestore DocumentSnapshot에서 모델로 변환
  factory AttendanceModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 점수 안전하게 파싱 (int 또는 String 모두 처리)
    final int myScore = data['myScore'] is int
        ? data['myScore'] as int
        : int.tryParse('${data['myScore']}') ?? 0;

    final int opponentScore = data['opponentScore'] is int
        ? data['opponentScore'] as int
        : int.tryParse('${data['opponentScore']}') ?? 0;

    // imageUrls 처리: 기존 단일 imageUrl과 새로운 imageUrls 모두 지원
    List<String> imageUrls = [];
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      imageUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      // 기존 데이터 호환성: 단일 imageUrl을 리스트로 변환
      imageUrls = [data['imageUrl'].toString()];
    }

    final int? ticketPrice = data['ticketPrice'] is int
        ? data['ticketPrice'] as int
        : int.tryParse('${data['ticketPrice']}');

    final int? foodCost = data['foodCost'] is int
        ? data['foodCost'] as int
        : int.tryParse('${data['foodCost']}');

    final List<String> foodItems = data['foodItems'] is List
        ? List<String>.from(data['foodItems'])
        : const [];

    final Map<String, int> foodPrices = {};
    if (data['foodPrices'] is Map) {
      (data['foodPrices'] as Map).forEach((k, v) {
        final parsed = v is int ? v : int.tryParse('$v') ?? 0;
        if (parsed > 0) {
          foodPrices[k.toString()] = parsed;
        }
      });
    }

    final int? goodsCost = data['goodsCost'] is int
        ? data['goodsCost'] as int
        : int.tryParse('${data['goodsCost']}');

    final List<String> goodsItems = data['goodsItems'] is List
        ? List<String>.from(data['goodsItems'])
        : const [];

    final Map<String, int> goodsPrices = {};
    if (data['goodsPrices'] is Map) {
      (data['goodsPrices'] as Map).forEach((k, v) {
        final parsed = v is int ? v : int.tryParse('$v') ?? 0;
        if (parsed > 0) {
          goodsPrices[k.toString()] = parsed;
        }
      });
    }

    return AttendanceModel(
      gameId: data['gameId'] ?? '',
      season: data['season'] ?? 0,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      oppTeam: data['oppTeam'],
      myScore: myScore,
      opponentScore: opponentScore,
      imageUrls: imageUrls,
      memo: data['memo'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      ticketPrice: ticketPrice,
      seat: data['seat'] as String?,
      seatType: data['seatType'] as String?,
      foodCost: foodCost,
      foodItems: foodItems,
      foodPrices: foodPrices,
      goodsCost: goodsCost,
      goodsItems: goodsItems,
      goodsPrices: goodsPrices,
      isPublic: data['isPublic'] is bool ? data['isPublic'] as bool : true,
      commentsCount: data['commentsCount'] is int
          ? data['commentsCount'] as int
          : int.tryParse('${data['commentsCount']}') ?? 0,
    );
  }

  // Map에서 모델로 변환 (직접 Map을 받을 때 사용)
  factory AttendanceModel.fromMap(Map<String, dynamic> data) {
    final int myScore = data['myScore'] is int
        ? data['myScore'] as int
        : int.tryParse('${data['myScore']}') ?? 0;

    final int opponentScore = data['opponentScore'] is int
        ? data['opponentScore'] as int
        : int.tryParse('${data['opponentScore']}') ?? 0;

    // imageUrls 처리: 기존 단일 imageUrl과 새로운 imageUrls 모두 지원
    List<String> imageUrls = [];
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      imageUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      // 기존 데이터 호환성: 단일 imageUrl을 리스트로 변환
      imageUrls = [data['imageUrl'].toString()];
    }

    return AttendanceModel(
      gameId: data['gameId'] ?? '',
      season: data['season'] ?? 0,
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      stadium: data['stadium'] ?? '',
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      myTeam: data['myTeam'] ?? '',
      oppTeam: data['oppTeam'],
      myScore: myScore,
      opponentScore: opponentScore,
      imageUrls: imageUrls,
      memo: data['memo'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // 모델을 Firestore Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'season': season,
      'date': date,
      'time': time,
      'stadium': stadium,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'myTeam': myTeam,
      if (oppTeam != null) 'oppTeam': oppTeam,
      'myScore': myScore,
      'opponentScore': opponentScore,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (ticketPrice != null) 'ticketPrice': ticketPrice,
      if (seat != null) 'seat': seat,
      if (seatType != null) 'seatType': seatType,
      if (foodCost != null) 'foodCost': foodCost,
      if (foodItems.isNotEmpty) 'foodItems': foodItems,
      if (foodPrices.isNotEmpty) 'foodPrices': foodPrices,
      if (goodsCost != null) 'goodsCost': goodsCost,
      if (goodsItems.isNotEmpty) 'goodsItems': goodsItems,
      if (goodsPrices.isNotEmpty) 'goodsPrices': goodsPrices,
      'isPublic': isPublic,
      'commentsCount': commentsCount,
    };
  }

  // copyWith 메서드 (선택사항, 필요시 사용)
  AttendanceModel copyWith({
    String? gameId,
    int? season,
    String? date,
    String? time,
    String? stadium,
    String? homeTeam,
    String? awayTeam,
    String? myTeam,
    String? oppTeam,
    int? myScore,
    int? opponentScore,
    List<String>? imageUrls,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? ticketPrice,
    String? seat,
    String? seatType,
    int? foodCost,
    List<String>? foodItems,
    Map<String, int>? foodPrices,
    int? goodsCost,
    List<String>? goodsItems,
    Map<String, int>? goodsPrices,
    bool? isPublic,
    int? commentsCount,
  }) {
    return AttendanceModel(
      gameId: gameId ?? this.gameId,
      season: season ?? this.season,
      date: date ?? this.date,
      time: time ?? this.time,
      stadium: stadium ?? this.stadium,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      myTeam: myTeam ?? this.myTeam,
      oppTeam: oppTeam ?? this.oppTeam,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      imageUrls: imageUrls ?? this.imageUrls,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      seat: seat ?? this.seat,
      seatType: seatType ?? this.seatType,
      foodCost: foodCost ?? this.foodCost,
      foodItems: foodItems ?? this.foodItems,
      foodPrices: foodPrices ?? this.foodPrices,
      goodsCost: goodsCost ?? this.goodsCost,
      goodsItems: goodsItems ?? this.goodsItems,
      goodsPrices: goodsPrices ?? this.goodsPrices,
      isPublic: isPublic ?? this.isPublic,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}
