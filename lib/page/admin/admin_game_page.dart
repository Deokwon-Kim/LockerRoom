import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminGamePage extends StatefulWidget {
  const AdminGamePage({super.key});

  @override
  State<AdminGamePage> createState() => _AdminGamePageState();
}

class _AdminGamePageState extends State<AdminGamePage> {
  DateTime _selectedDate = DateTime.now();

  static const List<String> _statusOptions = [
    'SCHEDULED',
    'LIVE',
    'FINAL',
    'PPD',
  ];
  static const Map<String, String> _statusNames = {
    'SCHEDULED': '예정',
    'LIVE': '진행중',
    'FINAL': '종료',
    'PPD': '취소',
  };

  static final List<String> _inningOptions = List.generate(24, (index) {
    int inning = (index ~/ 2) + 1;
    String half = index % 2 == 0 ? '초' : '말';
    return '$inning회$half';
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    if (!userProvider.isAdmin) {
      return const Scaffold(body: Center(child: Text('접근 권한이 없습니다.')));
    }

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final games = scheduleProvider.allSchedules.where((s) {
      final gameDate = DateFormat('yyyy-MM-dd').format(s.dateTimeKst);
      return gameDate == dateKey;
    }).toList();

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        title: const Text(
          '경기 데이터 관리 (Admin)',
          style: TextStyle(color: BLACK, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: BLACK),
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          Expanded(
            child: games.isEmpty
                ? const Center(child: Text('해당 날짜에 경기가 없습니다.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      return _buildGameCard(games[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: WHITE,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
            icon: const Icon(Icons.arrow_back_ios, size: 20),
          ),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2027),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: BLACK,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(ScheduleModel game) {
    return Card(
      color: WHITE,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${game.stadium} | ${DateFormat('HH:mm').format(game.dateTimeKst)}',
                    style: const TextStyle(
                      color: GRAYSCALE_LABEL_500,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isDense: true,
                      value: _statusOptions.contains(game.status)
                          ? game.status
                          : (_statusNames.entries
                                    .where((e) => e.value == game.status)
                                    .firstOrNull
                                    ?.key ??
                                'SCHEDULED'),
                      items: _statusOptions.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(
                            _statusNames[s]!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          Map<String, dynamic> data = {'status': val};
                          if (val != 'LIVE') data['inning'] = null;
                          if (val == 'LIVE' && game.inning == null) {
                            data['inning'] = '1회초';
                          }
                          _updateGameData(game.gameId, data);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildTeamScoreControl(
                  teamName: game.homeTeam,
                  score: game.homeScore,
                  onChanged: (val) =>
                      _updateGameData(game.gameId, {'homeScore': val}),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: GRAYSCALE_LABEL_300,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildTeamScoreControl(
                  teamName: game.awayTeam,
                  score: game.awayScore,
                  onChanged: (val) =>
                      _updateGameData(game.gameId, {'awayScore': val}),
                ),
              ],
            ),
            if (game.status != 'SCHEDULED') ...[
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Text(
                      '이닝 정보:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: GRAYSCALE_LABEL_500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: GRAYSCALE_LABEL_50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GRAYSCALE_LABEL_200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _inningOptions.contains(game.inning)
                                ? game.inning
                                : null,
                            hint: const Text(
                              '이닝 선택',
                              style: TextStyle(fontSize: 13),
                            ),
                            items: _inningOptions.map((i) {
                              return DropdownMenuItem(
                                value: i,
                                child: Text(
                                  i,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _updateGameData(game.gameId, {'inning': val});
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreControl({
    required String teamName,
    required int score,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            teamName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _counterButton(
                icon: Icons.remove,
                onPressed: score > 0 ? () => onChanged(score - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _counterButton(
                icon: Icons.add,
                onPressed: () => onChanged(score + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterButton({required IconData icon, VoidCallback? onPressed}) {
    return Material(
      color: onPressed == null ? Colors.grey[100] : BUTTON.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed == null ? Colors.transparent : BUTTON,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: onPressed == null ? Colors.grey : BUTTON,
            size: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _updateGameData(String gameId, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(gameId)
          .update(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
      }
    }
  }
}
