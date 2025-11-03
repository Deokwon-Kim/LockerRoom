class FoodStoreModel {
  final String storeName;
  final String location;
  final String? storePhoto;
  final String type;

  FoodStoreModel({
    required this.storeName,
    required this.location,
    required this.type,
    this.storePhoto,
  });
}
