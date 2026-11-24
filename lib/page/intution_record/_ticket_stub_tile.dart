import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/team_model.dart';

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

  String _shortStadium(String? stadium) {
    if (stadium == null || stadium.isEmpty) return '';
    return stadium
        .replaceAll('야구장', '')
        .replaceAll('구장', '')
        .replaceAll('파크', '')
        .replaceAll('돔', '돔')
        .trim();
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
    final stadium = _shortStadium(data['stadium']?.toString());
    final date = _shortDate(data['date']?.toString());
    final time = (data['time'] ?? attendance.time).toString().trim();
    final dateWithTime = time.isNotEmpty ? '$date · $time' : date;

    return Material(
      color: WHITE,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GRAYSCALE_LABEL_200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                            color: recordedTeamColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'TICKET',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: GRAYSCALE_LABEL_500,
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
                        if (coverUrl != null)
                          CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 480,
                            placeholder: (_, __) => Container(
                              color: recordedTeamColor.withValues(alpha: 0.15),
                            ),
                            errorWidget: (_, __, ___) =>
                                Container(color: recordedTeamColor),
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
                            color: GRAYSCALE_LABEL_200,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: BACKGROUND_COLOR,
                            shape: BoxShape.circle,
                            border: Border.all(color: GRAYSCALE_LABEL_200),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: BACKGROUND_COLOR,
                            shape: BoxShape.circle,
                            border: Border.all(color: GRAYSCALE_LABEL_200),
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
                          color: GRAYSCALE_LABEL_900,
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
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: GRAYSCALE_LABEL_500,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: WHITE,
              borderRadius: BorderRadius.circular(20),
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
                              color: recordedTeamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'MATCH TICKET',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: GRAYSCALE_LABEL_500,
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
                      height: 185,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (coverUrl != null)
                            CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 800,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              color: GRAYSCALE_LABEL_200,
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
                        const Divider(height: 1, color: GRAYSCALE_LABEL_100),
                        const SizedBox(height: 8),
                        Text(
                          '"$memo"',
                          style: GoogleFonts.nanumPenScript(
                            fontSize: 20,
                            height: 1.3,
                            color: GRAYSCALE_LABEL_950,
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: GRAYSCALE_LABEL_500,
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
                                  backgroundColor: recordedTeamColor,
                                  foregroundColor: WHITE,
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
          child: const Text(
            '취소',
            style: TextStyle(color: GRAYSCALE_LABEL_600),
          ),
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
          child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w700)),
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
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_400,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: GRAYSCALE_LABEL_900,
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
          color: GRAYSCALE_LABEL_700,
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
