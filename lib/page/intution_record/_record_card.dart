import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/attendance_model.dart';
import 'package:lockerroom/model/schedule_model.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/intution_record/intution_record_detail_page.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/schdule_Provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class RecordCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final AttendanceModel attendance;
  final TeamModel? recordedTeam;
  final Color recordedTeamColor;
  final bool isWin;
  final int myScore;
  final int oppScore;
  final String myTeam;
  final String oppTeam;

  const RecordCard({
    super.key,
    required this.data,
    required this.attendance,
    required this.recordedTeam,
    required this.recordedTeamColor,
    required this.isWin,
    required this.myScore,
    required this.oppScore,
    required this.myTeam,
    required this.oppTeam,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = context.select<ScheduleProvider, ScheduleModel?>(
      (sp) => sp.getById(data['gameId']),
    );

    final pageIndex = ValueNotifier<int>(0);

    final card = GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                IntutionRecordDetailPage(gameId: data['gameId']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: WHITE,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageArea(pageIndex),
            _buildGameScore(),
            _buildMeta(schedule),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Slidable(
        key: ValueKey(attendance.gameId),
        endActionPane: ActionPane(
          motion: ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (slidableContext) async {
                if (!context.mounted) return;

                try {
                  final provider = Provider.of<IntutionRecordProvider>(
                    context,
                    listen: false,
                  );

                  final success = await provider.deleteRecord(attendance);

                  if (!context.mounted) return;

                  if (success) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      title: Text('직관기록이 삭제되었습니다'),
                    );
                  } else {
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      title: Text('직관기록 삭제에 실패했습니다'),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      alignment: Alignment.bottomCenter,
                      autoCloseDuration: Duration(seconds: 2),
                      title: Text('삭제 중 오류가 발생했습니다'),
                    );
                  }
                }
              },
              backgroundColor: RED_DANGER_TEXT_50,
              foregroundColor: WHITE,
              icon: Icons.delete,
              label: '삭제',
              borderRadius: BorderRadius.circular(14),
            ),
          ],
        ),
        child: card,
      ),
    );
  }

  Widget _buildImageArea(ValueNotifier<int> pageIndex) {
    final urls = attendance.imageUrls;

    if (urls.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: recordedTeamColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        alignment: Alignment.center,
        child: recordedTeam != null
            ? Image.asset(recordedTeam!.logoPath, height: 120)
            : const SizedBox(),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            onPageChanged: (i) => pageIndex.value = i,
            itemCount: urls.length,
            itemBuilder: (_, i) {
              return ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  memCacheWidth: 900,
                  placeholder: (context, url) =>
                      Container(color: recordedTeamColor.withOpacity(0.15)),
                ),
              );
            },
          ),
        ),
        // 이미지 개수 인디케이터
        if (urls.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: ValueListenableBuilder<int>(
              valueListenable: pageIndex,
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${value + 1}/${urls.length}',
                    style: TextStyle(color: WHITE, fontSize: 13),
                  ),
                );
              },
            ),
          ),
        // 메모 표시
        if (data['memo'] != null && data['memo'].toString().trim().isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 18, color: Colors.white70),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data['memo'].toString(),
                      style: GoogleFonts.nanumPenScript(
                        fontSize: 18,
                        color: WHITE,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGameScore() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$myScore',
            style: GoogleFonts.roboto(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: isWin ? recordedTeamColor : GRAYSCALE_LABEL_500,
            ),
          ),
          SizedBox(width: 18),
          Flexible(
            child: Text(
              myTeam,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Text('vs', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              oppTeam,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 18),
          Text(
            '$oppScore',
            style: GoogleFonts.roboto(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: GRAYSCALE_LABEL_500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(ScheduleModel? schedule) {
    String _formatDate(String dateStr) {
      try {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final year = parts[0];
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          return '$year년 $month월 $day일';
        }
      } catch (e) {
        // 파싱 실패 시 원본 반환
      }
      return dateStr;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Transform.translate(
        offset: Offset(0, -10),
        child: Column(
          children: [
            Text(
              _formatDate(data['date']),

              style: TextStyle(
                color: GRAYSCALE_LABEL_500,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              data['stadium'] ?? '',
              style: TextStyle(color: GRAYSCALE_LABEL_500),
            ),
          ],
        ),
      ),
    );
  }
}
