import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class TicketStubTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final AttendanceModel attendance;
  final TeamModel? recordedTeam;
  final Color recordedTeamColor;
  final int ticketNumber;
  final bool isWin;
  final int myScore;
  final int oppScore;
  final String myTeam;
  final String oppTeam;
  final VoidCallback onTap;

  const TicketStubTile({
    super.key,
    required this.data,
    required this.attendance,
    required this.recordedTeam,
    required this.recordedTeamColor,
    required this.ticketNumber,
    required this.isWin,
    required this.myScore,
    required this.oppScore,
    required this.myTeam,
    required this.oppTeam,
    required this.onTap,
  });

  String _shortDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final parts = dateStr.split('.');
    if (parts.length == 3) {
      return '${parts[1].padLeft(2, '0')}.${parts[2].padLeft(2, '0')}';
    }
    return dateStr;
  }

  String _formatPrice(dynamic raw) {
    if (raw == null) return '-';
    final numVal = raw is int ? raw : int.tryParse(raw.toString());
    if (numVal == null || numVal <= 0) return '-';
    final s = numVal.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final isDraw = myScore == oppScore;
    final resultLabel = isWin ? 'WIN' : (isDraw ? 'DRAW' : 'LOSE');
    final resultColor = isWin
        ? recordedTeamColor
        : (isDraw ? GRAYSCALE_LABEL_600 : Colors.redAccent);
    final coverUrl = attendance.imageUrls.isNotEmpty
        ? attendance.imageUrls.first
        : null;
    final serialText = 'NO.${ticketNumber.toString().padLeft(3, '0')}';
    final seat = (data['seat'] ?? '').toString().trim();
    final memo = (data['memo'] ?? '').toString().trim();
    final stadium = context.read<TeamProvider>().sympleStadiumName(
      data['stadium']?.toString(),
    );
    final date = _shortDate(data['date']?.toString());
    final time = (data['time'] ?? attendance.time).toString().trim();
    final dateWithTime = time.isNotEmpty ? '$date · $time' : date;

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDarkMode ? 0.25 : 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 티켓 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.readableColor(recordedTeamColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          attendance.isFourCut ? 'FOUR-CUT' : 'TICKET',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: resultColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        resultLabel,
                        style: const TextStyle(
                          color: WHITE,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 사진 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverUrl != null && coverUrl.trim().isNotEmpty)
                          Container(
                            color: attendance.isFourCut
                                ? const Color(0xFF0F172A)
                                : Colors.transparent,
                            padding: attendance.isFourCut
                                ? const EdgeInsets.all(4)
                                : EdgeInsets.zero,
                            child: _StorageImageWithFallback(
                              imageUrl: coverUrl,
                              memCacheWidth: 480,
                              fit: attendance.isFourCut
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                              teamColor: recordedTeamColor,
                              logoPath: recordedTeam?.logoPath,
                            ),
                          )
                        else
                          Container(
                            color: recordedTeamColor,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(14),
                            child: recordedTeam != null
                                ? Opacity(
                                    opacity: 0.28,
                                    child: Image.asset(
                                      recordedTeam!.logoPath,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        if (!attendance.isFourCut) ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    '$myTeam $myScore:$oppScore $oppTeam',
                                    style: const TextStyle(
                                      color: WHITE,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  stadium,
                                  style: TextStyle(
                                    color: WHITE.withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // 절취선
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CustomPaint(
                          size: const Size(double.infinity, 1),
                          painter: _DashedLinePainter(
                            color: context.borderColor,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.borderColor),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.borderColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 날짜 · 금액 · 좌석 · 메모 · NO.001 + 바코드
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetaCell(label: 'DATE', value: dateWithTime),
                        ),
                        Expanded(
                          child: _MetaCell(
                            label: 'PRICE',
                            value: _formatPrice(data['ticketPrice']),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _MetaCell(
                      label: 'SEAT',
                      value: seat.isNotEmpty ? seat : '-',
                    ),
                    if (memo.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '"$memo"',
                        style: GoogleFonts.nanumPenScript(
                          fontSize: 15,
                          height: 1.15,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          serialText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const _MiniBarcode(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerticalTicketPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final AttendanceModel attendance;
  final TeamModel? recordedTeam;
  final Color recordedTeamColor;
  final int ticketNumber;
  final bool isWin;
  final int myScore;
  final int oppScore;
  final String myTeam;
  final String oppTeam;
  final VoidCallback onOpenDetail;
  final VoidCallback? onDelete;

  const VerticalTicketPreviewDialog({
    super.key,
    required this.data,
    required this.attendance,
    required this.recordedTeam,
    required this.recordedTeamColor,
    required this.ticketNumber,
    required this.isWin,
    required this.myScore,
    required this.oppScore,
    required this.myTeam,
    required this.oppTeam,
    required this.onOpenDetail,
    this.onDelete,
  });

  String _formatPrice(dynamic raw) {
    if (raw == null) return '-';
    final numVal = raw is int ? raw : int.tryParse(raw.toString());
    if (numVal == null || numVal <= 0) return '-';
    final s = numVal.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final isDraw = myScore == oppScore;
    final resultLabel = isWin ? 'WIN' : (isDraw ? 'DRAW' : 'LOSE');
    final resultColor = isWin
        ? recordedTeamColor
        : (isDraw ? GRAYSCALE_LABEL_600 : Colors.redAccent);
    final coverUrl = attendance.imageUrls.isNotEmpty
        ? attendance.imageUrls.first
        : null;
    final serialText = 'NO.${ticketNumber.toString().padLeft(3, '0')}';
    final seat = (data['seat'] ?? '').toString().trim();
    final memo = (data['memo'] ?? '').toString().trim();
    final stadium = (data['stadium'] ?? '').toString();
    final date = (data['date'] ?? '').toString();
    final time = (data['time'] ?? attendance.time).toString().trim();
    final dateWithTime = time.isNotEmpty ? '$date · $time' : date;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 상단 티켓 헤더
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: context.readableColor(recordedTeamColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              attendance.isFourCut
                                  ? 'BASEBALL FOUR-CUT'
                                  : 'MATCH TICKET',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            resultLabel,
                            style: const TextStyle(
                              color: WHITE,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 사진 영역
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: attendance.isFourCut ? 280 : 185,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (coverUrl != null && coverUrl.trim().isNotEmpty)
                              Container(
                                color: attendance.isFourCut
                                    ? const Color(0xFF0F172A)
                                    : Colors.transparent,
                                padding: attendance.isFourCut
                                    ? const EdgeInsets.all(8)
                                    : EdgeInsets.zero,
                                child: _StorageImageWithFallback(
                                  imageUrl: coverUrl,
                                  memCacheWidth: 800,
                                  fit: attendance.isFourCut
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  teamColor: recordedTeamColor,
                                  logoPath: recordedTeam?.logoPath,
                                ),
                              )
                            else
                              Container(
                                color: recordedTeamColor,
                                alignment: Alignment.center,
                                child: recordedTeam != null
                                    ? Image.asset(
                                        recordedTeam!.logoPath,
                                        height: 84,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            if (!attendance.isFourCut) ...[
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.72),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 14,
                                right: 14,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$myTeam $myScore : $oppScore $oppTeam',
                                      style: const TextStyle(
                                        color: WHITE,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      stadium,
                                      style: TextStyle(
                                        color: WHITE.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 절취선
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      height: 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: _DashedLinePainter(
                                color: context.borderColor,
                              ),
                            ),
                          ),
                          Positioned(
                            left: -8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 메타 정보 + 손글씨 메모
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetaCell(
                                label: 'DATE',
                                value: dateWithTime,
                              ),
                            ),
                            Expanded(
                              child: _MetaCell(
                                label: 'PRICE',
                                value: _formatPrice(data['ticketPrice']),
                              ),
                            ),
                          ],
                        ),
                        if (seat.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _MetaCell(label: 'SEAT', value: seat),
                        ],
                        if (memo.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Divider(height: 1, color: context.dividerColor),
                          const SizedBox(height: 8),
                          Text(
                            '"$memo"',
                            style: GoogleFonts.nanumPenScript(
                              fontSize: 20,
                              height: 1.3,
                              color: context.textPrimary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              serialText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.textMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const _MiniBarcode(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (onDelete != null) ...[
                              SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: onDelete,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '삭제',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: onOpenDetail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.readableColor(
                                      recordedTeamColor,
                                    ),
                                    foregroundColor:
                                        ThemeData.estimateBrightnessForColor(
                                              context.readableColor(
                                                recordedTeamColor,
                                              ),
                                            ) ==
                                            Brightness.dark
                                        ? WHITE
                                        : Colors.black,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '상세페이지 보기',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 직관기록 삭제 전 확인 팝업
Future<bool> showDeleteAttendanceConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: WHITE,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '직관기록 삭제',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        '이 직관기록을 삭제할까요?\n삭제한 기록과 사진은 복구할 수 없습니다.',
        style: TextStyle(
          fontSize: 13.5,
          color: GRAYSCALE_LABEL_700,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소', style: TextStyle(color: GRAYSCALE_LABEL_600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: WHITE,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            '삭제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MiniBarcode extends StatelessWidget {
  const _MiniBarcode();

  @override
  Widget build(BuildContext context) {
    const widths = [2.0, 3.0, 1.5, 2.5, 1.0, 3.0, 1.5, 2.0, 3.0, 1.5];
    const heights = [
      16.0,
      12.0,
      16.0,
      10.0,
      16.0,
      14.0,
      16.0,
      11.0,
      16.0,
      13.0,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widths.length, (i) {
        return Container(
          width: widths[i],
          height: heights[i],
          margin: const EdgeInsets.only(left: 1.5),
          color: context.textSecondary,
        );
      }),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StorageImageWithFallback extends StatefulWidget {
  final String imageUrl;
  final int memCacheWidth;
  final BoxFit fit;
  final Color teamColor;
  final String? logoPath;

  const _StorageImageWithFallback({
    required this.imageUrl,
    required this.memCacheWidth,
    this.fit = BoxFit.cover,
    required this.teamColor,
    this.logoPath,
  });

  @override
  State<_StorageImageWithFallback> createState() =>
      _StorageImageWithFallbackState();
}

class _StorageImageWithFallbackState extends State<_StorageImageWithFallback> {
  String? _refreshedUrl;
  bool _refreshAttempted = false;

  Future<void> _tryRefreshTokenUrl() async {
    if (_refreshAttempted) return;
    _refreshAttempted = true;
    if (!widget.imageUrl.contains('firebasestorage.googleapis.com')) return;
    try {
      final fresh = await FirebaseStorage.instance
          .refFromURL(widget.imageUrl)
          .getDownloadURL();
      if (mounted && fresh != widget.imageUrl) {
        setState(() => _refreshedUrl = fresh);
      }
    } catch (e) {
      debugPrint('TicketStubTile token refresh failed: $e');
    }
  }

  Widget _buildLogoFallback() {
    return Container(
      color: widget.teamColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: widget.logoPath != null
          ? Opacity(
              opacity: 0.28,
              child: Image.asset(widget.logoPath!, fit: BoxFit.contain),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUrl = _refreshedUrl ?? widget.imageUrl;
    return CachedNetworkImage(
      imageUrl: activeUrl,
      fit: widget.fit,
      width: widget.fit == BoxFit.fitWidth ? double.infinity : null,
      memCacheWidth: widget.memCacheWidth,
      placeholder: (_, _) => widget.fit == BoxFit.fitWidth
          ? AspectRatio(
              aspectRatio: 0.84,
              child: Container(color: widget.teamColor.withValues(alpha: 0.15)),
            )
          : Container(color: widget.teamColor.withValues(alpha: 0.15)),
      errorWidget: (_, url, error) {
        if (!_refreshAttempted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tryRefreshTokenUrl();
          });
        }
        return _buildLogoFallback();
      },
    );
  }
}

/// 직관 네컷 전용 그리드 카드 (티켓 스텁 틀 없이 네컷 프레임 그 자체로 표시)
class FourCutGridCard extends StatelessWidget {
  final AttendanceModel attendance;
  final TeamModel? recordedTeam;
  final Color recordedTeamColor;
  final VoidCallback onTap;

  const FourCutGridCard({
    super.key,
    required this.attendance,
    required this.recordedTeam,
    required this.recordedTeamColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = attendance.imageUrls.isNotEmpty
        ? attendance.imageUrls.first
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: coverUrl != null && coverUrl.trim().isNotEmpty
              ? _StorageImageWithFallback(
                  imageUrl: coverUrl,
                  memCacheWidth: 560,
                  fit: BoxFit.fitWidth,
                  teamColor: recordedTeamColor,
                  logoPath: recordedTeam?.logoPath,
                )
              : AspectRatio(
                  aspectRatio: 0.84,
                  child: Container(
                    color: recordedTeamColor,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(18),
                    child: recordedTeam != null
                        ? Opacity(
                            opacity: 0.35,
                            child: Image.asset(
                              recordedTeam!.logoPath,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 직관 네컷 전용 프리뷰 다이얼로그 (앞면 네컷 <-> 뒷면 좌석·가격 영수증 3D 플립 + 중앙 터치 유도)
class FourCutPreviewDialog extends StatefulWidget {
  final AttendanceModel attendance;
  final TeamModel? recordedTeam;
  final Color recordedTeamColor;
  final VoidCallback onOpenDetail;
  final VoidCallback? onDelete;

  const FourCutPreviewDialog({
    super.key,
    required this.attendance,
    required this.recordedTeam,
    required this.recordedTeamColor,
    required this.onOpenDetail,
    this.onDelete,
  });

  @override
  State<FourCutPreviewDialog> createState() => _FourCutPreviewDialogState();
}

class _FourCutPreviewDialogState extends State<FourCutPreviewDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnim;
  bool _isFlipped = false;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _flipAnim = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _hasInteracted = true;
      _isFlipped = !_isFlipped;
    });
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  String _formatWon(int? amount) {
    if (amount == null || amount <= 0) return '-';
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attendance;
    final coverUrl = a.imageUrls.isNotEmpty ? a.imageUrls.first : null;
    final subMeta = '${a.date} · ${a.stadium}';
    final ticketPrice = a.ticketPrice ?? 0;
    final foodCost = a.foodCost ?? 0;
    final goodsCost = a.goodsCost ?? 0;
    final totalCost = ticketPrice + foodCost + goodsCost;
    final seatText = (a.seat ?? '').trim();
    final hasSeat = seatText.isNotEmpty;
    final hasPrice = ticketPrice > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleFlip,
              child: AnimatedBuilder(
                animation: _flipAnim,
                builder: (context, child) {
                  final angle = _flipAnim.value * math.pi;
                  final showBack = angle > math.pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _buildBackReceiptCard(
                              context,
                              a: a,
                              subMeta: subMeta,
                              seatText: seatText,
                              ticketPrice: ticketPrice,
                              foodCost: foodCost,
                              goodsCost: goodsCost,
                              totalCost: totalCost,
                            ),
                          )
                        : _buildFrontFourCutCard(coverUrl),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSeat || hasPrice) ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (hasSeat)
                          _buildMetaChip(context, '💺 $seatText'),
                        if (hasPrice)
                          _buildMetaChip(
                            context,
                            '🎫 ${_formatWon(ticketPrice)}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Text(
                      subMeta,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (widget.onDelete != null) ...[
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: widget.onDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '삭제',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: widget.onOpenDetail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.readableColor(
                                widget.recordedTeamColor,
                              ),
                              foregroundColor:
                                  ThemeData.estimateBrightnessForColor(
                                        context.readableColor(
                                          widget.recordedTeamColor,
                                        ),
                                      ) ==
                                      Brightness.dark
                                  ? WHITE
                                  : Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '상세페이지 보기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.borderColor),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFrontFourCutCard(String? coverUrl) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (coverUrl != null && coverUrl.trim().isNotEmpty)
              _StorageImageWithFallback(
                imageUrl: coverUrl,
                memCacheWidth: 960,
                fit: BoxFit.fitWidth,
                teamColor: widget.recordedTeamColor,
                logoPath: widget.recordedTeam?.logoPath,
              )
            else
              Container(
                height: 360,
                width: double.infinity,
                color: widget.recordedTeamColor,
                alignment: Alignment.center,
                child: widget.recordedTeam != null
                    ? Image.asset(widget.recordedTeam!.logoPath, height: 84)
                    : const SizedBox.shrink(),
              ),
            if (!_hasInteracted)
              IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.94, end: 1.0),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(height: 5),
                        Text(
                          '터치해서 뒷면 보기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackReceiptCard(
    BuildContext context, {
    required AttendanceModel a,
    required String subMeta,
    required String seatText,
    required int ticketPrice,
    required int foodCost,
    required int goodsCost,
    required int totalCost,
  }) {
    final result = a.myScore > a.opponentScore
        ? 'WIN'
        : (a.myScore < a.opponentScore ? 'LOSE' : 'DRAW');
    final opp = (a.oppTeam ?? '').trim().isNotEmpty ? a.oppTeam! : '상대팀';
    final accent = context.readableColor(widget.recordedTeamColor);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 360),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FOUR-CUT RECEIPT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: context.textMuted,
                ),
              ),
              Text(
                '터치해서 앞면 보기',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${a.myTeam} ${a.myScore} : ${a.opponentScore} $opp ($result)',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subMeta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: context.borderColor),
            ),
          ),
          _buildReceiptRow(
            context,
            '좌석',
            seatText.isNotEmpty ? seatText : '미입력',
          ),
          const SizedBox(height: 10),
          _buildReceiptRow(context, '티켓 가격', _formatWon(ticketPrice)),
          const SizedBox(height: 10),
          _buildReceiptRow(context, '식비', _formatWon(foodCost)),
          const SizedBox(height: 10),
          _buildReceiptRow(context, '굿즈비', _formatWon(goodsCost)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 지출',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textSecondary,
                  ),
                ),
                Text(
                  _formatWon(totalCost),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          if ((a.memo ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '"${a.memo!.trim()}"',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.textMuted,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
