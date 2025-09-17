import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordPage extends StatefulWidget {
  const IntutionRecordPage({super.key});

  @override
  State<IntutionRecordPage> createState() => _IntutionRecordPageState();
}

class _IntutionRecordPageState extends State<IntutionRecordPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => IntutionRecordProvider()..init(context),
      child: Consumer<IntutionRecordProvider>(
        builder: (context, intutionProvider, child) {
          if (intutionProvider.isLoding) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(title: Text('직관 기록')),
              body: Center(child: CircularProgressIndicator(color: BUTTON)),
            );
          }

          if (intutionProvider.myTeamSymple == null) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(title: Text('직관 기록')),
              body: Center(child: Text('응원팀이 설정되어 있지 않습니다.')),
            );
          }

          if (intutionProvider.todayGame == null) {
            return Scaffold(
              backgroundColor: BACKGROUND_COLOR,
              appBar: AppBar(title: Text('직관 기록')),
              body: Center(
                child: Text(
                  '오늘은 ${intutionProvider.myTeamSymple} 경기 일정이 없습니다.',
                ),
              ),
            );
          }

          final g = intutionProvider.todayGame!;
          final isHome = g.homeTeam == intutionProvider.myTeamSymple;

          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              title: Text('직관 기록'),
              backgroundColor: BACKGROUND_COLOR,
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Card(
                      color: BACKGROUND_COLOR,
                      child: ListTile(
                        title: Text(
                          '${intutionProvider.todayStr}'
                          '${g.dateTimeKst.hour.toString().padLeft(2, '0')}:${g.dateTimeKst.minute.toString().padLeft(2, '0')}'
                          '${g.stadium}',
                        ),
                        subtitle: Text('${g.awayTeam} VS ${g.homeTeam}'),
                        trailing: Text(g.status),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('내 팀: ${isHome ? g.homeTeam : g.awayTeam}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: intutionProvider.myScoreController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '내 팀 스코어',
                              hintText: '0~99',
                            ),
                            validator: intutionProvider.validateScore,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: intutionProvider.oppScoreContreller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '상대 스코어',
                              hintText: '0~99',
                            ),
                            validator: intutionProvider.validateScore,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: intutionProvider.saving
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final ok = await intutionProvider.save(context);
                              if (!mounted) return;
                              toastification.show(
                                context: context,
                                type: ToastificationType.success,
                                alignment: Alignment.bottomCenter,
                                autoCloseDuration: Duration(seconds: 2),
                                title: Text(ok ? '직관 기록이 저장 되었습니다' : '저장 실패'),
                              );
                            },

                      child: intutionProvider.saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Container(
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                color: BUTTON,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '저장',
                                style: TextStyle(
                                  color: WHITE,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
