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
          Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: teamModel.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color.fromARGB(255, 255, 188, 2)
                    : teamModel.color,
                width: 3,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth > constraints.maxHeight * 1.25;
                if (isWide) {
                  final double logoSize = (constraints.maxHeight * 0.84).clamp(
                    36.0,
                    68.0,
                  );
                  return Row(
                    children: [
                      SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Image.asset(
                          teamModel.logoPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          teamModel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                color: Color(0x47000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          final double logoSize =
                              inner.biggest.shortestSide * 0.88;
                          return Center(
                            child: SizedBox(
                              width: logoSize,
                              height: logoSize,
                              child: Image.asset(
                                teamModel.logoPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      teamModel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        shadows: [
                          Shadow(
                            color: Color(0x47000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
