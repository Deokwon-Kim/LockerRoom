import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPostModel {
  final String postId;
  final String userId;
  final String userName;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final String price;
  final String type;
  final int viewCount;
  final List<String> viewdBy;
  final int likesCount;
  final List<String> likedBy;
  final DateTime createdAt;

  MarketPostModel({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.title,
    this.description,
    required this.imageUrls,
    required this.price,
    required this.type,
    this.viewCount = 0,
    this.viewdBy = const [],
    required this.likesCount,
    required this.likedBy,
    required this.createdAt,
  });

  MarketPostModel copyWith({
    String? postId,
    String? userId,
    String? userName,
    String? title,
    String? description,
    List<String>? imageUrls,
    String? price,
    String? type,
    int? viewCount,
    List<String>? viewdBy,
    int? likesCount,
    List<String>? likedBy,
    DateTime? createdAt,
  }) {
    return MarketPostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      imageUrls: imageUrls ?? this.imageUrls,
      price: price ?? this.price,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }

  factory MarketPostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // imageUrls 안전하게 파싱
    List<String> imageUrls = [];
    final imageUrlsData = data['imageUrls'];

    if (imageUrlsData != null) {
      if (imageUrlsData is List) {
        imageUrls = imageUrlsData
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (imageUrlsData is String) {
        if (imageUrlsData.isNotEmpty) {
          imageUrls = [imageUrlsData];
        }
      }
    }

    return MarketPostModel(
      postId: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      imageUrls: imageUrls,
      price: data['price']?.toString() ?? '0',
      type: data['type'] ?? '',
      viewCount: data['viewCount'] ?? 0,
      viewdBy: List<String>.from(data['viewdBy'] ?? []),
      likesCount: data['likesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
