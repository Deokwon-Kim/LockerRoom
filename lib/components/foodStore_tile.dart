import 'package:flutter/cupertino.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/food_store_model.dart';

class FoodstoreTile extends StatelessWidget {
  final FoodStoreModel foodStoreModel;
  final void Function()? onTap;
  final bool isSelected;
  const FoodstoreTile({
    super.key,
    required this.foodStoreModel,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  foodStoreModel.storePhoto ??
                      'assets/images/applogo/app_logo.png',
                  height: 100,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodStoreModel.storeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      foodStoreModel.type,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '위치:${foodStoreModel.location}',
                      style: TextStyle(
                        color: GRAYSCALE_LABEL_500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
