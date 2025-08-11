import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  const int season = 2025;
  final String inputPath = args.isNotEmpty
      ? args.first
      : 'assets/schedules/kbo_2025_schedule_full.csv';
  final String outputPath = args.length > 1
      ? args[1]
      : 'assets/schedules/kbo_2025.csv';

  final Map<String, String> stadiumMap = {
    '잠실': '잠실야구장',
    '고척': '고척스카이돔',
    '문학': '인천SSG랜더스필드',
    '수원': '수원KT위즈파크',
    '대전': '한화이글스파크',
    '대구': '대구라이온즈파크',
    '광주': '광주기아챔피언스필드',
    '사직': '사직야구장',
    '창원': '창원NC파크',
  };

  final Map<String, String> teamMap = {
    '두산': '두산베어스',
    '삼성': '삼성라이온즈',
    '롯데': '롯데자이언츠',
    'KIA': '기아타이거즈',
    'LG': 'LG트윈스',
    'SSG': 'SSG랜더스',
    '한화': '한화이글스',
    '키움': '키움히어로즈',
    'NC': 'NC다이노스',
    'KT': 'KT위즈',
  };

  List<String> lines;
  try {
    lines = await File(inputPath).readAsLines(encoding: utf8);
  } catch (e) {
    stderr.writeln('입력 파일을 읽을 수 없습니다: $inputPath, error: $e');
    exit(1);
  }

  // 동적으로 stadium 인덱스를 추출
  Map<int, String> colIndexToStadium = {};

  // 출력 헤더
  final List<List<String>> out = [
    [
      'season',
      'game_id',
      'date',
      'weekday',
      'time',
      'home_team',
      'away_team',
      'stadium',
      'status',
      'broadcast',
      'doubleheader_no',
      'note',
    ],
  ];

  int seq = 1;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final List<String> cells = line.split(',');

    // 첫 줄의 인덱스 행(0,1,2,...) 또는 너무 짧은 행은 스킵
    if (cells.length < 4) continue;
    if (cells.first == '0' && cells[1] == '1') continue;

    // 헤더 행 감지: 월,일,요일,잠실,고척,...
    if (cells[0] == '월' && cells[1] == '일') {
      colIndexToStadium.clear();
      for (int i = 0; i < cells.length; i++) {
        final key = cells[i];
        if (stadiumMap.containsKey(key)) {
          colIndexToStadium[i] = stadiumMap[key]!;
        }
      }
      continue;
    }

    // 미편성 블록은 스킵
    if (cells[0] == '구분' || cells[0] == '미편성') {
      continue;
    }

    // 날짜 파싱 (월,일)
    final String monthStr = cells[0];
    final String dayStr = cells[1];
    final String weekday = cells[2];
    if (monthStr == '월' || dayStr == '일') continue; // 안전장치

    final int? month = int.tryParse(monthStr);
    final int? day = int.tryParse(dayStr);
    if (month == null || day == null) continue;

    final String date =
        '${season.toString()}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final String time = _computeTimeFor(
      date: date,
      month: month,
      day: day,
      weekday: weekday,
    );

    // 각 구장 컬럼 순회
    for (final entry in colIndexToStadium.entries) {
      final int colIdx = entry.key;
      final String stadiumName = entry.value;
      if (colIdx >= cells.length) continue;
      final String v = cells[colIdx].trim();
      if (v.isEmpty) continue;
      if (v.contains('올스타')) {
        // 올스타 브레이크 같은 특수 표기는 스킵
        continue;
      }

      // 형식: "원정-홈" 기준으로 파싱
      final List<String> parts = v.split('-').map((e) => e.trim()).toList();
      if (parts.length != 2) continue;
      final String awayAbbr = parts[0];
      final String homeAbbr = parts[1];

      final String? homeTeam = teamMap[homeAbbr];
      final String? awayTeam = teamMap[awayAbbr];
      if (homeTeam == null || awayTeam == null) continue;

      final String gameId =
          '${season.toString()}-${seq.toString().padLeft(4, '0')}';
      seq++;

      out.add([
        season.toString(),
        gameId,
        date,
        weekday,
        time,
        homeTeam,
        awayTeam,
        stadiumName,
        'SCHEDULED',
        '',
        '',
        '',
      ]);
    }
  }

  // 파일로 저장
  final sink = File(outputPath).openWrite(encoding: utf8);
  for (final row in out) {
    sink.writeln(row.map(_csvCell).join(','));
  }
  await sink.flush();
  await sink.close();

  stdout.writeln('변환 완료: ${out.length - 1}경기 → $outputPath');
}

String _csvCell(String v) {
  if (v.contains(',') || v.contains('"')) {
    return '"' + v.replaceAll('"', '""') + '"';
  }
  return v;
}

bool _isWeekendKST(String weekday) {
  // 요일: 월,화,수,목,금,토,일 중 주말 판별
  return weekday.contains('토') || weekday.contains('일');
}

String _computeTimeFor({
  required String date,
  required int month,
  required int day,
  required String weekday,
}) {
  // 규칙:
  // - 평일 18:30
  // - 주말 14:00
  // - 6월 1일 이후 주말경기 17:00
  // - 7월부터 주말경기 18:00
  final bool isWeekend = _isWeekendKST(weekday);
  if (!isWeekend) return '18:30';

  // 주말
  if (month < 6) return '14:00';
  if (month == 6) {
    if (day >= 1) return '17:00';
    return '14:00';
  }
  // 7월 이상
  return '18:00';
}
