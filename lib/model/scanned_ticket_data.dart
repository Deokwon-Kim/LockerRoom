import 'dart:io';
import 'package:lockerroom/model/schedule_model.dart';

class ScannedTicketData {
  final ScheduleModel matchedGame;
  final DateTime gameDate;
  final int? ticketPrice;
  final String? seat;
  final File? ticketImageFile;

  ScannedTicketData({
    required this.matchedGame,
    required this.gameDate,
    this.ticketPrice,
    this.seat,
    this.ticketImageFile,
  });
}

