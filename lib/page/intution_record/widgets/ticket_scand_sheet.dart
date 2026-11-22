import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/scanned_ticket_data.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

export 'package:lockerroom/model/scanned_ticket_data.dart';

class TicketScandSheet extends StatelessWidget {
  const TicketScandSheet({super.key});

  static Future<ScannedTicketData?> show(BuildContext context) {
    final scheduleProvider = context.read<ScheduleProvider>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => TicketScanProvider(scheduleProvider: scheduleProvider),
        child: const TicketScandSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanProvider = context.watch<TicketScanProvider>();
    final teamColor =
        context.read<TeamProvider>().selectedTeam?.color ?? BUTTON;
    final currencyFormat = NumberFormat('#,###');

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: WHITE,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: GRAYSCALE_LABEL_300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '스마트 티켓 스캔',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: BLACK,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          if (scanProvider.isProcessing) ...[
            SizedBox(height: 20),
            Center(child: CircularProgressIndicator(color: teamColor)),
            SizedBox(height: 16),
            Text(
              scanProvider.statusMessage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BLACK,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
          ] else if (scanProvider.parsedResult == null) ...[
            if (scanProvider.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  scanProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamColor,
                      foregroundColor: WHITE,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(Icons.camera_alt_outlined),
                    label: Text(
                      '실물 티켓 촬영',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () =>
                        scanProvider.pickCameraAndScan(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BLACK,
                      side: BorderSide(color: GRAYSCALE_LABEL_300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(Icons.photo_library_outlined),
                    label: Text(
                      '모바일 캡처 선택',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => scanProvider.pickGalleryAndScan(),
                  ),
                ),
              ],
            ),
          ] else ...[
            // 인식결과 카드
            _buildResultCard(context, scanProvider, currencyFormat, teamColor),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: teamColor,
                foregroundColor: WHITE,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final matched = scanProvider.selectedMatchedGame;
                final parsed = scanProvider.parsedResult;
                if (matched != null && parsed?.gameDate != null) {
                  final resultData = ScannedTicketData(
                    matchedGame: matched,
                    gameDate: parsed!.gameDate!,
                    ticketPrice: parsed.ticketPrice ?? 0,
                    seat: parsed.seatType,
                    ticketImageFile: scanProvider.scannedImageFile,
                  );
                  Navigator.pop(context, resultData);
                } else {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    alignment: Alignment.bottomCenter,
                    autoCloseDuration: Duration(seconds: 2),
                    title: Text('일치하는 경기를 선택해주세요.'),
                  );
                }
              },
              child: Text(
                '기록에 자동 적용하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    TicketScanProvider ticketScanProvider,
    NumberFormat format,
    Color teamColor,
  ) {
    final result = ticketScanProvider.parsedResult!;
    final dateStr = result.gameDate != null
        ? DateFormat('yyyy.MM.dd').format(result.gameDate!)
        : '날짜 미인식';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BACKGROUND_COLOR,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GRAYSCALE_LABEL_300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: teamColor, size: 20),
              SizedBox(width: 8),
              Text(
                '티켓 인식 결과',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('📅 경기 일시', '$dateStr ${result.gameTime ?? ""}'),
          const SizedBox(height: 8),
          _buildInfoRow('⚾ 매치업 후보', result.detectedTeams.join(' vs ')),
          const SizedBox(height: 8),
          _buildInfoRow(
            '💰 티켓 가격',
            '${format.format(result.ticketPrice ?? 0)}원',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('💺 좌석 정보', result.seatType ?? '미인식 (직접 입력 가능)'),
          const SizedBox(height: 12),

          if (ticketScanProvider.matchedGames.isNotEmpty) ...[
            Text(
              '매칭된 경기 선택:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: GRAYSCALE_LABEL_600,
              ),
            ),
            SizedBox(height: 6),
            ...ticketScanProvider.matchedGames.map((game) {
              final isSelceted =
                  ticketScanProvider.selectedMatchedGame?.gameId == game.gameId;
              return InkWell(
                onTap: () => ticketScanProvider.selectGame(game),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelceted ? teamColor.withOpacity(0.1) : WHITE,
                    border: Border.all(
                      color: isSelceted ? teamColor : GRAYSCALE_LABEL_300,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${game.awayTeam} vs ${game.homeTeam} (${game.stadium})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isSelceted)
                        Icon(Icons.check, color: teamColor, size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: BLACK,
            ),
          ),
        ),
      ],
    );
  }
}
