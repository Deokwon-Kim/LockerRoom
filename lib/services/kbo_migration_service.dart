import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lockerroom/services/schedule_service.dart';
import 'package:flutter/foundation.dart';

class KboMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScheduleService _scheduleService = ScheduleService();

  /// 2026 시즌 데이터만 필터링하여 Firestore의 'games' 컬렉션에 업로드합니다.
  /// 사용자가 이미 기존 컬렉션을 삭제했으므로, 단순 업로드 로직으로 간소화했습니다.
  Future<int> performMigration() async {
    try {
      // 1. CSV에서 모든 일정 로드
      final allSchedules = await _scheduleService.loadSchedules();

      // 2. 2026 시즌 데이터만 필터링
      final schedules2026 = allSchedules
          .where((s) => s.season == 2026)
          .toList();
      debugPrint('Filtered ${schedules2026.length} games for 2026 season.');

      if (schedules2026.isEmpty) {
        debugPrint('No games found for 2026 season.');
        return 0;
      }

      int totalSynced = 0;

      // 3. 500개 단위로 배치 업로드 (Firestore 제한)
      for (var i = 0; i < schedules2026.length; i += 500) {
        final end = (i + 500 < schedules2026.length)
            ? i + 500
            : schedules2026.length;
        final chunk = schedules2026.sublist(i, end);

        final batch = _firestore.batch();
        for (var game in chunk) {
          final docRef = _firestore.collection('games').doc(game.gameId);
          // 덮어쓰기(Set) 방식으로 데이터 업로드
          batch.set(docRef, game.toFirestore(), SetOptions(merge: true));
        }

        await batch.commit();
        totalSynced += chunk.length;
        debugPrint('Synced $totalSynced / ${schedules2026.length} games...');
      }

      return totalSynced;
    } catch (e) {
      debugPrint('Migration Error: $e');
      rethrow;
    }
  }
}
