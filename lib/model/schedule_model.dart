import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final int season;
  final String gameId;
  final DateTime dateTimeKst;
  final String? weekday;
  final String homeTeam;
  final String awayTeam;
  final String stadium;
  final String status; // SCHEDULED / LIVE / FINAL / PPD
  final String? inning;
  final String? broadcast;
  final String? doubleHeaderNo;
  final String? note;
  final String gameType;
  final int homeScore;
  final int awayScore;

  ScheduleModel({
    required this.season,
    required this.gameId,
    required this.dateTimeKst,
    this.weekday,
    required this.homeTeam,
    required this.awayTeam,
    required this.stadium,
    required this.status,
    this.inning,
    this.broadcast,
    this.doubleHeaderNo,
    this.note,
    required this.gameType,
    required this.homeScore,
    required this.awayScore,
  });

  factory ScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleModel(
      season: data['season'] ?? 2026,
      gameId: doc.id,
      dateTimeKst: (data['dateTimeKst'] as Timestamp).toDate().toLocal(),
      weekday: data['weekday'],
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      stadium: data['stadium'] ?? '',
      status: data['status'] ?? 'SCHEDULED',
      inning: data['inning'],
      broadcast: data['broadcast'],
      doubleHeaderNo: data['doubleHeaderNo']?.toString(),
      note: data['note'],
      gameType: data['gameType'] ?? '',
      homeScore: data['homeScore'] ?? 0,
      awayScore: data['awayScore'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'season': season,
      'dateTimeKst': Timestamp.fromDate(dateTimeKst),
      'weekday': weekday,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'stadium': stadium,
      'status': status,
      'inning': inning,
      'broadcast': broadcast,
      'doubleHeaderNo': doubleHeaderNo,
      'note': note,
      'gameType': gameType,
      'homeScore': homeScore,
      'awayScore': awayScore,
    };
  }
}
