import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPostModel {
  final String userId;
  final String userName;
  final String title;
  final String? description;
  final List<String> imageUrls;
  final String price;
  final String type;
  final DateTime createdAt;

  MarketPostModel({
    required this.userId,
    required this.userName,
    required this.title,
    this.description,
    required this.imageUrls,
    required this.price,
    required this.type,
    required this.createdAt,
  });

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
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      imageUrls: imageUrls,
      price: data['price']?.toString() ?? '0',
      type: data['type'] ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
