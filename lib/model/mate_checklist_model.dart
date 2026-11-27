import 'package:flutter/material.dart';

class MateQuestionDef {
  final String key;
  final String title;
  final bool multiSelect;
  final List<String> options;

  const MateQuestionDef({
    required this.key,
    required this.title,
    required this.multiSelect,
    required this.options,
  });
}

class MateChecklistModel {
  final String team;
  final String age;
  final String gender;
  final int highlightColorValue;
  final Map<String, List<String>> answers;

  const MateChecklistModel({
    this.team = '두산',
    this.age = '20~24',
    this.gender = '남자',
    this.highlightColorValue = 0xFFFB7185,
    this.answers = const {},
  });

  Color get highlightColor => Color(highlightColorValue);

  static const List<int> highlightPresets = [
    0xFFFB7185, // 코랄 핑크
    0xFFFACC15, // 레몬 옐로우
    0xFF4ADE80, // 민트 그린
    0xFF38BDF8, // 스카이 블루
    0xFFC084FC, // 라벤더 퍼플
  ];

  static const List<String> teamOptions = [
    'LG', '한화', 'SSG', '삼성', 'NC', 'KT', '롯데', 'KIA', '두산', '키움',
  ];

  static const List<String> ageOptions = [
    '~19', '20~24', '25~29', '30~34', '35~39', '40+', '50+', '60+',
  ];

  static const List<String> genderOptions = ['남자', '여자'];

  static const List<MateQuestionDef> questions = [
    MateQuestionDef(
      key: 'smoke',
      title: '1. 본인 흡연여부',
      multiSelect: false,
      options: ['O', 'X'],
    ),
    MateQuestionDef(
      key: 'dist',
      title: '2. 본인이 추구하는 관계거리',
      multiSelect: false,
      options: ['가까운', '중간', '먼'],
    ),
    MateQuestionDef(
      key: 'genderPref',
      title: '3. 본인이 추구하는 성별',
      multiSelect: false,
      options: ['동성', '이성', '무관'],
    ),
    MateQuestionDef(
      key: 'gear',
      title: '4. 본인이 평소 응원하는 모습',
      multiSelect: true,
      options: ['유니폼', '응원배트(짝짝이)', '수건', '머리띠'],
    ),
    MateQuestionDef(
      key: 'seat',
      title: '5. 본인이 추구하는 자리',
      multiSelect: true,
      options: ['응원단석', '내야', '외야', '잔디', '탁자', '중앙', '포후'],
    ),
    MateQuestionDef(
      key: 'style1',
      title: '6. 본인 직관스타일 1',
      multiSelect: true,
      options: ['안무', '응원가', '육성', '일어서서', '앉아서'],
    ),
    MateQuestionDef(
      key: 'style2',
      title: '7. 본인 직관스타일 2',
      multiSelect: false,
      options: ['끝까지 본다', '끝까지 안 본다'],
    ),
    MateQuestionDef(
      key: 'style3',
      title: '8. 본인 직관스타일 3',
      multiSelect: false,
      options: ['경기만 집중', '이야기하면서 보는 편'],
    ),
    MateQuestionDef(
      key: 'photo',
      title: '9. 사진기록',
      multiSelect: false,
      options: ['O', 'X'],
    ),
    MateQuestionDef(
      key: 'awayHome',
      title: '10. 홈구장에서 원정석 or 원정구장에서 홈석',
      multiSelect: false,
      options: ['O', 'X'],
    ),
    MateQuestionDef(
      key: 'after',
      title: '11. 뒷풀이',
      multiSelect: false,
      options: ['O', 'X'],
    ),
    MateQuestionDef(
      key: 'rain',
      title: '12. 우천 시',
      multiSelect: false,
      options: ['일단 간다', '상황보고'],
    ),
    MateQuestionDef(
      key: 'size',
      title: '13. 인원',
      multiSelect: false,
      options: ['많을수록 좋다', '소수정예(4명이하)'],
    ),
    MateQuestionDef(
      key: 'food',
      title: '14. 음식여부',
      multiSelect: false,
      options: ['O', 'X'],
    ),
  ];

  factory MateChecklistModel.defaults({String team = '두산'}) {
    return MateChecklistModel(
      team: team,
      age: '20~24',
      gender: '남자',
      highlightColorValue: 0xFFFB7185,
      answers: const {
        'smoke': ['X'],
        'dist': ['가까운'],
        'genderPref': ['동성'],
        'gear': ['유니폼', '응원배트(짝짝이)'],
        'seat': ['응원단석', '내야'],
        'style1': ['안무', '응원가', '육성'],
        'style2': ['끝까지 본다'],
        'style3': ['이야기하면서 보는 편'],
        'photo': ['O'],
        'awayHome': ['X'],
        'after': ['O'],
        'rain': ['일단 간다'],
        'size': ['소수정예(4명이하)'],
        'food': ['O'],
      },
    );
  }

  factory MateChecklistModel.fromMap(Map<String, dynamic> map) {
    final rawAnswers = map['answers'] as Map<String, dynamic>? ?? {};
    final parsedAnswers = <String, List<String>>{};
    rawAnswers.forEach((k, v) {
      if (v is List) {
        parsedAnswers[k] = v.map((e) => e.toString()).toList();
      } else if (v is String && v.isNotEmpty) {
        parsedAnswers[k] = [v];
      }
    });

    return MateChecklistModel(
      team: (map['team'] ?? '두산').toString(),
      age: (map['age'] ?? '20~24').toString(),
      gender: (map['gender'] ?? '남자').toString(),
      highlightColorValue:
          (map['highlightColorValue'] as num?)?.toInt() ?? 0xFFFB7185,
      answers: parsedAnswers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'team': team,
      'age': age,
      'gender': gender,
      'highlightColorValue': highlightColorValue,
      'answers': answers,
    };
  }

  MateChecklistModel copyWith({
    String? team,
    String? age,
    String? gender,
    int? highlightColorValue,
    Map<String, List<String>>? answers,
  }) {
    return MateChecklistModel(
      team: team ?? this.team,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
      answers: answers ?? this.answers,
    );
  }

  bool get isNonSmoke => answers['smoke']?.contains('X') ?? false;
  bool get isSmallGroupPreferred =>
      answers['size']?.contains('소수정예(4명이하)') ?? false;
  bool get isWatchUntilEnd => answers['style2']?.contains('끝까지 본다') ?? false;

  /// 핵심 성향 태그 목록 (직관모임 카드/상세 표시용)
  List<String> toSummaryTags({int maxTags = 5}) {
    final tags = <String>[];
    if (isSmallGroupPreferred) tags.add('#소수정예');
    if (isNonSmoke) tags.add('#비흡연');
    final seats = answers['seat'] ?? const [];
    for (final s in seats.take(2)) {
      tags.add('#$s');
    }
    if (isWatchUntilEnd) tags.add('#끝까지봄');
    if (answers['photo']?.contains('O') ?? false) tags.add('#사진OK');
    if (answers['after']?.contains('O') ?? false) tags.add('#뒷풀이OK');
    return tags.take(maxTags).toList();
  }

  /// 두 체크리스트 간 성향 일치율 (0 ~ 100%)
  int calculateMatchPercent(MateChecklistModel other) {
    const compareKeys = [
      'smoke',
      'dist',
      'seat',
      'style1',
      'style2',
      'style3',
      'photo',
      'after',
      'rain',
      'size',
      'food',
    ];

    int compared = 0;
    double score = 0;

    for (final key in compareKeys) {
      final a = answers[key] ?? const [];
      final b = other.answers[key] ?? const [];
      if (a.isEmpty || b.isEmpty) continue;
      compared++;
      final overlap = a.toSet().intersection(b.toSet());
      if (overlap.isNotEmpty) {
        score += 1.0;
      }
    }

    if (compared == 0) return 0;
    return ((score / compared) * 100).round().clamp(0, 100);
  }
}
