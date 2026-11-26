import 'package:flutter/material.dart';

class BattingTierCriteria {
  final String tierName;
  final int minHits;
  final double minAvg;

  const BattingTierCriteria({
    required this.tierName,
    required this.minHits,
    required this.minAvg,
  });
}

class BattingTierProgress {
  final String currentTier;
  final String nextTier;
  final int currentHits;
  final double currentAvg;
  final int requiredHits;
  final double requiredAvg;
  final int remainingHits;
  final bool isAvgMet;
  final double progress;

  const BattingTierProgress({
    required this.currentTier,
    required this.nextTier,
    required this.currentHits,
    required this.currentAvg,
    required this.requiredHits,
    required this.requiredAvg,
    required this.remainingHits,
    required this.isAvgMet,
    required this.progress,
  });

  String get statusMessage {
    if (nextTier.isEmpty) return '최고 티어 LEGEND 달성!';
    final avgStr = requiredAvg >= 1.0
        ? '1.000'
        : '.${(requiredAvg * 1000).round().toString().padLeft(3, '0')}';
    if (remainingHits > 0 && !isAvgMet) {
      return '$nextTier까지 $remainingHits안타 · 타율 $avgStr 필요';
    }
    if (remainingHits > 0) {
      return '$nextTier까지 $remainingHits안타 남음 (타율 충족 ✓)';
    }
    return '타율 $avgStr 달성 시 $nextTier 승급';
  }
}

class QuizTierUtils {
  static const List<BattingTierCriteria> battingTierCriteria = [
    BattingTierCriteria(tierName: 'PROSPECT', minHits: 0, minAvg: 0.0),
    BattingTierCriteria(tierName: 'MINOR', minHits: 15, minAvg: 0.400),
    BattingTierCriteria(tierName: 'MAJOR', minHits: 40, minAvg: 0.500),
    BattingTierCriteria(tierName: 'ALL-STAR', minHits: 80, minAvg: 0.600),
    BattingTierCriteria(tierName: 'MVP', minHits: 150, minAvg: 0.700),
    BattingTierCriteria(tierName: 'LEGEND', minHits: 250, minAvg: 0.800),
  ];

  static String getTierByBattingStats(int totalHits, double battingAvg) {
    for (int i = battingTierCriteria.length - 1; i >= 0; i--) {
      final c = battingTierCriteria[i];
      if (totalHits >= c.minHits && battingAvg >= c.minAvg) {
        return c.tierName;
      }
    }
    return 'PROSPECT';
  }

  static BattingTierProgress getBattingTierProgress(
    int totalHits,
    double battingAvg,
  ) {
    int currentIdx = 0;
    for (int i = battingTierCriteria.length - 1; i >= 0; i--) {
      final c = battingTierCriteria[i];
      if (totalHits >= c.minHits && battingAvg >= c.minAvg) {
        currentIdx = i;
        break;
      }
    }

    final current = battingTierCriteria[currentIdx];
    if (currentIdx >= battingTierCriteria.length - 1) {
      return BattingTierProgress(
        currentTier: current.tierName,
        nextTier: '',
        currentHits: totalHits,
        currentAvg: battingAvg,
        requiredHits: current.minHits,
        requiredAvg: current.minAvg,
        remainingHits: 0,
        isAvgMet: true,
        progress: 1.0,
      );
    }

    final next = battingTierCriteria[currentIdx + 1];
    final remainingHits = (next.minHits - totalHits).clamp(0, next.minHits);
    final isAvgMet = battingAvg >= next.minAvg;
    final hitRatio = next.minHits > current.minHits
        ? ((totalHits - current.minHits) / (next.minHits - current.minHits))
              .clamp(0.0, 1.0)
        : 1.0;
    final avgRatio = next.minAvg > 0
        ? (battingAvg / next.minAvg).clamp(0.0, 1.0)
        : 1.0;
    final progress = (hitRatio * 0.6 + avgRatio * 0.4).clamp(0.0, 1.0);

    return BattingTierProgress(
      currentTier: current.tierName,
      nextTier: next.tierName,
      currentHits: totalHits,
      currentAvg: battingAvg,
      requiredHits: next.minHits,
      requiredAvg: next.minAvg,
      remainingHits: remainingHits,
      isAvgMet: isAvgMet,
      progress: progress,
    );
  }

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
