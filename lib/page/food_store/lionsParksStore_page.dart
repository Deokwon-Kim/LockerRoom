import 'package:flutter/material.dart';
import 'package:lockerroom/components/foodStore_tile.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/food_store_provider.dart';
import 'package:provider/provider.dart';

class LionsparksstorePage extends StatelessWidget {
  const LionsparksstorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final fsp = context.read<FoodStoreProvider>().getStore('라이온즈 파크');
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: Text(
          '라이온즈파크 푸드존',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(left: 10, right: 10),
              itemCount: fsp.length,
              itemBuilder: (context, index) {
                final foodStore = fsp[index];

                return FoodstoreTile(foodStoreModel: foodStore);
              },
            ),
          ),
        ],
      ),
    );
  }
}
