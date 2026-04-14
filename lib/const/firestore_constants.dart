import 'package:flutter/foundation.dart';

class FirestoreConstants {
  /// 퀴즈 문제 컬렉션 (운영: quizzes / 테스트: quizzes_test)
  static String get quizzes => kDebugMode ? 'quizzes_test' : 'quizzes';

  /// 퀴즈 결과 루트 컬렉션 (운영: quiz_results / 테스트: quiz_results_test)
  static String get quizResults => kDebugMode ? 'quiz_results_test' : 'quiz_results';

  /// 퀴즈 결과 서브 컬렉션 (운영: results / 테스트: results_test)
  /// collectionGroup 쿼리 시 환경 분리를 위해 필요합니다.
  static String get quizResultsSub => kDebugMode ? 'results_test' : 'results';
  
  /// 퀴즈 챔피언(트로피) 컬렉션
  static String get trophies => kDebugMode ? 'quiz_champions_test' : 'quiz_champions';

  /// 필요 시 사용자 데이터 등에 대해서도 세분화 가능
  // static String get users => kDebugMode ? 'users_test' : 'users';
}
