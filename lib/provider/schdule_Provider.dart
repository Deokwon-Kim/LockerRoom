import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/services/schedule_service.dart';

class ScheduleProvider with ChangeNotifier {
  final Map<String, ScheduleModel> _scheduleMap = {};
  bool _loaded = false;
  StreamSubscription? _subscription;

  bool get loaded => _loaded;
  List<ScheduleModel> get allSchedules => _scheduleMap.values.toList();

  ScheduleModel? getById(String id) => _scheduleMap[id];

  Future<void> load() async {
    if (_loaded) return;

    // 1. Load static CSV data (2023-2025)
    // Note: This still loads all schedules including 2026 CSV if present.
    // Firestore updates will overwrite these with live data for matching gameIds.
    final staticList = await ScheduleService().loadSchedules();
    for (var s in staticList) {
      _scheduleMap[s.gameId] = s;
    }

    // 2. Listen to Firestore real-time data for games
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('games')
        .snapshots()
        .listen(
          (snapshot) {
            for (var doc in snapshot.docs) {
              try {
                final model = ScheduleModel.fromFirestore(doc);
                _scheduleMap[model.gameId] = model;
              } catch (e) {
                debugPrint('Error parsing game doc ${doc.id}: $e');
              }
            }
            _loaded = true;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Firestore Schedule Subscription Error: $error');
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
