import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPostModel {
  final String userId;
  final String userName;
  final String title;
  final String? description;
  final List<String> imageUrl;
  final double price;
  final String type;
  final DateTime createdAt;

  MarketPostModel({
    required this.userId,
    required this.userName,
    required this.title,
    this.description,
    required this.imageUrl,
    required this.price,
    required this.type,
    required this.createdAt,
  });

  factory MarketPostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketPostModel(
      userId: doc.id,
      userName: data['userName'],
      title: data['title'],
      imageUrl: List<String>.from(data['mediaUrls'] ?? []),
      price: data['price'],
      type: data['type'],
      createdAt: data['createdAt'],
    );
  }
}
