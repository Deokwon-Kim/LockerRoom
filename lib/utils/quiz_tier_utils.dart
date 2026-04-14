import 'package:flutter/material.dart';

class QuizTierUtils {
  static String getTierName(int score) {
    if (score >= 3000) return 'MVP';
    if (score >= 1500) return 'ALL-STAR';
    if (score >= 700) return 'MAJOR';
    if (score >= 200) return 'MINOR';
    return 'PROSPECT';
  }

  static String getTierEmblem(String tier) {
    switch (tier) {
      case 'MVP':
        return 'assets/images/quiz/quiz_emblem_mvp.png';
      case 'ALL-STAR':
        return 'assets/images/quiz/quiz_emblem_allstar.png';
      case 'MAJOR':
        return 'assets/images/quiz/quiz_emblem_major.png';
      case 'MINOR':
        return 'assets/images/quiz/quiz_emblem_minor.png';
      default:
        return 'assets/images/quiz/quiz_emblem_prospect.png';
    }
  }

  static Color getTierColor(String tier) {
    switch (tier) {
      case 'MVP':
        return const Color(0xFFB19CD9); // Diamond Purple
      case 'ALL-STAR':
        return const Color(0xFFFF4D4D); // Platinum Red
      case 'MAJOR':
        return const Color(0xFFFFD700); // Gold
      case 'MINOR':
        return const Color(0xFFC0C0C0); // Silver
      default:
        return const Color(0xFFCD7F32); // Bronze
    }
  }

  static TierProgress getTierProgress(int score) {
    if (score >= 3000) {
      return TierProgress(
        currentTier: 'MVP',
        nextTier: 'LEGEND', // MVP 이후의 목표(명예직)
        nextTierScore: 5000,
        progress: 1.0,
        remainingScore: 0,
      );
    } else if (score >= 1500) {
      return TierProgress(
        currentTier: 'ALL-STAR',
        nextTier: 'MVP',
        nextTierScore: 3000,
        progress: (score - 1500) / (3000 - 1500),
        remainingScore: 3000 - score,
      );
    } else if (score >= 700) {
      return TierProgress(
        currentTier: 'MAJOR',
        nextTier: 'ALL-STAR',
        nextTierScore: 1500,
        progress: (score - 700) / (1500 - 700),
        remainingScore: 1500 - score,
      );
    } else if (score >= 200) {
      return TierProgress(
        currentTier: 'MINOR',
        nextTier: 'MAJOR',
        nextTierScore: 700,
        progress: (score - 200) / (700 - 200),
        remainingScore: 700 - score,
      );
    } else {
      return TierProgress(
        currentTier: 'PROSPECT',
        nextTier: 'MINOR',
        nextTierScore: 200,
        progress: score / 200,
        remainingScore: 200 - score,
      );
    }
  }
}

class TierProgress {
  final String currentTier;
  final String nextTier;
  final int nextTierScore;
  final double progress;
  final int remainingScore;

  TierProgress({
    required this.currentTier,
    required this.nextTier,
    required this.nextTierScore,
    required this.progress,
    required this.remainingScore,
  });
}
