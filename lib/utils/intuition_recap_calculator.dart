import 'dart:math';

class KboStadiumMeta {
  final String code;
  final String displayName;
  final double lat;
  final double lng;
  final bool isJapan;

  const KboStadiumMeta({
    required this.code,
    required this.displayName,
    required this.lat,
    required this.lng,
    this.isJapan = false,
  });
}

class RecapStep {
  final int index;
  final String stadiumCode;
  final String stadiumDisplayName;
  final String? prevStadiumCode;
  final double stepDistanceKm;
  final double cumulativeDistanceKm;
  final String date;
  final String oppTeam;
  final String result;
  final List<String> imageUrls;

  const RecapStep({
    required this.index,
    required this.stadiumCode,
    required this.stadiumDisplayName,
    required this.prevStadiumCode,
    required this.stepDistanceKm,
    required this.cumulativeDistanceKm,
    required this.date,
    required this.oppTeam,
    required this.result,
    this.imageUrls = const [],
  });
}

class StadiumRankItem {
  final String code;
  final String displayName;
  final int count;

  const StadiumRankItem({
    required this.code,
    required this.displayName,
    required this.count,
  });
}

class RecapSnapshot {
  final int gamesCount;
  final int visitedStadiumCount;
  final int totalDistanceKm;
  final Map<String, int> stadiumVisits;
  final List<StadiumRankItem> top3Stadiums;
  final RecapStep? currentStep;
  final double stepFraction;

  const RecapSnapshot({
    required this.gamesCount,
    required this.visitedStadiumCount,
    required this.totalDistanceKm,
    required this.stadiumVisits,
    required this.top3Stadiums,
    required this.currentStep,
    this.stepFraction = 1.0,
  });
}

class IntuitionRecapData {
  final List<RecapStep> steps;
  final int totalGames;
  final int totalVisitedStadiums;
  final int totalDistanceKm;
  final int wins;
  final int losses;
  final int draws;
  final bool hasJapanVisit;
  final List<StadiumRankItem> top3Stadiums;

  const IntuitionRecapData({
    required this.steps,
    required this.totalGames,
    required this.totalVisitedStadiums,
    required this.totalDistanceKm,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.hasJapanVisit,
    required this.top3Stadiums,
  });

  static const Map<String, KboStadiumMeta> stadiums = {
    '잠실': KboStadiumMeta(
      code: '잠실',
      displayName: '잠실야구장',
      lat: 37.5122,
      lng: 127.0719,
    ),
    '고척': KboStadiumMeta(
      code: '고척',
      displayName: '고척 스카이돔',
      lat: 37.4982,
      lng: 126.8671,
    ),
    '문학': KboStadiumMeta(
      code: '문학',
      displayName: '인천 SSG 랜더스필드',
      lat: 37.4370,
      lng: 126.6933,
    ),
    '수원': KboStadiumMeta(
      code: '수원',
      displayName: '수원 KT 위즈파크',
      lat: 37.2997,
      lng: 127.0097,
    ),
    '대전': KboStadiumMeta(
      code: '대전',
      displayName: '대전 한화생명 볼파크',
      lat: 36.3171,
      lng: 127.4291,
    ),
    '대구': KboStadiumMeta(
      code: '대구',
      displayName: '대구 삼성 라이온즈 파크',
      lat: 35.8410,
      lng: 128.6815,
    ),
    '광주': KboStadiumMeta(
      code: '광주',
      displayName: '광주-기아 챔피언스 필드',
      lat: 35.1683,
      lng: 126.8889,
    ),
    '사직': KboStadiumMeta(
      code: '사직',
      displayName: '사직야구장',
      lat: 35.1940,
      lng: 129.0615,
    ),
    '창원': KboStadiumMeta(
      code: '창원',
      displayName: '창원 NC 파크',
      lat: 35.2225,
      lng: 128.5822,
    ),
    // 일본 주요 구장 (국가대표/NPB 직관 대응)
    '도쿄돔': KboStadiumMeta(
      code: '도쿄돔',
      displayName: '도쿄 돔',
      lat: 35.7056,
      lng: 139.7519,
      isJapan: true,
    ),
    '교세라돔': KboStadiumMeta(
      code: '교세라돔',
      displayName: '오사카 교세라 돔',
      lat: 34.6693,
      lng: 135.4761,
      isJapan: true,
    ),
    '페이페이돔': KboStadiumMeta(
      code: '페이페이돔',
      displayName: '후쿠오카 PayPay 돔',
      lat: 33.5954,
      lng: 130.3621,
      isJapan: true,
    ),
    '나고야': KboStadiumMeta(
      code: '나고야',
      displayName: '반테린 돔 나고야',
      lat: 35.1860,
      lng: 136.9474,
      isJapan: true,
    ),
    '오카자기': KboStadiumMeta(
      code: '오카자기',
      displayName: '오카자기 구장',
      lat: 34.9547,
      lng: 137.1743,
      isJapan: true,
    ),
    '도요하시': KboStadiumMeta(
      code: '도요하시',
      displayName: '도요하시 시민구장',
      lat: 34.7739,
      lng: 137.4368,
      isJapan: true,
    ),
    '요코하마': KboStadiumMeta(
      code: '요코하마',
      displayName: '요코하마 스타디움',
      lat: 35.4433,
      lng: 139.6401,
      isJapan: true,
    ),
    '고시엔': KboStadiumMeta(
      code: '고시엔',
      displayName: '한신 고시엔 구장',
      lat: 34.7212,
      lng: 135.3616,
      isJapan: true,
    ),
    '미야자키': KboStadiumMeta(
      code: '미야자키',
      displayName: '미야자키 선마린 스타디움',
      lat: 31.8253,
      lng: 131.4488,
      isJapan: true,
    ),
    '오키나와': KboStadiumMeta(
      code: '오키나와',
      displayName: '오키나와 셀룰러 스타디움',
      lat: 26.2054,
      lng: 127.6697,
      isJapan: true,
    ),
  };

  static String? normalizeStadium(String raw) {
    if (raw.contains('잠실')) return '잠실';
    if (raw.contains('고척')) return '고척';
    if (raw.contains('문학') || raw.contains('인천') || raw.contains('랜더스')) {
      return '문학';
    }
    if (raw.contains('수원') || raw.contains('위즈')) return '수원';
    if (raw.contains('대전') || raw.contains('이글스') || raw.contains('볼파크')) {
      return '대전';
    }
    if (raw.contains('대구') || raw.contains('라이온즈')) return '대구';
    if (raw.contains('광주') || raw.contains('챔피언스')) return '광주';
    if (raw.contains('사직') || raw.contains('부산')) return '사직';
    if (raw.contains('창원') || raw.contains('마산') || raw.contains('NC')) {
      return '창원';
    }
    // 일본 구장 매핑
    if (raw.contains('도쿄') || raw.contains('Tokyo')) return '도쿄돔';
    if (raw.contains('교세라') || raw.contains('오사카')) return '교세라돔';
    if (raw.contains('후쿠오카') ||
        raw.contains('페이페이') ||
        raw.contains('PayPay')) {
      return '페이페이돔';
    }
    if (raw.contains('오카자기')) return '오카자기';
    if (raw.contains('도요하시')) return '도요하시';
    if (raw.contains('나고야') || raw.contains('반테린') || raw.contains('아이치')) {
      return '나고야';
    }
    if (raw.contains('요코하마')) return '요코하마';
    if (raw.contains('고시엔')) return '고시엔';
    if (raw.contains('미야자키')) return '미야자키';
    if (raw.contains('오키나와')) return '오키나와';
    if (raw.contains('일본')) return '도쿄돔';
    return null;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  factory IntuitionRecapData.fromRecords(List<Map<String, dynamic>> records) {
    final sorted = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) {
        final da = (a['date'] as String?) ?? '';
        final db = (b['date'] as String?) ?? '';
        final cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        final ta = (a['time'] as String?) ?? '';
        final tb = (b['time'] as String?) ?? '';
        return ta.compareTo(tb);
      });

    final List<RecapStep> steps = [];
    final Map<String, int> finalVisits = {};
    int wins = 0;
    int losses = 0;
    int draws = 0;

    String? prevCode;
    double cumulativeKm = 0;

    for (final item in sorted) {
      final result = (item['result'] as String?) ?? '';
      if (result.contains('승')) {
        wins++;
      } else if (result.contains('패')) {
        losses++;
      } else if (result.contains('무')) {
        draws++;
      }

      final rawStadium = (item['stadium'] as String?)?.trim() ?? '';
      final code = normalizeStadium(rawStadium);
      if (code == null) continue;

      final meta = stadiums[code]!;
      double stepKm = 0;

      if (prevCode == null) {
        // 첫 직관 이동 기본 왕복 거리 반영
        stepKm = 24;
      } else if (prevCode == code) {
        // 같은 구장 재방문 시 평균 시내 이동 왕복 반영
        stepKm = 24;
      } else {
        final prevMeta = stadiums[prevCode]!;
        stepKm = _haversineKm(prevMeta.lat, prevMeta.lng, meta.lat, meta.lng);
      }

      cumulativeKm += stepKm;
      finalVisits[code] = (finalVisits[code] ?? 0) + 1;

      final rawUrls = item['imageUrls'];
      final List<String> imageUrls = rawUrls is List
          ? rawUrls
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const [];

      steps.add(
        RecapStep(
          index: steps.length,
          stadiumCode: code,
          stadiumDisplayName: meta.displayName,
          prevStadiumCode: prevCode,
          stepDistanceKm: stepKm,
          cumulativeDistanceKm: cumulativeKm,
          date: (item['date'] as String?) ?? '',
          oppTeam: (item['oppTeam'] as String?) ?? '',
          result: result,
          imageUrls: imageUrls,
        ),
      );

      prevCode = code;
    }

    final top3 = _buildTop3(finalVisits);
    final hasJapanVisit = finalVisits.keys.any(
      (code) => stadiums[code]?.isJapan ?? false,
    );

    return IntuitionRecapData(
      steps: steps,
      totalGames: sorted.length,
      totalVisitedStadiums: finalVisits.length,
      totalDistanceKm: cumulativeKm.round(),
      wins: wins,
      losses: losses,
      draws: draws,
      hasJapanVisit: hasJapanVisit,
      top3Stadiums: top3,
    );
  }

  static List<StadiumRankItem> _buildTop3(Map<String, int> visits) {
    final entries = visits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) {
      final meta = stadiums[e.key];
      return StadiumRankItem(
        code: e.key,
        displayName: meta?.displayName ?? e.key,
        count: e.value,
      );
    }).toList();
  }

  /// 한국 <-> 일본 바다 건너는 스텝인지 판별
  static bool isCrossSeaStep(RecapStep step) {
    if (step.prevStadiumCode == null) return false;
    final fromJp = stadiums[step.prevStadiumCode!]?.isJapan ?? false;
    final toJp = stadiums[step.stadiumCode]?.isJapan ?? false;
    return fromJp != toJp;
  }

  /// 가중 타임라인 계산: 바다를 건너는 비행 스텝은 3.8배 천천히 진행
  static ({int activeIndex, double stepFraction}) resolveTimeline(
    List<RecapStep> steps,
    double progress,
  ) {
    if (steps.isEmpty) return (activeIndex: 0, stepFraction: 0.0);
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped >= 1.0) {
      return (activeIndex: steps.length - 1, stepFraction: 1.0);
    }

    final weights = <double>[];
    double totalWeight = 0.0;
    for (final s in steps) {
      final double w;
      if (isCrossSeaStep(s)) {
        w = 4.5;
      } else if (s.imageUrls.isNotEmpty) {
        w = 3.4;
      } else {
        w = 1.0;
      }
      weights.add(w);
      totalWeight += w;
    }

    final target = clamped * totalWeight;
    double acc = 0.0;
    for (int i = 0; i < steps.length; i++) {
      final nextAcc = acc + weights[i];
      if (target <= nextAcc || i == steps.length - 1) {
        final frac = ((target - acc) / weights[i]).clamp(0.0, 1.0);
        return (activeIndex: i, stepFraction: frac);
      }
      acc = nextAcc;
    }
    return (activeIndex: steps.length - 1, stepFraction: 1.0);
  }

  /// 애니메이션 진행 시점(0.0 ~ 1.0)에 해당하는 실시간 스냅샷 계산
  RecapSnapshot snapshotAtProgress(double progress) {
    if (steps.isEmpty) {
      return const RecapSnapshot(
        gamesCount: 0,
        visitedStadiumCount: 0,
        totalDistanceKm: 0,
        stadiumVisits: {},
        top3Stadiums: [],
        currentStep: null,
      );
    }

    final clamped = progress.clamp(0.0, 1.0);
    final resolved = resolveTimeline(steps, clamped);
    final activeIndex = resolved.activeIndex;
    final stepFraction = resolved.stepFraction;

    final activeStep = steps[activeIndex];
    final bool hasPhotos = activeStep.imageUrls.isNotEmpty;
    final bool isCrossSea = isCrossSeaStep(activeStep);
    final double arrivalThreshold = activeIndex == 0
        ? 0.0
        : (hasPhotos ? (isCrossSea ? 0.45 : 0.35) : 0.85);
    final double moveProgress = arrivalThreshold <= 0
        ? 1.0
        : (stepFraction / arrivalThreshold).clamp(0.0, 1.0);

    final Map<String, int> visits = {};
    final int visibleUntil = clamped >= 1.0
        ? steps.length
        : (activeIndex + 1).clamp(1, steps.length);

    for (int i = 0; i < visibleUntil; i++) {
      // 현재 이동 중인 스텝은 라인이 도착한 시점(arrivalThreshold) 이후에 카운트
      if (i == visibleUntil - 1 &&
          clamped < 1.0 &&
          i > 0 &&
          stepFraction < arrivalThreshold) {
        continue;
      }
      final code = steps[i].stadiumCode;
      visits[code] = (visits[code] ?? 0) + 1;
    }

    final prevCum = activeIndex > 0
        ? steps[activeIndex - 1].cumulativeDistanceKm
        : 0.0;
    final interpKm = clamped >= 1.0
        ? steps.last.cumulativeDistanceKm
        : prevCum + activeStep.stepDistanceKm * moveProgress;

    final gamesNow = clamped >= 1.0
        ? totalGames
        : (activeIndex +
                  (stepFraction >= arrivalThreshold || activeIndex == 0
                      ? 1
                      : 0))
              .clamp(1, totalGames);

    return RecapSnapshot(
      gamesCount: gamesNow,
      visitedStadiumCount: visits.length,
      totalDistanceKm: interpKm.round(),
      stadiumVisits: visits,
      top3Stadiums: _buildTop3(visits),
      currentStep: activeStep,
      stepFraction: stepFraction,
    );
  }
}
