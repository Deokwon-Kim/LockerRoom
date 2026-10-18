import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/page/intution_record/_record_card.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class AllUsersIntutionRecordPage extends StatefulWidget {
  const AllUsersIntutionRecordPage({super.key});

  @override
  State<AllUsersIntutionRecordPage> createState() =>
      _AllUsersIntutionRecordPageState();
}

class _AllUsersIntutionRecordPageState
    extends State<AllUsersIntutionRecordPage> {
  // Timestamp → DateTime 변환 헬퍼
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // imageUrls 처리: 기존 단일 imageUrl과 새로운 imageUrls 모두 지원
  List<String> _parseImageUrls(Map<String, dynamic> data) {
    if (data['imageUrls'] != null && data['imageUrls'] is List) {
      return List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null &&
        data['imageUrl'].toString().isNotEmpty) {
      return [data['imageUrl'].toString()];
    }
    return [];
  }

  AttendanceModel _toAttendance(Map<String, dynamic> data) {
    return AttendanceModel(
      gameId: data['gameId'],
      season: data['season'],
      date: data['date'],
      time: data['time'],
      stadium: data['stadium'],
      homeTeam: data['homeTeam'],
      awayTeam: data['awayTeam'],
      myTeam: data['myTeam'],
      oppTeam: data['oppTeam'],
      myScore: data['myScore'],
      opponentScore: data['opponentScore'],
      imageUrls: _parseImageUrls(data),
      memo: data['memo'],
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        backgroundColor: BACKGROUND_COLOR,
        title: const Text(
          '[개발자용] 모든 유저 직관기록',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        // 🔥 핵심: collectionGroup을 사용하여 모든 유저의 attendances 컬렉션을 조회합니다.
        future: FirebaseFirestore.instance
            .collectionGroup('attendances')
            .orderBy('createdAt', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  '데이터를 불러오는 중 오류가 발생했습니다.\n\n(최초 실행 시 디버그 콘솔창의 링크를 클릭해 Firebase 인덱스를 생성해주세요!)\n\n에러 내용:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('저장된 직관 기록이 없습니다'));
          }

          // 직관 기록을 남긴 총 유저 수 계산 (Set을 이용해서 중복 제거)
          final Set<String> uniqueUsers = {};
          for (var doc in docs) {
            final userId = doc.reference.parent.parent?.id;
            if (userId != null) {
              uniqueUsers.add(userId);
            }
          }

          return Column(
            children: [
              // 통계 요약 (총 기록 수 및 사용 유저 수)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '총 누적 기록: ${docs.length}개',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '직관 남긴 유저: ${uniqueUsers.length}명',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // 리스트 뷰
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final attendance = _toAttendance(d);

                    // 이 기록의 주인(유저) uid를 알고 싶다면:
                    final String userId =
                        docs[i].reference.parent.parent?.id ?? '알수없음';

                    final myTeam = d['myTeam'] ?? '';
                    final oppTeam = d['oppTeam'] ?? '';
                    final myScore = d['myScore'] ?? 0;
                    final oppScore = d['opponentScore'] ?? 0;
                    final isWin = myScore > oppScore;

                    final tp = Provider.of<TeamProvider>(
                      context,
                      listen: false,
                    );
                    final team = tp.findTeamByName(myTeam);
                    final color = team?.color ?? GRAYSCALE_LABEL_500;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 누구의 기록인지 표시하는 부분
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0, left: 20),
                          child: Text(
                            '👤 User ID: $userId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: GRAYSCALE_LABEL_500,
                            ),
                          ),
                        ),
                        // 기존 뷰에서 사용하던 카드를 그대로 재활용
                        RecordCard(
                          data: d,
                          attendance: attendance,
                          recordedTeam: team,
                          recordedTeamColor: color,
                          isWin: isWin,
                          myScore: myScore,
                          oppScore: oppScore,
                          myTeam: myTeam,
                          oppTeam: oppTeam,
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
