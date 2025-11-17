import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lockerroom/model/schedule_model.dart';

class ScheduleService {
  static const String defaultAssetPath =
      'assets/schedules/kbo_2025_results.csv';
  static const List<String> defaultAssetPaths = [
    'assets/schedules/kbo_2023.csv',
    'assets/schedules/kbo_2024.csv',
    'assets/schedules/kbo_2025_results.csv',
    'assets/schedules/kbo_2026.csv',
  ];

  Future<List<ScheduleModel>> loadSchedules({
    String assetPath = defaultAssetPath,
    List<String>? assetPaths,
  }) async {
    final List<String> targets = (assetPaths == null || assetPaths.isEmpty)
        ? defaultAssetPaths
        : assetPaths;

    final List<ScheduleModel> all = [];
    for (final path in targets) {
      final List<ScheduleModel> one = await _loadSingleCsv(path);
      all.addAll(one);
    }
    return all;
  }

  Future<List<ScheduleModel>> _loadSingleCsv(String assetPath) async {
    final String raw = await rootBundle.loadString(assetPath, cache: true);
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
    final int idxScore = header.indexOf('score');

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

    int _parseIntOrZero(String? s) {
      if (s == null) return 0;
      final v = int.tryParse(s.trim());
      return v ?? 0;
    }

    (int away, int home) _parseScore(String? raw) {
      if (raw == null) return (0, 0);
      final t = raw.trim();
      if (t.isEmpty) return (0, 0);
      final parts = t.split('-');
      if (parts.length == 2) {
        final away = _parseIntOrZero(parts[0]);
        final home = _parseIntOrZero(parts[1]);
        return (away, home);
      }
      return (0, 0);
    }

    final List<ScheduleModel> schedules = [];
    for (int i = 1; i < rows.length; i++) {
      final List<dynamic> r = rows[i];
      if (r.isEmpty) continue;
      try {
        int awayScore = 0;
        int homeScore = 0;
        if (idxScore >= 0 && idxScore < r.length) {
          final parsed = _parseScore(r[idxScore]?.toString());
          awayScore = parsed.$1;
          homeScore = parsed.$2;
        }
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
            homeScore: homeScore,
            awayScroe: awayScore,
          ),
        );
      } catch (_) {
        // skip bad row
      }
    }
    return schedules;
  }
}
