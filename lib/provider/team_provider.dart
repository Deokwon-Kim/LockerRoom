import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';

class TeamProvider with ChangeNotifier {
  String? _team;

  String? get team => _team;

  Future<void> loadTeam(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (doc.exists && doc.data()?['team'] != null) {
      _team = doc['team'];
    }
    notifyListeners();
  }

  final Map<String, List<TeamModel>> _teamList = {
    'team': [
      TeamModel(
        name: '두산베어스',
        symplename: '두산',
        stadium: '잠실야구장',
        logoPath: 'assets/images/logo/1.png',
        calenderLogo: 'assets/images/logo/1.png',
        symbolPath: 'assets/images/symbol/newlogo2.png',
        youtubeName: 'BEARS TV',
        youtubeUrl: 'https://www.youtube.com/@bearstv1982',
        channelId: 'UCsebzRfMhwYfjeBIxNX1brg',
        color: Doosan,
      ),
      TeamModel(
        name: '삼성라이온즈',
        symplename: '삼성',
        stadium: '라이온즈 파크',
        logoPath: 'assets/images/logo/lions.png',
        calenderLogo: 'assets/images/logo/lions2.png',
        symbolPath: 'assets/images/symbol/samsung_symbol.png',
        youtubeName: 'LIONS TV',
        youtubeUrl: 'https://www.youtube.com/@lionstv1982',
        channelId: 'UCMWAku3a3h65QpLm63Jf2pw',
        color: Samsung,
      ),
      TeamModel(
        name: '롯데자이언츠',
        symplename: '롯데',
        stadium: '사직야구장',
        logoPath: 'assets/images/logo/lotte.png',
        calenderLogo: 'assets/images/logo/lotte.png',
        symbolPath: 'assets/images/symbol/lotte_symbol.png',
        youtubeName: '자이언츠 TV',
        youtubeUrl: 'https://www.youtube.com/@giantstv',
        channelId: 'UCAZQZdSY5_YrziMPqXi-Zfw',
        color: Lotte,
      ),
      TeamModel(
        name: '기아타이거즈',
        symplename: '기아',
        stadium: '챔피언스 필드',
        logoPath: 'assets/images/logo/tigers.png',
        calenderLogo: 'assets/images/logo/tigers.png',
        symbolPath: 'assets/images/symbol/kia_symbol.png',
        youtubeName: '갸티비',
        youtubeUrl: 'https://www.youtube.com/@kiatigerstv',
        channelId: 'UCKp8knO8a6tSI1oaLjfd9XA',
        color: Kia,
      ),
      TeamModel(
        name: 'LG트윈스',
        symplename: 'LG',
        stadium: '잠실야구장',
        logoPath: 'assets/images/logo/twins.png',
        calenderLogo: 'assets/images/logo/twins.png',
        symbolPath: 'assets/images/symbol/lg_symbol.png',
        youtubeName: 'LGTWINSTV',
        youtubeUrl: 'https://www.youtube.com/@LGTwinsTV',
        channelId: 'UCL6QZZxb-HR4hCh_eFAnQWA',
        color: LG,
      ),
      TeamModel(
        name: 'SSG랜더스',
        symplename: 'SSG',
        stadium: '랜더스 필드',
        logoPath: 'assets/images/logo/ssg.png',
        calenderLogo: 'assets/images/logo/ssg.png',
        symbolPath: 'assets/images/symbol/landers_symbol.png',
        youtubeName: '쓱튜브',
        youtubeUrl: 'https://www.youtube.com/@SSGLANDERS',
        channelId: 'UCt8iRtgjVqm5rJHNl1TUojg',
        color: Landers,
      ),
      TeamModel(
        name: '한화이글스',
        symplename: '한화',
        stadium: '이글스 볼파크',
        logoPath: 'assets/images/logo/eagles.png',
        calenderLogo: 'assets/images/logo/eagles.png',
        symbolPath: 'assets/images/symbol/hanwha_symbol.png',
        youtubeName: 'Eagles TV',
        youtubeUrl: 'https://www.youtube.com/@HanwhaEagles_official',
        channelId: 'UCdq4Ji3772xudYRUatdzRrg',
        color: Eagles,
      ),
      TeamModel(
        name: '키움히어로즈',
        symplename: '키움',
        stadium: '고척스카이돔',
        logoPath: 'assets/images/logo/heroes.png',
        calenderLogo: 'assets/images/logo/heroes.png',
        symbolPath: 'assets/images/symbol/kiwoom_symbol.png',
        youtubeName: '큠튜브',
        youtubeUrl: 'https://www.youtube.com/@heroesbaseballclub',
        channelId: 'UC_MA8-XEaVmvyayPzG66IKg',
        color: KIWOOM,
      ),

      TeamModel(
        name: 'NC다이노스',
        symplename: 'NC',
        stadium: '창원 NC파크',
        logoPath: 'assets/images/logo/nc.png',
        calenderLogo: 'assets/images/logo/nc.png',
        symbolPath: 'assets/images/symbol/nc_symbol.png',
        youtubeName: '엔튜브',
        youtubeUrl: 'https://www.youtube.com/@ncdinos',
        channelId: 'UC8_FRgynMX8wlGsU6Jh3zKg',
        color: NC,
      ),

      TeamModel(
        name: 'KT위즈',
        symplename: 'KT',
        stadium: '위즈파크',
        logoPath: 'assets/images/logo/kt.png',
        calenderLogo: 'assets/images/logo/kt.png',
        symbolPath: 'assets/images/symbol/kt_symbol.png',
        youtubeName: 'kt wiz - 위즈TV',
        youtubeUrl: 'https://www.youtube.com/@ktwiztv',
        channelId: 'UCvScyjGkBUx2CJDMNAi9Twg',
        color: KT,
      ),
    ],
  };

  TeamModel? _selectedTeam;

  List<TeamModel> getTeam(String category) {
    return _teamList[category] ?? [];
  }

  TeamModel? get selectedTeam => _selectedTeam;

  void selectTeam(TeamModel team) {
    _selectedTeam = team;
    notifyListeners();
  }

  // 팀 이름으로 TeamModel 찾기
  TeamModel? findTeamByName(String name) {
    final teams = _teamList['team'] ?? [];
    try {
      return teams.firstWhere((t) => t.symplename == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> setTeam(String team) async {
    _team = team;
    notifyListeners();
  }
}
