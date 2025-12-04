import 'package:flutter/widgets.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/services/schedule_service.dart';

class ScheduleProvider with ChangeNotifier {
  Map<String, ScheduleModel> _scheduleMap = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  ScheduleModel? getById(String id) => _scheduleMap[id];

  Future<void> load() async {
    if (_loaded) return;
    final list = await ScheduleService().loadSchedules();
    for (var s in list) {
      _scheduleMap[s.gameId] = s;
    }
    _loaded = true;
    notifyListeners();
  }
}
