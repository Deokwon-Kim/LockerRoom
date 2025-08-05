import 'package:flutter/material.dart';
import 'package:lockerroom/model/team_model.dart';

class ThemeTile extends StatelessWidget {
  final TeamModel teamModel;
  final void Function()? onTap;
  const ThemeTile({super.key, required this.teamModel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(15),
            margin: EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: teamModel.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: teamModel.color),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 110,
                height: 110,
                child: Image.asset(teamModel.logoPath),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
