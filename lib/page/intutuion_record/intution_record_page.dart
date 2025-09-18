import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/provider/intution_record_provider.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class IntutionRecordPage extends StatefulWidget {
  const IntutionRecordPage({super.key});

  @override
  State<IntutionRecordPage> createState() => _IntutionRecordPageState();
}

class _IntutionRecordPageState extends State<IntutionRecordPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  Future<void> _selectedDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1982),
      lastDate: DateTime(2026),
      builder: (context, child) {
        final base = Theme.of(context);
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),

          child: Theme(
            data: base.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: BACKGROUND_COLOR,
                headerBackgroundColor: BACKGROUND_COLOR,
              ),
              colorScheme: base.colorScheme.copyWith(
                primary: BUTTON,
                surface: BACKGROUND_COLOR,
                onSurface: Colors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: BUTTON),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

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
          final teamProvider = context.watch<TeamProvider>();
          final g = intutionProvider.todayGame!;
          final isHome = g.homeTeam == intutionProvider.myTeamSymple;

          final myTeamSymple = intutionProvider.myTeamSymple!;
          final opponentSymple = isHome ? g.awayTeam : g.homeTeam;

          final myTeamModel =
              teamProvider.selectedTeam ??
              teamProvider.findTeamByName(myTeamSymple);
          final oppenentTeamModel = teamProvider.findTeamByName(opponentSymple);

          return Scaffold(
            backgroundColor: BACKGROUND_COLOR,
            appBar: AppBar(
              title: Text(
                '직관 기록 추가',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              backgroundColor: BACKGROUND_COLOR,
            ),
            body: Padding(
              padding: const EdgeInsets.only(
                top: 20.0,
                left: 16.0,
                right: 16.0,
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text(
                      '경기날짜',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.all(10),
                      alignment: Alignment.centerLeft,
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        border: Border.all(color: GRAYSCALE_LABEL_300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate != null
                                ? '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일'
                                : '날짜 선택',
                          ),
                          IconButton(
                            onPressed: _selectedDate,
                            icon: Icon(Icons.date_range_outlined),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '경기정보',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: BACKGROUND_COLOR,
                        border: Border.all(color: GRAYSCALE_LABEL_300),
                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Column(
                        children: [
                          // Row(
                          //   children: [
                          //     Text(
                          //       '야구장:',
                          //       style: TextStyle(
                          //         fontSize: 13,
                          //         fontWeight: FontWeight.w500,
                          //       ),
                          //     ),
                          //     Spacer(),
                          //     Text(g.stadium),
                          //   ],
                          // ),
                          // SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '응원 팀',
                                    style: TextStyle(
                                      color: GRAYSCALE_LABEL_500,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Image.asset(
                                    myTeamModel?.logoPath ??
                                        'assets/images/applogo/app_logo.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    g.homeTeam,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.only(top: 30.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'VS',
                                      style: TextStyle(
                                        fontSize: 50,
                                        color: GRAYSCALE_LABEL_500,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      g.stadium,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    '상대 팀',
                                    style: TextStyle(
                                      color: GRAYSCALE_LABEL_500,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Image.asset(
                                    oppenentTeamModel?.logoPath ??
                                        'assets/images/applogo/app_logo.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    g.awayTeam,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '스코어',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            cursorColor: BUTTON,
                            controller: intutionProvider.myScoreController,
                            keyboardType: TextInputType.number,

                            decoration: InputDecoration(
                              focusColor: BUTTON,
                              labelText: '내 팀 스코어',
                              labelStyle: TextStyle(color: GRAYSCALE_LABEL_500),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_300,
                                ),
                              ),
                            ),

                            validator: intutionProvider.validateScore,
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            cursorColor: BUTTON,
                            controller: intutionProvider.oppScoreContreller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: GRAYSCALE_LABEL_300,
                                ),
                              ),
                              labelText: '상대 스코어',
                              labelStyle: TextStyle(color: GRAYSCALE_LABEL_500),
                            ),
                            validator: intutionProvider.validateScore,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
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
