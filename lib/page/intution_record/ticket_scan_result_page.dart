import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:lockerroom/provider/ticket_scan_provider.dart';
import 'package:provider/provider.dart';

class TicketScanResultPage extends StatelessWidget {
  const TicketScanResultPage({super.key});

  Future<void> _changePhoto(
    BuildContext context,
    TicketScanProvider provider,
  ) async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 다시 촬영'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 100,
                );
                if (ctx.mounted) Navigator.pop(ctx, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 100,
                );
                if (ctx.mounted) Navigator.pop(ctx, file);
              },
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      provider.updateTicketImage(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketScanProvider>();
    final teamProvider = context.read<TeamProvider>();
    final teamColor = teamProvider.selectedTeam?.color ?? BUTTON;
    final game = provider.selectedMatchedGame;

    final awayTeamModel = game != null
        ? teamProvider.findTeamByName(game.awayTeam)
        : null;
    final homeTeamModel = game != null
        ? teamProvider.findTeamByName(game.homeTeam)
        : null;

    final dateStr = provider.selectedDate != null
        ? DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(provider.selectedDate!)
        : '날짜 미인식';
    final timeStr = provider.selectedTime != null
        ? ' · ${provider.selectedTime}'
        : '';

    return Scaffold(
      backgroundColor: BACKGROUND_COLOR,
      appBar: AppBar(
        title: const Text(
          '티켓 편집',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BLACK,
          ),
        ),
        backgroundColor: BACKGROUND_COLOR,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BLACK, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 매치업 카드 (스캔된 티켓 이미지 대신 매칭된 경기 정보 표시)
              if (game != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: WHITE,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: GRAYSCALE_LABEL_200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green.shade700,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '티켓 정보 매칭 완료',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _changePhoto(context, provider),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: GRAYSCALE_LABEL_100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 13,
                                    color: GRAYSCALE_LABEL_700,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '다시 스캔',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: GRAYSCALE_LABEL_700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Image.asset(
                                  awayTeamModel?.calenderLogo ??
                                      context.appLogoAsset,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  game.awayTeam,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: GRAYSCALE_LABEL_950,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '원정',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: GRAYSCALE_LABEL_500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: GRAYSCALE_LABEL_50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'VS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: GRAYSCALE_LABEL_500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.stadium,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: GRAYSCALE_LABEL_800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${game.season} KBO',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: GRAYSCALE_LABEL_500,
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Image.asset(
                                  homeTeamModel?.calenderLogo ??
                                      context.appLogoAsset,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  game.homeTeam,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: GRAYSCALE_LABEL_950,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '홈',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: GRAYSCALE_LABEL_500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

            // 3. 복수 매칭 경기 선택
            if (provider.matchedGames.length > 1) ...[
              const Text(
                '일치하는 경기 선택',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: GRAYSCALE_LABEL_600,
                ),
              ),
              const SizedBox(height: 8),
              ...provider.matchedGames.map((g) {
                final isSelected = game?.gameId == g.gameId;
                return InkWell(
                  onTap: () => provider.selectGame(g),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? teamColor.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? teamColor : GRAYSCALE_LABEL_300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${g.awayTeam} vs ${g.homeTeam} (${g.stadium}) · ${DateFormat('HH:mm').format(g.dateTimeKst)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected ? teamColor : BLACK,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: teamColor, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // 4. 상세 편집 필드 (Provider의 컨트롤러 사용)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GRAYSCALE_LABEL_300),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: provider.selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2010),
                        lastDate: DateTime(2030),
                        locale: const Locale('ko', 'KR'),
                      );
                      if (picked != null) {
                        await provider.updateDate(picked);
                      }
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildEditRow(
                      icon: Icons.calendar_today_outlined,
                      label: '경기 일시',
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$dateStr$timeStr',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BLACK,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_calendar_outlined,
                            size: 15,
                            color: GRAYSCALE_LABEL_400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  _buildEditRow(
                    icon: Icons.chair_outlined,
                    label: '좌석 정보',
                    child: TextField(
                      controller: provider.seatController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BLACK,
                      ),
                      decoration: const InputDecoration(
                        hintText: '예: 1루 오렌지석 205블록 12열',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: GRAYSCALE_LABEL_400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  _buildEditRow(
                    icon: Icons.payments_outlined,
                    label: '티켓 금액',
                    child: TextField(
                      controller: provider.priceController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BLACK,
                      ),
                      decoration: const InputDecoration(
                        hintText: '예: 18000 (숫자만 입력)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: GRAYSCALE_LABEL_400,
                        ),
                        suffixText: '원',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 5. 하단 적용 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: teamColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                provider.applyToRecord(context);
              },
              child: const Text(
                '직관 기록에 적용하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEditRow({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: GRAYSCALE_LABEL_600),
          const SizedBox(width: 12),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: GRAYSCALE_LABEL_600),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
