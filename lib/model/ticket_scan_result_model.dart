class TicketScanResultModel {
  final DateTime? gameDate;
  final String? gameTime;
  final List<String> detectedTeams;
  final String? stadium;
  final int? ticketPrice;
  final String? rawSeat;
  final String? seatType;
  final String rawText;

  TicketScanResultModel({
    this.gameDate,
    this.gameTime,
    this.detectedTeams = const [],
    this.stadium,
    this.ticketPrice,
    this.rawSeat,
    this.seatType,
    required this.rawText,
  });

  TicketScanResultModel copyWith({
    DateTime? gameDate,
    String? gameTime,
    List<String>? detectedTeams,
    String? stadium,
    int? ticketPrice,
    String? rawSeat,
    String? seatType,
    String? rawText,
  }) {
    return TicketScanResultModel(
      gameDate: gameDate ?? this.gameDate,
      gameTime: gameTime ?? this.gameTime,
      detectedTeams: detectedTeams ?? this.detectedTeams,
      stadium: stadium ?? this.stadium,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      rawSeat: rawSeat ?? this.rawSeat,
      seatType: seatType ?? this.seatType,
      rawText: rawText ?? this.rawText,
    );
  }

  @override
  String toString() {
    return 'TicketScanResult(date: $gameDate, time: $gameTime, teams: $detectedTeams, price: $ticketPrice, seat: $rawSeat, seatType: $seatType)';
  }
}
