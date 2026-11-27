import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/model/team_model.dart';

enum WordmarkMode { english, korean, hidden }

class TeamWordmarkData {
  final String english;
  final String korean;

  const TeamWordmarkData({required this.english, required this.korean});
}

class TeamWordmark extends StatelessWidget {
  final TeamModel? team;
  final WordmarkMode mode;
  final Color textColor;
  final bool compact;

  const TeamWordmark({
    super.key,
    required this.team,
    this.mode = WordmarkMode.english,
    this.textColor = Colors.white,
    this.compact = false,
  });

  static const Map<String, TeamWordmarkData> _map = {
    '삼성': TeamWordmarkData(english: 'SAMSUNG LIONS', korean: '삼성 라이온즈'),
    'LG': TeamWordmarkData(english: 'LG TWINS', korean: 'LG 트윈스'),
    '두산': TeamWordmarkData(english: 'DOOSAN BEARS', korean: '두산 베어스'),
    '기아': TeamWordmarkData(english: 'KIA TIGERS', korean: 'KIA 타이거즈'),
    'KIA': TeamWordmarkData(english: 'KIA TIGERS', korean: 'KIA 타이거즈'),
    'SSG': TeamWordmarkData(english: 'SSG LANDERS', korean: 'SSG 랜더스'),
    'SK': TeamWordmarkData(english: 'SSG LANDERS', korean: 'SSG 랜더스'),
    '한화': TeamWordmarkData(english: 'HANWHA EAGLES', korean: '한화 이글스'),
    '롯데': TeamWordmarkData(english: 'LOTTE GIANTS', korean: '롯데 자이언츠'),
    'NC': TeamWordmarkData(english: 'NC DINOS', korean: 'NC 다이노스'),
    'KT': TeamWordmarkData(english: 'KT WIZ', korean: 'KT 위즈'),
    '키움': TeamWordmarkData(english: 'KIWOOM HEROES', korean: '키움 히어로즈'),
    '넥센': TeamWordmarkData(english: 'KIWOOM HEROES', korean: '키움 히어로즈'),
    '대한민국': TeamWordmarkData(english: 'TEAM KOREA', korean: '대한민국'),
  };

  static TeamWordmarkData resolve(TeamModel? team) {
    if (team == null) {
      return const TeamWordmarkData(
        english: 'SAMSUNG LIONS',
        korean: '삼성 라이온즈',
      );
    }
    return _map[team.symplename] ??
        _map[team.name] ??
        TeamWordmarkData(
          english: team.symplename.toUpperCase(),
          korean: team.name,
        );
  }

  @override
  Widget build(BuildContext context) {
    final logoPath = team?.logoPath ?? 'assets/images/korean_logo/lions.png';
    final badgeSize = compact ? 22.0 : 28.0;

    final badge = Container(
      width: badgeSize,
      height: badgeSize,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(compact ? 7 : 9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(logoPath, fit: BoxFit.contain),
    );

    if (mode == WordmarkMode.hidden) {
      return badge;
    }

    final data = resolve(team);
    final label = mode == WordmarkMode.english ? data.english : data.korean;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        SizedBox(width: compact ? 6 : 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mode == WordmarkMode.english
                ? GoogleFonts.bebasNeue(
                    fontSize: compact ? 15 : 20,
                    letterSpacing: 1.2,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    height: 1.0,
                  )
                : TextStyle(
                    fontFamily: 'kbo',
                    fontSize: compact ? 12 : 15,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: textColor,
                    letterSpacing: -0.3,
                    height: 1.05,
                  ),
          ),
        ),
      ],
    );
  }
}
