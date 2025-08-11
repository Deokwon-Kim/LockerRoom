import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lockerroom/model/schedule_model.dart';

class ScheduleService {
  static const String defaultAssetPath = 'assets/schedules/kbo_2025.csv';

  Future<List<ScheduleModel>> loadSchedules({
    String assetPath = defaultAssetPath,
  }) async {
    final String raw = await rootBundle.loadString(assetPath, cache: true);
    // Parse CSV
    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
    ).convert(raw);
    if (rows.isEmpty) return [];

    // Assume first row is header
    final List<String> header = rows.first
        .map((e) => e.toString().trim())
        .toList();
    final int idxSeason = header.indexOf('season');
    final int idxGameId = header.indexOf('game_id');
    final int idxDate = header.indexOf('date');
    final int idxTime = header.indexOf('time');
    final int idxWeekday = header.indexOf('weekday');
    final int idxHomeTeam = header.indexOf('home_team');
    final int idxAwayTeam = header.indexOf('away_team');
    final int idxStadium = header.indexOf('stadium');
    final int idxStatus = header.indexOf('status');
    final int idxBroadcast = header.indexOf('broadcast');
    final int idxDoubleHeader = header.indexOf('doubleheader_no');
    final int idxNote = header.indexOf('note');

    String normalizeToHHmm(String rawTime) {
      final t = rawTime.trim();
      if (t.isEmpty) return '00:00';

      final ampmRe = RegExp(r'^(오전|오후)\s*(\d{1,2})(?::(\d{1,2}))?');
      final ampmM = ampmRe.firstMatch(t);
      if (ampmM != null) {
        final ampm = ampmM.group(1)!; // 오전/오후
        int hour = int.tryParse(ampmM.group(2)!) ?? 0;
        int minute = int.tryParse(ampmM.group(3) ?? '0') ?? 0;
        if (ampm == '오후' && hour < 12) hour += 12;
        if (ampm == '오전' && hour == 12) hour = 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }

      final hmRe = RegExp(r'^(\d{1,2})(?::(\d{1,2}))?');
      final hmM = hmRe.firstMatch(t);
      if (hmM != null) {
        int hour = int.tryParse(hmM.group(1)!) ?? 0;
        int minute = int.tryParse(hmM.group(2) ?? '0') ?? 0;
        if (hour >= 24) hour = 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }

      return '00:00';
    }

    DateTime parseKst(String date, String time) {
      final String hhmm = normalizeToHHmm(time); // ← 여기로 변경
      final String isoLocal = '${date.trim()}T$hhmm:00'; // 초는 00 유지
      return DateTime.parse(isoLocal);
    }

    final List<ScheduleModel> schedules = [];
    for (int i = 1; i < rows.length; i++) {
      final List<dynamic> r = rows[i];
      if (r.isEmpty) continue;
      try {
        schedules.add(
          ScheduleModel(
            season: int.tryParse(r[idxSeason].toString()) ?? 2025,
            gameId: r[idxGameId].toString(),
            dateTimeKst: parseKst(r[idxDate].toString(), r[idxTime].toString()),
            weekday: idxWeekday >= 0 ? r[idxWeekday]?.toString() : null,
            homeTeam: r[idxHomeTeam].toString(),
            awayTeam: r[idxAwayTeam].toString(),
            stadium: r[idxStadium].toString(),
            status: r[idxStatus].toString(),
            broadcast: idxBroadcast >= 0 ? r[idxBroadcast]?.toString() : null,
            doubleHeaderNo: idxDoubleHeader >= 0
                ? r[idxDoubleHeader]?.toString()
                : null,
            note: idxNote >= 0 ? r[idxNote]?.toString() : null,
          ),
        );
      } catch (_) {
        // skip bad row
      }
    }
    return schedules;
  }
}
