class ScheduleModel {
  final int season;
  final String gameId;
  final DateTime dateTimeKst;
  final String? weekday;
  final String homeTeam;
  final String awayTeam;
  final String stadium;
  final String status; // SCHEDULED / IN_PLAY / FINAL / PPD
  final String? broadcast;
  final String? doubleHeaderNo;
  final String? note;
  final String gameType;
  final int homeScore;
  final int awayScroe;

  ScheduleModel({
    required this.season,
    required this.gameId,
    required this.dateTimeKst,
    this.weekday,
    required this.homeTeam,
    required this.awayTeam,
    required this.stadium,
    required this.status,
    this.broadcast,
    this.doubleHeaderNo,
    this.note,
    required this.gameType,
    required this.homeScore,
    required this.awayScroe,
  });
}
