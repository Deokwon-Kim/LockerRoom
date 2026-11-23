import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lockerroom/utils/intuition_recap_calculator.dart';

class KboFootprintMap extends StatelessWidget {
  final List<RecapStep> steps;
  final double progress; // 0.0 ~ 1.0
  final Color teamColor;
  final Map<String, int> stadiumVisits;
  final bool includeJapan;

  const KboFootprintMap({
    super.key,
    required this.steps,
    required this.progress,
    required this.teamColor,
    required this.stadiumVisits,
    this.includeJapan = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KboFootprintMapPainter(
        steps: steps,
        progress: progress.clamp(0.0, 1.0),
        teamColor: teamColor,
        stadiumVisits: stadiumVisits,
        includeJapan: includeJapan,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _KboFootprintMapPainter extends CustomPainter {
  final List<RecapStep> steps;
  final double progress;
  final Color teamColor;
  final Map<String, int> stadiumVisits;
  final bool includeJapan;

  _KboFootprintMapPainter({
    required this.steps,
    required this.progress,
    required this.teamColor,
    required this.stadiumVisits,
    required this.includeJapan,
  });

  // 국내 단독 Bounding Box
  static const double _krMinLng = 125.75;
  static const double _krMaxLng = 129.65;
  static const double _krMinLat = 33.05;
  static const double _krMaxLat = 38.65;

  // 한·일 확장 Bounding Box
  static const double _jpMinLng = 125.4;
  static const double _jpMaxLng = 142.3;
  static const double _jpMinLat = 25.6;
  static const double _jpMaxLat = 39.3;

  // 남한 본토 정규화 윤곽 좌표 (lng, lat)
  static const List<List<double>> _mainlandCoords = [
    [126.15, 37.80], // 강화 북부
    [126.55, 37.88], // 파주/임진강
    [127.15, 38.25], // 철원
    [127.75, 38.30], // 화천
    [128.35, 38.62], // 고성 최북단
    [128.65, 38.20], // 속초
    [128.95, 37.75], // 강릉
    [129.20, 37.40], // 삼척
    [129.42, 36.95], // 울진
    [129.40, 36.40], // 영덕
    [129.58, 36.02], // 포항 호미곶
    [129.48, 35.50], // 울산
    [129.25, 35.15], // 부산 해운대
    [128.95, 35.02], // 부산 사하
    [128.55, 35.12], // 창원/마산
    [128.35, 34.82], // 통영/고성
    [127.95, 34.88], // 남해
    [127.65, 34.72], // 여수
    [127.15, 34.55], // 고흥
    [126.68, 34.32], // 완도/해남 땅끝
    [126.32, 34.52], // 진도
    [126.35, 34.85], // 목포
    [126.42, 35.30], // 영광
    [126.52, 35.65], // 부안 변산
    [126.65, 36.02], // 군산
    [126.52, 36.35], // 보령
    [126.12, 36.75], // 태안 반도
    [126.52, 36.95], // 당진/아산만
    [126.68, 37.38], // 인천 송도
    [126.40, 37.55], // 영종/강화
  ];

  // 제주도 좌표 (lng, lat)
  static const List<List<double>> _jejuCoords = [
    [126.18, 33.30],
    [126.50, 33.52],
    [126.95, 33.48],
    [126.82, 33.24],
    [126.35, 33.20],
  ];

  // 일본 규슈 좌표 (lng, lat)
  static const List<List<double>> _kyushuCoords = [
    [130.10, 33.90],
    [130.95, 33.95],
    [131.65, 33.55],
    [131.85, 32.55],
    [131.40, 31.35],
    [130.55, 31.25],
    [130.25, 32.15],
    [129.75, 33.05],
  ];

  // 일본 시코쿠 좌표 (lng, lat)
  static const List<List<double>> _shikokuCoords = [
    [132.10, 33.40],
    [133.20, 33.95],
    [134.70, 34.15],
    [134.65, 33.55],
    [133.50, 33.25],
    [132.55, 32.85],
  ];

  // 일본 혼슈(주요 본토) 좌표 (lng, lat)
  static const List<List<double>> _honshuCoords = [
    [130.95, 34.05], // 시모노세키
    [131.85, 34.65], // 시마네
    [133.40, 35.50], // 돗토리
    [135.25, 35.65], // 교토 북부
    [136.60, 36.60], // 가나자와
    [137.30, 37.35], // 노토 반도
    [138.80, 37.90], // 니가타
    [139.95, 39.20], // 아키타 남부
    [141.60, 39.20], // 이와테 동부
    [141.55, 38.25], // 센다이
    [140.95, 37.00], // 후쿠시마
    [140.85, 35.75], // 지바
    [139.80, 35.30], // 도쿄/요코하마
    [138.80, 34.65], // 이즈
    [137.00, 34.70], // 아이치
    [135.80, 33.45], // 와카야마
    [135.15, 34.60], // 오사카/고베
    [133.80, 34.45], // 오카야마
    [132.45, 34.30], // 히로시마
  ];

  // 일본 오키나와 본섬 좌표 (lng, lat)
  static const List<List<double>> _okinawaCoords = [
    [127.60, 26.10],
    [127.85, 26.45],
    [128.25, 26.85],
    [128.32, 26.65],
    [127.90, 26.12],
  ];

  // 수도권 구장 겹침 방지를 위한 미세 시각 보정 (lat, lng)
  static const Map<String, List<double>> _visualOffsets = {
    '문학': [-0.06, -0.32], // 서쪽(인천)으로 살짝 벌림
    '고척': [0.12, -0.10],  // 북서쪽으로 살짝
    '잠실': [0.18, 0.18],   // 북동쪽으로 살짝
    '수원': [-0.22, 0.08],  // 남쪽으로 살짝
  };

  /// 첫 일본 직관 스텝에 도달할 때 0.0(한국 단독) -> 1.0(한·일 확장)으로 부드럽게 줌아웃
  double _computeJapanBlend(int activeIndex, double stepFraction) {
    if (!includeJapan || steps.isEmpty) return 0.0;
    final firstJapanIdx = steps.indexWhere(
      (s) => IntuitionRecapData.stadiums[s.stadiumCode]?.isJapan ?? false,
    );
    if (firstJapanIdx == -1) return 0.0;
    if (firstJapanIdx == 0) return 1.0;

    if (activeIndex < firstJapanIdx) {
      return 0.0;
    } else if (activeIndex == firstJapanIdx && progress < 1.0) {
      // 비행기 출발 전 앞부분(0.0 ~ 0.35) 동안 카메라 줌아웃 완료 후 비행기 이동이 선명하게 보이도록
      final t = (stepFraction / 0.35).clamp(0.0, 1.0);
      return Curves.easeInOutCubic.transform(t);
    } else {
      return 1.0;
    }
  }

  /// 진행 방향 각도(angle)에 맞춰 깔끔한 벡터 비행기 실루엣 그리기
  void _drawAirplane(Canvas canvas, Offset center, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // 은은한 후광
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 오른쪽(+X 방향)을 바라보는 비행기 벡터 Path
    final planePath = Path()
      ..moveTo(9.5, 0) // 기수
      ..lineTo(3.0, -1.6)
      ..lineTo(-2.5, -8.5) // 좌측 날개
      ..lineTo(-4.5, -8.5)
      ..lineTo(-1.2, -1.6)
      ..lineTo(-6.5, -1.3)
      ..lineTo(-8.8, -3.8) // 꼬리 날개 위
      ..lineTo(-10.0, -3.8)
      ..lineTo(-8.5, 0)
      ..lineTo(-10.0, 3.8) // 꼬리 날개 아래
      ..lineTo(-8.8, 3.8)
      ..lineTo(-6.5, 1.3)
      ..lineTo(-1.2, 1.6)
      ..lineTo(-4.5, 8.5) // 우측 날개
      ..lineTo(-2.5, 8.5)
      ..lineTo(3.0, 1.6)
      ..close();

    canvas.drawPath(
      planePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      planePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    canvas.restore();
  }

  Offset _latLngToOffset(
    double lat,
    double lng,
    Rect mapRect,
    double japanBlend, {
    String? code,
  }) {
    final off = code != null ? _visualOffsets[code] : null;
    final offsetScale = 1.0 - japanBlend;
    final adjLat = lat + (off != null ? off[0] * offsetScale : 0.0);
    final adjLng = lng + (off != null ? off[1] * offsetScale : 0.0);
    final minLng = lerpDouble(_krMinLng, _jpMinLng, japanBlend)!;
    final maxLng = lerpDouble(_krMaxLng, _jpMaxLng, japanBlend)!;
    final minLat = lerpDouble(_krMinLat, _jpMinLat, japanBlend)!;
    final maxLat = lerpDouble(_krMaxLat, _jpMaxLat, japanBlend)!;
    final nx = (adjLng - minLng) / (maxLng - minLng);
    final ny = 1.0 - ((adjLat - minLat) / (maxLat - minLat));
    return Offset(
      mapRect.left + nx * mapRect.width,
      mapRect.top + ny * mapRect.height,
    );
  }

  Path _buildPolygonPath(
    List<List<double>> coords,
    Rect mapRect,
    double japanBlend,
  ) {
    final path = Path();
    for (int i = 0; i < coords.length; i++) {
      final p = _latLngToOffset(coords[i][1], coords[i][0], mapRect, japanBlend);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  Path _buildArcPath(Offset from, Offset to) {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = sqrt(dx * dx + dy * dy);
    // 수직 방향으로 부드럽게 휘어지는 곡선
    final nx = -dy / (dist == 0 ? 1 : dist);
    final ny = dx / (dist == 0 ? 1 : dist);
    final bend = (dist * 0.24).clamp(16.0, 68.0);
    final control = Offset(mid.dx + nx * bend, mid.dy + ny * bend);

    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final resolved = IntuitionRecapData.resolveTimeline(steps, progress);
    final activeIndex = resolved.activeIndex;
    final stepFraction = resolved.stepFraction;

    final japanBlend = _computeJapanBlend(activeIndex, stepFraction);

    // 지도 종횡비 동적 보간 (한국 단독 0.72 -> 한·일 확장 1.08)
    final mapAspect = lerpDouble(0.72, 1.08, japanBlend)!;
    final availW = size.width;
    final availH = size.height;
    double drawW = availW;
    double drawH = drawW / mapAspect;
    if (drawH > availH) {
      drawH = availH;
      drawW = drawH * mapAspect;
    }
    final mapRect = Rect.fromLTWH(
      (availW - drawW) / 2,
      (availH - drawH) / 2,
      drawW,
      drawH,
    );

    // 1. 한반도 (+ 일본) 실루엣 그리기
    final mainlandPath = _buildPolygonPath(_mainlandCoords, mapRect, japanBlend);
    final jejuPath = _buildPolygonPath(_jejuCoords, mapRect, japanBlend);

    final landFill = Paint()
      ..color = const Color(0xFF23262E)
      ..style = PaintingStyle.fill;
    final landStroke = Paint()
      ..color = const Color(0xFF3A3F4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(mainlandPath, landFill);
    canvas.drawPath(mainlandPath, landStroke);
    canvas.drawPath(jejuPath, landFill);
    canvas.drawPath(jejuPath, landStroke);

    if (japanBlend > 0.01) {
      final jpFill = Paint()
        ..color = const Color(0xFF23262E).withValues(alpha: japanBlend)
        ..style = PaintingStyle.fill;
      final jpStroke = Paint()
        ..color = const Color(0xFF3A3F4B).withValues(alpha: japanBlend)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round;

      for (final coords in [
        _kyushuCoords,
        _shikokuCoords,
        _honshuCoords,
        _okinawaCoords,
      ]) {
        final jpPath = _buildPolygonPath(coords, mapRect, japanBlend);
        canvas.drawPath(jpPath, jpFill);
        canvas.drawPath(jpPath, jpStroke);
      }
    }

    // 2. 미방문 국내 구장 미세한 점 표시
    for (final entry in IntuitionRecapData.stadiums.entries) {
      if (entry.value.isJapan) continue;
      final count = stadiumVisits[entry.key] ?? 0;
      if (count == 0) {
        final pos = _latLngToOffset(
          entry.value.lat,
          entry.value.lng,
          mapRect,
          japanBlend,
          code: entry.key,
        );
        canvas.drawCircle(
          pos,
          lerpDouble(3.2, 2.2, japanBlend)!,
          Paint()..color = const Color(0xFF4B5160),
        );
      }
    }

    if (steps.isEmpty) return;

    // 3. 시간순 곡선 이동 경로 애니메이션
    final int maxEdgeIndex = progress >= 1.0
        ? steps.length - 1
        : activeIndex;

    // 중복 엣지 투명도 누적을 막기 위해 기본 선과 현재 활성 선 분리
    final pastLinePaint = Paint()
      ..color = teamColor.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final activeLineGlowPaint = Paint()
      ..color = teamColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final activeLinePaint = Paint()
      ..color = teamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    Offset? movingHeadPos;
    double movingHeadAngle = 0.0;
    bool isFlyingCrossSea = false;

    for (int i = 0; i <= maxEdgeIndex; i++) {
      final step = steps[i];
      if (step.prevStadiumCode == null ||
          step.prevStadiumCode == step.stadiumCode) {
        continue;
      }

      final fromMeta = IntuitionRecapData.stadiums[step.prevStadiumCode!];
      final toMeta = IntuitionRecapData.stadiums[step.stadiumCode];
      if (fromMeta == null || toMeta == null) continue;

      final fromPos = _latLngToOffset(
        fromMeta.lat,
        fromMeta.lng,
        mapRect,
        japanBlend,
        code: fromMeta.code,
      );
      final toPos = _latLngToOffset(
        toMeta.lat,
        toMeta.lng,
        mapRect,
        japanBlend,
        code: toMeta.code,
      );
      final arcPath = _buildArcPath(fromPos, toPos);

      if (i < maxEdgeIndex || progress >= 1.0) {
        canvas.drawPath(arcPath, pastLinePaint);
      } else {
        // 사진이 있는 스텝은 전반부(0.35 / 국제선 0.45)까지 먼저 라인이 도착하고, 후반부엔 도착 상태로 사진 감상
        final isCrossSea = IntuitionRecapData.isCrossSeaStep(step);
        final hasPhotos = step.imageUrls.isNotEmpty;
        final double arrivalEnd = hasPhotos ? (isCrossSea ? 0.45 : 0.35) : 0.88;
        final double startOffset = isCrossSea ? 0.10 : 0.0;
        final double span = (arrivalEnd - startOffset).clamp(0.1, 1.0);
        final double drawProgress =
            ((stepFraction - startOffset) / span).clamp(0.0, 1.0);

        final metrics = arcPath.computeMetrics();
        for (final metric in metrics) {
          final drawLen = metric.length * drawProgress;
          final partial = metric.extractPath(0, drawLen);
          canvas.drawPath(partial, activeLineGlowPaint);
          canvas.drawPath(partial, activeLinePaint);

          if (drawProgress > 0.0 && drawProgress < 1.0) {
            final tangent = metric.getTangentForOffset(drawLen);
            if (tangent != null) {
              movingHeadPos = tangent.position;
              movingHeadAngle = atan2(tangent.vector.dy, tangent.vector.dx);
              isFlyingCrossSea = isCrossSea;
            }
          }
        }
      }
    }

    // 이동 중인 비행기 아이콘(국제선) 또는 빛나는 포인트(국내선)
    if (movingHeadPos != null && progress < 1.0) {
      if (isFlyingCrossSea) {
        _drawAirplane(canvas, movingHeadPos, movingHeadAngle, teamColor);
      } else {
        canvas.drawCircle(
          movingHeadPos,
          6.5,
          Paint()
            ..color = teamColor.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          movingHeadPos,
          3.5,
          Paint()..color = Colors.white,
        );
      }
    }

    // 4. 방문한 구장 원형 마커 + 방문 횟수 뱃지
    final maxVisit = stadiumVisits.values.isEmpty
        ? 1
        : stadiumVisits.values.reduce(max);
    final activeStadiumCode = steps[activeIndex].stadiumCode;

    // 겹침 최소화를 위해 방문 횟수 적은 것부터 큰 것 순으로 그리기
    final visitedEntries = stadiumVisits.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final entry in visitedEntries) {
      final meta = IntuitionRecapData.stadiums[entry.key];
      if (meta == null) continue;
      final pos = _latLngToOffset(
        meta.lat,
        meta.lng,
        mapRect,
        japanBlend,
        code: entry.key,
      );
      final count = entry.value;
      final ratio = maxVisit > 1 ? (count / maxVisit) : 1.0;
      final radius = 10.5 + ratio * 6.5; // 10.5 ~ 17.0

      // 현재 도착 구장 파동(Ripple) 효과
      if (entry.key == activeStadiumCode && progress < 1.0) {
        final rippleRadius = radius + 6 + (stepFraction * 8);
        canvas.drawCircle(
          pos,
          rippleRadius,
          Paint()
            ..color = teamColor.withValues(alpha: (1.0 - stepFraction) * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // 외곽 글로우
      canvas.drawCircle(
        pos,
        radius + 3.0,
        Paint()
          ..color = teamColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // 다크 분리 테두리 (수도권 마커 겹침 시 구분선)
      canvas.drawCircle(
        pos,
        radius + 1.5,
        Paint()..color = const Color(0xFF0A0B0F),
      );

      // 메인 원
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = teamColor,
      );

      // 숫자 텍스트
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius >= 16 ? 12 : 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KboFootprintMapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.teamColor != teamColor ||
        oldDelegate.includeJapan != includeJapan ||
        oldDelegate.steps.length != steps.length;
  }
}
