class QuizQuestionModel {
  final String quizId;
  final String category;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String difficulty;
  final String explanation;
  final String? imageUrl;

  QuizQuestionModel({
    required this.quizId,
    required this.category,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    required this.explanation,
    this.imageUrl,
  });

  // json 변환 (나중을 위해)
  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'category': category,
      'options': options,
      'correctIndex': correctIndex,
      'difficulty': difficulty,
      'explanation': explanation,
      'imageUrl': imageUrl,
    };
  }

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      quizId: json['quizId'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctIndex: json['correctIndex'] as int,
      difficulty: json['difficulty'] as String,
      explanation: json['explanation'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  // 복사본 생성
  QuizQuestionModel copyWith({
    String? quizId,
    String? category,
    String? question,
    List<String>? options,
    int? correctIndex,
    String? difficulty,
    String? explanation,
    String? imageUrl,
  }) {
    return QuizQuestionModel(
      quizId: quizId ?? this.quizId,
      category: category ?? this.category,
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      difficulty: difficulty ?? this.difficulty,
      explanation: explanation ?? this.explanation,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
