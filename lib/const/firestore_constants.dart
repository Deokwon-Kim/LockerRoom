class FirestoreConstants {
  /// 테스트 컬렉션 분리 사용 여부
  /// (Firestore 보안 규칙, Cloud Function 트리거 및 인덱스가 운영 컬렉션('results') 기준으로 설정되어 있으므로 기본 false)
  static const bool useTestCollections = false;

  /// 퀴즈 문제 컬렉션 (운영: quizzes / 테스트: quizzes_test)
  static String get quizzes => useTestCollections ? 'quizzes_test' : 'quizzes';

  /// 퀴즈 결과 루트 컬렉션 (운영: quiz_results / 테스트: quiz_results_test)
  static String get quizResults =>
      useTestCollections ? 'quiz_results_test' : 'quiz_results';

  /// 퀴즈 결과 서브 컬렉션 (운영: results / 테스트: results_test)
  /// collectionGroup 쿼리 시 환경 분리를 위해 필요합니다.
  static String get quizResultsSub =>
      useTestCollections ? 'results_test' : 'results';

  /// 퀴즈 챔피언(트로피) 컬렉션
  static String get trophies =>
      useTestCollections ? 'quiz_champions_test' : 'quiz_champions';

  /// 필요 시 사용자 데이터 등에 대해서도 세분화 가능
  // static String get users => kDebugMode ? 'users_test' : 'users';
}
