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
        actions: [
          IconButton(
            onPressed: () async {
              try {
                final snapshot = await FirebaseFirestore.instance
                    .collection('games')
                    .get();
                final batch = FirebaseFirestore.instance.batch();
                int count = 0;
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  if (data['dateTimeKst'] != null) {
                    final dt = (data['dateTimeKst'] as Timestamp)
                        .toDate()
                        .toLocal();
                    final stadium = data['stadium'] ?? '';

                    // 2026년 8월 29일부터 9월 6일까지인지 확인
                    bool isTargetDate = false;
                    if (dt.year == 2026) {
                      if (dt.month == 8 && dt.day >= 29) isTargetDate = true;
                      if (dt.month == 9 && dt.day <= 6) isTargetDate = true;
                    }

                    if (isTargetDate) {
                      final isWeekend = dt.weekday == 6 || dt.weekday == 7;
                      if (isWeekend) {
                        int targetHour = 18;
                        int targetMinute = 0;

                        // 고척은 일요일만 14:00, 나머지는 18:00
                        if (stadium.contains('고척') && dt.weekday == 7) {
                          targetHour = 14;
                          targetMinute = 0;
                        }

                        final newDt = DateTime(
                          dt.year,
                          dt.month,
                          dt.day,
                          targetHour,
                          targetMinute,
                          0,
                        );
                        batch.update(doc.reference, {
                          'dateTimeKst': Timestamp.fromDate(newDt),
                        });
                        count++;
                      }
                    }
                  }
                }

                // 1. 8월 28일 잠실 취소된 경기 상태를 PPD로 변경
                final oldGameRef = FirebaseFirestore.instance
                    .collection('games')
                    .doc('2026-00696');
                batch.update(oldGameRef, {'status': 'PPD'});

                // 2. 9월 10일 재편성 경기 추가
                final newGameRef = FirebaseFirestore.instance
                    .collection('games')
                    .doc('2026-00846');
                batch.set(newGameRef, {
                  'season': 2026,
                  'dateTimeKst': Timestamp.fromDate(
                    DateTime(2026, 9, 10, 18, 30),
                  ),
                  'weekday': '목',
                  'homeTeam': '두산',
                  'awayTeam': '키움',
                  'stadium': '잠실야구장',
                  'status': '예정',
                  'inning': null,
                  'broadcast': null,
                  'doubleHeaderNo': null,
                  'note': null,
                  'gameType': 'KBO리그',
                  'homeScore': 0,
                  'awayScore': 0,
                }, SetOptions(merge: true));

                // 3. 9월 11일 기아 vs SSG 광주 경기 추가
                final newGameRef2 = FirebaseFirestore.instance
                    .collection('games')
                    .doc('2026-00847');
                batch.set(newGameRef2, {
                  'season': 2026,
                  'dateTimeKst': Timestamp.fromDate(
                    DateTime(2026, 9, 11, 18, 30),
                  ),
                  'weekday': '금',
                  'homeTeam': '기아',
                  'awayTeam': 'SSG',
                  'stadium': '광주기아챔피언스필드',
                  'status': '예정',
                  'inning': null,
                  'broadcast': null,
                  'doubleHeaderNo': null,
                  'note': null,
                  'gameType': 'KBO리그',
                  'homeScore': 0,
                  'awayScore': 0,
                }, SetOptions(merge: true));

                await batch.commit();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('주말 경기 시간 변경, 9/10 두산-키움 및 9/11 기아-SSG 경기 추가 완료!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('에러 발생: $e')));
                }
              }
            },
            icon: const Icon(Icons.build, color: Colors.red),
            tooltip: '주말 경기 시간 변경 및 9/10, 9/11 경기 추가',
          ),
          IconButton(
            onPressed: () => _showAddGameDialog(context),
            icon: const Icon(Icons.add_circle, color: BUTTON),
            tooltip: '새 경기 일정 직접 추가 (결승전 등)',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BUTTON,
        onPressed: () => _showAddGameDialog(context),
        icon: const Icon(Icons.add, color: WHITE),
        label: const Text(
          '새 경기 일정 추가',
          style: TextStyle(color: WHITE, fontWeight: FontWeight.bold),
        ),
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
                      final game = games[index];
                      return _buildGameCard(game);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddGameDialog(BuildContext context) {
    DateTime gameDate = _selectedDate;
    TimeOfDay gameTime = const TimeOfDay(hour: 18, minute: 30);
    String homeTeam = '대한민국';
    String awayTeam = '일본';
    String stadium = '나고야';
    String gameType = '아시안게임';
    String status = '예정';

    final homeController = TextEditingController(text: homeTeam);
    final awayController = TextEditingController(text: awayTeam);
    final stadiumController = TextEditingController(text: stadium);
    final gameTypeController = TextEditingController(text: gameType);

    final List<String> teamOptions = [
      '대한민국',
      '일본',
      '대만',
      '태국',
      '홍콩',
      '중국',
      '체코',
      '호주',
      '도미니카',
      '쿠바',
      '두산',
      '삼성',
      '롯데',
      '기아',
      'LG',
      'SSG',
      '한화',
      '키움',
      'NC',
      'KT',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BACKGROUND_COLOR,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '새 경기 일정 직접 추가',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 날짜 & 시간 선택
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: gameDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  gameDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '경기 날짜',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(gameDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: gameTime,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  gameTime = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '경기 시간',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                '${gameTime.hour.toString().padLeft(2, '0')}:${gameTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 홈팀 선택
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: homeController,
                            decoration: const InputDecoration(
                              labelText: '홈팀',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down_circle),
                          onSelected: (val) {
                            setModalState(() {
                              homeController.text = val;
                            });
                          },
                          itemBuilder: (context) => teamOptions
                              .map((t) => PopupMenuItem(value: t, child: Text(t)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 원정팀 선택
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: awayController,
                            decoration: const InputDecoration(
                              labelText: '원정팀',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.arrow_drop_down_circle),
                          onSelected: (val) {
                            setModalState(() {
                              awayController.text = val;
                            });
                          },
                          itemBuilder: (context) => teamOptions
                              .map((t) => PopupMenuItem(value: t, child: Text(t)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 구장 & 대회명
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stadiumController,
                            decoration: const InputDecoration(
                              labelText: '구장 (예: 나고야, 잠실)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: gameTypeController,
                            decoration: const InputDecoration(
                              labelText: '대회/리그 (예: 아시안게임)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BUTTON,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final hTeam = homeController.text.trim();
                          final aTeam = awayController.text.trim();
                          final st = stadiumController.text.trim();
                          final gt = gameTypeController.text.trim();

                          if (hTeam.isEmpty || aTeam.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('홈팀과 원정팀을 입력해 주세요.')),
                            );
                            return;
                          }

                          final dt = DateTime(
                            gameDate.year,
                            gameDate.month,
                            gameDate.day,
                            gameTime.hour,
                            gameTime.minute,
                          );

                          final weekdayList = ['월', '화', '수', '목', '금', '토', '일'];
                          final weekdayStr = weekdayList[dt.weekday - 1];

                          final scheduleProvider = context.read<ScheduleProvider>();
                          int maxIdNum = 851;
                          for (var s in scheduleProvider.allSchedules) {
                            final parts = s.gameId.split('-');
                            if (parts.length == 2) {
                              final numVal = int.tryParse(parts[1]);
                              if (numVal != null && numVal > maxIdNum) {
                                maxIdNum = numVal;
                              }
                            }
                          }
                          final newIdNum = (maxIdNum + 1).toString().padLeft(5, '0');
                          final newGameId = '${dt.year}-$newIdNum';

                          try {
                            await FirebaseFirestore.instance
                                .collection('games')
                                .doc(newGameId)
                                .set({
                              'season': dt.year,
                              'dateTimeKst': Timestamp.fromDate(dt),
                              'weekday': weekdayStr,
                              'homeTeam': hTeam,
                              'awayTeam': aTeam,
                              'stadium': st,
                              'status': status,
                              'inning': null,
                              'broadcast': null,
                              'doubleHeaderNo': null,
                              'note': null,
                              'gameType': gt,
                              'homeScore': 0,
                              'awayScore': 0,
                            }, SetOptions(merge: true));

                            if (mounted) {
                              setState(() {
                                _selectedDate = dt;
                              });
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '새 경기($hTeam vs $aTeam)가 Firestore에 추가되었습니다!\n앱 업데이트 없이 모든 유저에게 즉시 반영됩니다.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('추가 실패: $e')),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Firestore에 새 경기 추가 (앱 전체 즉시 연동)',
                          style: TextStyle(
                            color: WHITE,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
