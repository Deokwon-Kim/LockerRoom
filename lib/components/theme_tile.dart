import 'package:flutter/material.dart';
import 'package:lockerroom/model/team_model.dart';

class ThemeTile extends StatelessWidget {
  final TeamModel teamModel;
  final void Function()? onTap;
  final bool isSelected;
  const ThemeTile({
    super.key,
    required this.teamModel,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(15),
                margin: EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: teamModel.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(255, 255, 188, 2)
                        : teamModel.color,
                    width: 3,
                  ),
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

              // 체크 아이콘 (오른쪽 위)
            ],
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.check_circle,
                color: const Color.fromARGB(255, 255, 188, 2),
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}
