import 'package:flutter/material.dart';

class QuizTierUtils {
  static String getTierName(int score) {
    if (score >= 10000) return 'LEGEND';
    if (score >= 5000) return 'MVP';
    if (score >= 2500) return 'ALL-STAR';
    if (score >= 1200) return 'MAJOR';
    if (score >= 400) return 'MINOR';
    return 'PROSPECT';
  }

  static String getTierEmblem(String tier) {
    switch (tier) {
      case 'LEGEND':
        return 'assets/images/quiz/quiz_emblem_legend.png';
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
      case 'LEGEND':
        return const Color.fromARGB(255, 149, 124, 59); // Radiant Gold
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
    if (score >= 10000) {
      return TierProgress(
        currentTier: 'LEGEND',
        nextTier: '',
        nextTierScore: 10000,
        progress: 1.0,
        remainingScore: 0,
      );
    } else if (score >= 5000) {
      return TierProgress(
        currentTier: 'MVP',
        nextTier: 'LEGEND',
        nextTierScore: 10000,
        progress: (score - 5000) / (10000 - 5000),
        remainingScore: 10000 - score,
      );
    } else if (score >= 2500) {
      return TierProgress(
        currentTier: 'ALL-STAR',
        nextTier: 'MVP',
        nextTierScore: 5000,
        progress: (score - 2500) / (5000 - 2500),
        remainingScore: 5000 - score,
      );
    } else if (score >= 1200) {
      return TierProgress(
        currentTier: 'MAJOR',
        nextTier: 'ALL-STAR',
        nextTierScore: 2500,
        progress: (score - 1200) / (2500 - 1200),
        remainingScore: 2500 - score,
      );
    } else if (score >= 400) {
      return TierProgress(
        currentTier: 'MINOR',
        nextTier: 'MAJOR',
        nextTierScore: 1200,
        progress: (score - 400) / (1200 - 400),
        remainingScore: 1200 - score,
      );
    } else {
      return TierProgress(
        currentTier: 'PROSPECT',
        nextTier: 'MINOR',
        nextTierScore: 400,
        progress: score / 400,
        remainingScore: 400 - score,
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
