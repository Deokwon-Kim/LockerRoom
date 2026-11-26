import 'package:lockerroom/model/ticket_scan_result_model.dart';

class TicketParserService {
  static const Map<String, List<String>> teamAliases = {
    '한화': ['한화', '이글스', 'EAGLES', '한화이글스', 'HANWHA', 'ハンファ', 'イーグルス'],
    'KIA': ['KIA', '기아', '타이거즈', 'TIGERS', '기아타이거즈', 'キア', '起亜', 'タイガース'],
    '기아': ['기아', 'KIA', '타이거즈', 'TIGERS', '기아타이거즈', 'キア', '起亜', 'タイガース'],
    'LG': ['LG', '엘지', '트윈스', 'TWINS', '엘지트윈스', 'ツインズ'],
    '삼성': ['삼성', '라이온즈', 'LIONS', '삼성라이온즈', 'SAMSUNG', 'サムスン', '三星', 'ライオンズ'],
    '두산': ['두산', '베어스', 'BEARS', '두산베어스', 'DOOSAN', '투산', '斗山', 'ベアーズ'],
    'KT': ['KT', '케이티', '위즈', 'WIZ', '케이티위즈', 'ウィズ'],
    'SSG': ['SSG', '랜더스', 'LANDERS', '쓱', 'SK', '와이번스', 'WYVERNS', '에스에스지', 'ランダース'],
    'SK': ['SK', '와이번스', 'WYVERNS', 'SSG', '랜더스', 'ランダース'],
    '롯데': ['롯데', '자이언츠', 'GIANTS', '롯데자이언츠', 'LOTTE', 'ロッテ', 'ジャイアンツ'],
    'NC': ['NC', '엔씨', '다이노스', 'DINOS', '엔씨다이노스', 'ダイノス'],
    '키움': ['키움', '히어로즈', 'HEROES', '키움히어로즈', '넥센', 'NEXEN', 'KIWOOM', 'キウム', 'ヒーローズ'],
    '넥센': ['넥센', 'NEXEN', '키움', 'KIWOOM', '히어로즈', 'HEROES'],
    '대한민국': ['대한민국', '한국', 'KOREA', 'TEAM KOREA', '韓国', '大韓民国', 'KOR代表'],
    '일본': ['일본', 'JAPAN', '侍ジャパン', 'SAMURAI JAPAN'],
    '대만': ['대만', 'TAIWAN', 'CHINESE TAIPEI', '台湾', 'チャイニーズ・タイペイ', 'チャイニーズタイペイ'],
    '호주': ['호주', 'AUSTRALIA', 'オーストラリア', '豪州'],
    '체코': ['체코', 'CZECH', 'CZECHIA', 'チェコ'],
    '미국': ['미국', 'USA', 'AMERICA', 'アメリカ', '米国'],
    '중국': ['중국', 'CHINA'],
    '도미니카': ['도미니카', 'DOMINICA', 'DOMINICAN', 'ドミニカ'],
    '쿠바': ['쿠바', 'CUBA', 'キューバ'],
    '네덜란드': ['네덜란드', 'NETHERLANDS', 'オランダ'],
    '캐나다': ['캐나다', 'CANADA', 'カナダ'],
    '멕시코': ['멕시코', 'MEXICO', 'メキシコ'],
    '베네수엘라': ['베네수엘라', 'VENEZUELA', 'ベネズエラ'],
    '이스라엘': ['이스라엘', 'ISRAEL', 'イスラエル'],
  };

  /// 전각 숫자/기호 및 일본어 연호 등을 반각 표준으로 정규화
  static String _normalizeWidthAndEra(String input) {
    final buf = StringBuffer();
    for (final code in input.runes) {
      if (code >= 0xFF10 && code <= 0xFF19) {
        // ０-９ -> 0-9
        buf.writeCharCode(code - 0xFF10 + 0x30);
      } else if (code >= 0xFF21 && code <= 0xFF3A) {
        // Ａ-Ｚ -> A-Z
        buf.writeCharCode(code - 0xFF21 + 0x41);
      } else if (code >= 0xFF41 && code <= 0xFF5A) {
        // ａ-ｚ -> a-z
        buf.writeCharCode(code - 0xFF41 + 0x61);
      } else if (code == 0x3000) {
        buf.write(' ');
      } else if (code == 0xFF1A) {
        buf.write(':');
      } else if (code == 0xFF0C) {
        buf.write(',');
      } else if (code == 0xFF0E) {
        buf.write('.');
      } else if (code == 0xFF0F) {
        buf.write('/');
      } else if (code == 0xFFE5) {
        buf.write('¥');
      } else {
        buf.writeCharCode(code);
      }
    }
    var out = buf.toString();
    // 일본 레이와 연호(예: 令和8年 -> 2026年) 변환
    out = out.replaceAllMapped(
      RegExp(r'令和\s*(\d{1,2})\s*年'),
      (m) => '${2018 + int.parse(m.group(1)!)}年',
    );
    return out;
  }

  static TicketScanResultModel parse(String text) {
    final normalizedText = _normalizeWidthAndEra(text);
    // 파싱 시작 전 예매번호 전처리 제거
    final cleanText = _removeReservationNumbers(normalizedText);

    final gameDate = _extractDate(cleanText);
    final gameTime = _extractTime(cleanText);
    final detectedTeams = _extractTeams(cleanText);
    // 가격과 좌석은 '결제', '입장', '예매', '게이트' 등이 같은 줄에 포함될 수 있으므로 정규화된 원본 텍스트에서 전용 필터로 추출
    final ticketPrice = _extractPrice(normalizedText);
    final seatType = _extractSeat(normalizedText);

    return TicketScanResultModel(
      gameDate: gameDate,
      gameTime: gameTime,
      detectedTeams: detectedTeams,
      ticketPrice: ticketPrice,
      seatType: seatType,
      rawText: text,
    );
  }

  /// 한국어·일본어·라틴 OCR 결과를 지능적으로 결합하여 파싱
  static TicketScanResultModel parseEnsemble({
    required String koreanText,
    String? japaneseText,
    String? latinText,
  }) {
    final koResult = parse(koreanText);
    final jaResult = (japaneseText != null && japaneseText.trim().isNotEmpty)
        ? parse(japaneseText)
        : null;
    final latinResult = (latinText != null && latinText.trim().isNotEmpty)
        ? parse(latinText)
        : null;

    if (jaResult == null && latinResult == null) {
      return koResult;
    }

    final mergedDate =
        koResult.gameDate ?? jaResult?.gameDate ?? latinResult?.gameDate;
    final mergedTime =
        koResult.gameTime ?? jaResult?.gameTime ?? latinResult?.gameTime;
    final mergedTeams = {
      ...koResult.detectedTeams,
      if (jaResult != null) ...jaResult.detectedTeams,
      if (latinResult != null) ...latinResult.detectedTeams,
    }.toList();
    final mergedPrice =
        koResult.ticketPrice ?? jaResult?.ticketPrice ?? latinResult?.ticketPrice;
    final mergedSeat =
        koResult.seatType ?? jaResult?.seatType ?? latinResult?.seatType;

    final rawParts = [
      koreanText,
      if (japaneseText != null && japaneseText.trim().isNotEmpty) japaneseText,
      if (latinText != null && latinText.trim().isNotEmpty) latinText,
    ];

    return TicketScanResultModel(
      gameDate: mergedDate,
      gameTime: mergedTime,
      detectedTeams: mergedTeams,
      ticketPrice: mergedPrice,
      seatType: mergedSeat,
      rawText: rawParts.join('\n---\n'),
    );
  }

  // 예매번호 및 영수증 인쇄/발권/입장 시간 등 경기 시간 외 불필요 라인 제거
  static String _removeReservationNumbers(String text) {
    // 0) 일본 티켓 개장 시간("17:00 開場")만 부분 제거하여 같은 줄의 "19:00 開始"는 보존
    var result = text.replaceAll(
      RegExp(r'\d{1,2}[:;]\d{2}\s*開場|開場\s*\d{1,2}[:;]\d{2}'),
      '',
    );
    // 1) "예매", "예약", "발매", "판매", "인쇄", "발권", "입장", "개문", "취소마감" 등 경기 시작 시간과 무관한 영수증/안내/주최 라인 삭제
    result = result.replaceAll(
      RegExp(
        r'.*(?:예매|예약|티켓\s*번호|발권|바코드|QR코드|인쇄|출력|입장|관람\s*입장|개문|게이트|취소\s*마감|결제|발매|판매|発券|予約|申込|受付|購入|支払|決済|引換|再発行|バーコード|払戻|主催[:：]|共催[:：]|特別協賛[:：]).*',
        caseSensitive: false,
      ),
      '',
    );
    // 2) 영수증 하단 괄호 타임스탬프 패턴 제거 (예: 2026-09-10 (16:30), 2024.03.23 (11:00:15) 등)
    result = result.replaceAll(
      RegExp(r'\d{2,4}[.\-\/]\d{1,2}[.\-\/]\d{1,2}\s*\(\s*\d{1,2}[:;.]\d{2}(?::\d{2})?\s*\)'),
      '',
    );
    // 3) T로 시작하는 예매번호 패턴 제거 (예: T12345678, T24-12345678, T-12345 등)
    // ※ TWINS, TIGERS 같은 구단명 보호를 위해 T 뒤에 숫자(또는 -숫자)가 4개 이상 오는 것만 매칭
    result = result.replaceAll(RegExp(r'\b[Tt]-?\d{4,}[\d\-A-Za-z]*\b'), '');
    return result;
  }

  // 1. 날짜 추출 (2010년부터 지원, 다단계 정밀 매칭)
  static DateTime? _extractDate(String text) {
    // 1순위: 4자리 연도 한·일 (2010~2039) e.g., "2026년 09월 10일", "2026年3月5日"
    final matchKo4 = RegExp(
      r'(?:^|[^\d])(20[1-3]\d)\s*[년年]\s*(1[0-2]|0?[1-9])\s*[월月]\s*(3[01]|[12]\d|0?[1-9])\s*[일日]?',
    ).firstMatch(text);
    if (matchKo4 != null) {
      final y = int.parse(matchKo4.group(1)!);
      final m = int.parse(matchKo4.group(2)!);
      final d = int.parse(matchKo4.group(3)!);
      return DateTime(y, m, d);
    }

    // 2순위: 4자리 연도 기호/공백 구분 (2010~2039) e.g., "2026.09.10", "2010. 5. 18.", "2015-06-20", "2012/07/15", "2010 05 18", "2010, 05, 18"
    final matchSym4 = RegExp(
      r'(?:^|[^\d])(20[1-3]\d)\s*[.\-\/,\s]\s*(1[0-2]|0?[1-9])\s*[.\-\/,\s]\s*(3[01]|[12]\d|0?[1-9])(?!\d)',
    ).firstMatch(text);
    if (matchSym4 != null) {
      final y = int.parse(matchSym4.group(1)!);
      final m = int.parse(matchSym4.group(2)!);
      final d = int.parse(matchSym4.group(3)!);
      return DateTime(y, m, d);
    }

    // 3순위: 2자리 연도 한·일 (10~39년 -> 2010~2039) e.g., "10년 4월 3일", "26年3月5日"
    final matchKo2 = RegExp(
      r'(?:^|[^\d])([1-3]\d)\s*[년年]\s*(1[0-2]|0?[1-9])\s*[월月]\s*(3[01]|[12]\d|0?[1-9])\s*[일日]?',
    ).firstMatch(text);
    if (matchKo2 != null) {
      final y = 2000 + int.parse(matchKo2.group(1)!);
      final m = int.parse(matchKo2.group(2)!);
      final d = int.parse(matchKo2.group(3)!);
      return DateTime(y, m, d);
    }

    // 4순위: 2자리 연도 기호/공백 구분 (10~39.MM.DD -> 2010~2039) e.g., "10.04.03", "15-06-20", "24/05/18", "26. 09. 10."
    final matchSym2 = RegExp(
      r'(?:^|[^\d])([1-3]\d)\s*[.\-\/,\s]\s*(1[0-2]|0?[1-9])\s*[.\-\/,\s]\s*(3[01]|[12]\d|0?[1-9])(?!\d)',
    ).firstMatch(text);
    if (matchSym2 != null) {
      final y = 2000 + int.parse(matchSym2.group(1)!);
      final m = int.parse(matchSym2.group(2)!);
      final d = int.parse(matchSym2.group(3)!);
      return DateTime(y, m, d);
    }

    // 5순위: 월/일 한·일 형식 (예: "9월 10일", "3月5日")
    final matchKoNoYear = RegExp(
      r'(?:^|[^\d])(1[0-2]|0?[1-9])\s*[월月]\s*(3[01]|[12]\d|0?[1-9])\s*[일日]',
    ).firstMatch(text);
    if (matchKoNoYear != null) {
      final m = int.parse(matchKoNoYear.group(1)!);
      final d = int.parse(matchKoNoYear.group(2)!);
      return DateTime(DateTime.now().year, m, d);
    }

    // 6순위: 괄호 내 월.일 또는 단독 월.일 (예: "(9.10)", "09.10 (화)")
    final matchSymNoYear = RegExp(
      r'\(?\b(1[0-2]|0?[1-9])\s*[.\-\/]\s*(3[01]|[12]\d|0?[1-9])\b\)?',
    ).firstMatch(text);
    if (matchSymNoYear != null) {
      final m = int.parse(matchSymNoYear.group(1)!);
      final d = int.parse(matchSymNoYear.group(2)!);
      return DateTime(DateTime.now().year, m, d);
    }

    return null;
  }

  // 2. 시간 추출 ("오후 6시30분", "18시30분", "18:30", "18시", "오후 6시" 등 모든 형식 지원)
  static String? _extractTime(String text) {
    // 단일 문자열 구간에서 시간 파싱
    String? parseTimeFragment(String fragment) {
      // 0) 일본/한국 티켓 경기 시작 키워드가 직접 붙은 시간 최우선 ("19:00 開始", "19:00開始", "19時 開始")
      final regexStartKw = RegExp(
        r'(\d{1,2})\s*[:;시時]\s*(\d{2})?\s*[분分]?\s*(?:試合開始|開始|プレイボール)',
      );
      final matchStartKw = regexStartKw.firstMatch(fragment);
      if (matchStartKw != null) {
        int h = int.parse(matchStartKw.group(1)!);
        final minute = int.tryParse(matchStartKw.group(2) ?? '0') ?? 0;
        if (h >= 1 && h <= 7) h += 12;
        if (h >= 0 && h <= 23 && minute >= 0 && minute <= 59) {
          return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }

      // 1) 오전/오후/午前/午後/AM/PM 접두사
      final regexAmPmPre = RegExp(
        r'(오전|오후|午前|午後|AM|PM)\s*(\d{1,2})\s*(?:[:;]\s*(\d{1,2})|[시時]\s*(?:(\d{1,2})\s*[분分]?)?|[분分])',
        caseSensitive: false,
      );
      final matchAmPmPre = regexAmPmPre.firstMatch(fragment);
      if (matchAmPmPre != null) {
        final period = matchAmPmPre.group(1)!.toUpperCase();
        int h = int.parse(matchAmPmPre.group(2)!);
        final minuteStr = matchAmPmPre.group(3) ?? matchAmPmPre.group(4) ?? '0';
        final minute = int.tryParse(minuteStr) ?? 0;
        final isPm = period == '오후' || period == '午後' || period == 'PM';
        if (isPm && h < 12) {
          h += 12;
        } else if (!isPm && h == 12) {
          h = 0;
        }
        if (h >= 0 && h <= 23 && minute >= 0 && minute <= 59) {
          return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }

      // 2) 오전/오후/午前/午後/AM/PM 접미사
      final regexAmPmPost = RegExp(
        r'(\d{1,2})\s*(?:[:;]\s*(\d{1,2})|[시時]\s*(?:(\d{1,2})\s*[분分]?)?)\s*(오전|오후|午前|午後|AM|PM)',
        caseSensitive: false,
      );
      final matchAmPmPost = regexAmPmPost.firstMatch(fragment);
      if (matchAmPmPost != null) {
        int h = int.parse(matchAmPmPost.group(1)!);
        final minuteStr =
            matchAmPmPost.group(2) ?? matchAmPmPost.group(3) ?? '0';
        final minute = int.tryParse(minuteStr) ?? 0;
        final period = matchAmPmPost.group(4)!.toUpperCase();
        final isPm = period == '오후' || period == '午後' || period == 'PM';
        if (isPm && h < 12) {
          h += 12;
        } else if (!isPm && h == 12) {
          h = 0;
        }
        if (h >= 0 && h <= 23 && minute >= 0 && minute <= 59) {
          return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }

      // 3) '시'/'時' 표기 형식 (24시간 또는 야구 경기 1~7시)
      final regexSi = RegExp(
        r'(?:^|[^\d])(1\d|2[0-3]|0?\d)\s*[시時](?:\s*(\d{1,2})\s*[분分]?|\s*[분分])?(?![가-힣])',
      );
      final matchSi = regexSi.firstMatch(fragment);
      if (matchSi != null) {
        int h = int.parse(matchSi.group(1)!);
        final minuteStr = matchSi.group(2) ?? '0';
        final minute = int.tryParse(minuteStr) ?? 0;
        // 야구 경기 맥락: 1~7시는 오후(13~19시)로 보정
        if (h >= 1 && h <= 7) {
          h += 12;
        }
        if (h >= 0 && h <= 23 && minute >= 0 && minute <= 59) {
          return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }

      // 4) 24시간 디지털 표기 (콜론/세미콜론): "18:30", "18 : 30", "18;30", "17:00", "14:00"
      final regex24h = RegExp(
        r'(?:^|[^\d])(1\d|2[0-3])\s*[:;]\s*([0-5]\d)(?:\s*분)?(?!\d)',
      );
      final match24h = regex24h.firstMatch(fragment);
      if (match24h != null) {
        final h = match24h.group(1)!.padLeft(2, '0');
        final m = match24h.group(2)!.padLeft(2, '0');
        return '$h:$m';
      }

      // 5) 24시간 도트(.) 표기: "18.30", "17.00" (날짜 09.10과의 오인 방지를 위해 13시 이상만 허용)
      final regexDotTime = RegExp(
        r'(?:^|[^\d])(1[3-9]|2[0-3])\s*\.\s*([0-5]\d)(?:\s*분)?(?!\d)',
      );
      final matchDot = regexDotTime.firstMatch(fragment);
      if (matchDot != null) {
        final h = matchDot.group(1)!.padLeft(2, '0');
        final m = matchDot.group(2)!.padLeft(2, '0');
        return '$h:$m';
      }

      // 6) 12시간 디지털 콜론/세미콜론 야구 맥락: "6:30", "2:00", "5:00" -> 18:30, 14:00, 17:00
      final regex12h = RegExp(
        r'(?:^|[^\d])([1-7])\s*[:;]\s*([0-5]\d)(?:\s*분)?(?!\d)',
      );
      final match12h = regex12h.firstMatch(fragment);
      if (match12h != null) {
        final h =
            (int.parse(match12h.group(1)!) + 12).toString().padLeft(2, '0');
        final m = match12h.group(2)!.padLeft(2, '0');
        return '$h:$m';
      }

      return null;
    }

    final lines = text.split('\n');

    // 1순위: 날짜나 경기 관련 키워드가 포함된 라인에서 시간 우선 탐색
    for (final line in lines) {
      if (RegExp(r'(?:경기\s*일시|경기\s*시간|일시|試合開始|開始|プレイボール|GAME|\d{2,4}\s*[년年]|\d{2,4}[.\-\/]\d{1,2})')
          .hasMatch(line)) {
        final t = parseTimeFragment(line);
        if (t != null) return t;
      }
    }

    // 2순위: 전체 텍스트 라인 순차 탐색
    for (final line in lines) {
      final t = parseTimeFragment(line);
      if (t != null) return t;
    }

    return null;
  }

  // 3. 팀 추출
  static List<String> _extractTeams(String text) {
    final cleanText = text.replaceAll(' ', '').toUpperCase();
    final found = <String>{};
    for (final entry in teamAliases.entries) {
      for (final alias in entry.value) {
        if (cleanText.contains(alias.replaceAll(' ', '').toUpperCase())) {
          found.add(entry.key);
          break;
        }
      }
    }
    return found.toList();
  }

  // 4. 티켓 가격 추출 (5,000원 ~ 300,000원 사이 검증, 할인 문구 제외)
  static int? _extractPrice(String text) {
    // '2,000원 할인' 등 할인 안내 문구만 부분 제거 (결제금액/입장권 라인은 보존)
    final priceText = text.replaceAll(
      RegExp(r'[0-9,.]+\s*원?\s*할인'),
      '',
    );

    // 1순위: 금액/가격/합계/결제 키워드나 통화 기호(원, ₩, 円, ¥)가 붙은 경우
    final priorityRegex = RegExp(
      r'(?:금액|결제|가격|티켓|입장권|합계|일반|성인|料金|価格|金額|合計|小計|おとな|大人)\s*[:：]?\s*[₩￦\\¥]?\s*([1-9]\d{0,2}(?:[,.]\d{3})+|[1-9]\d{2,5})\s*(?:원|KRW|円|JPY)?|[₩￦\\¥]\s*([1-9]\d{0,2}(?:[,.]\d{3})+|[1-9]\d{2,5})|([1-9]\d{0,2}(?:[,.]\d{3})+|[1-9]\d{2,5})\s*(?:원|KRW|円|JPY)',
      caseSensitive: false,
    );
    final priorityMatches = priorityRegex.allMatches(priceText);
    for (final match in priorityMatches) {
      final fullMatch = match.group(0) ?? '';
      final isJpy = fullMatch.contains('円') ||
          fullMatch.contains('¥') ||
          fullMatch.toUpperCase().contains('JPY');
      final minPrice = isJpy ? 500 : 5000;
      final rawStr = match.group(1) ?? match.group(2) ?? match.group(3);
      final numStr = rawStr?.replaceAll(RegExp(r'[,.]'), '');
      if (numStr != null) {
        final price = int.tryParse(numStr);
        if (price != null && price >= minPrice && price <= 300000) {
          return price;
        }
      }
    }

    // 2순위: 콤마가 포함된 금액 포맷 숫자 (예: 26,000)
    final commaRegex = RegExp(r'\b([1-9]\d{0,2},\d{3})\b');
    final commaMatches = commaRegex.allMatches(priceText);
    for (final match in commaMatches) {
      final numStr = match.group(1)?.replaceAll(',', '');
      if (numStr != null) {
        final price = int.tryParse(numStr);
        if (price != null && price >= 5000 && price <= 300000) {
          return price;
        }
      }
    }
    return null;
  }

  // 5. 좌석명 추출 (스캔한 텍스트 그대로: 등급명 + 블럭/구역/열/번 결합, OCR 오타 보정 포함)
  static String? _extractSeat(String text) {
    final noiseRegex = RegExp(
      r'예매\s*번호|예약\s*번호|티켓\s*번호|발권\s*번호|바코드|QR코드|발매처|인쇄일|한함|카드|제외|홈페이지|무통장|입금|주차|유의사항|취소|환불|문의|할인|発券|予約|申込|受付|購入|支払|決済|払戻|再発行|注意事項|ご注意|手数料|税込',
      caseSensitive: false,
    );
    final dateOrMatchupRegex = RegExp(
      r'\d{2,4}\s*[년年]|\d{1,2}\s*[월月]\s*\d{1,2}\s*[일日]|\d{1,2}\s*[시時]\s*\d{0,2}\s*[분分]?|\d{2}:\d{2}|\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2}|\bvs\b|(?:원|円)\s*$',
      caseSensitive: false,
    );
    final teamOnlyRegex = RegExp(
      r'^(?:두산|키움|LG|SSG|KT|NC|KIA|기아|롯데|삼성|한화|SK|넥센|베어스|히어로즈|트윈스|랜더스|위즈|다이노스|타이거즈|자이언츠|라이온즈|이글스|일반|성인|청소년|어린이|おとな|大人|こども|小人)$',
      caseSensitive: false,
    );
    final gradeRegex = RegExp(
      r'(?:[13]루(?:측|쪽)?|[13一三]塁(?:側)?|중앙|내야|외야|内野|外野|バックネット|レフト|ライト|[1-5][층階])|(?:석|존|클럽|테이블|탁자|그린|스카이|라운지|박스|데크|캠핑|패밀리|VIP|익사이팅|네이비|오렌지|레드|블루|옐로우|버건디|지정|자유|응원|프리미엄|테라스|홈런|커플|로얄|다이아|몬스터|바베큐|피크닉|잔디|指定席|自由席|指定|自由|エキサイト|プレミアム|スイート|バルコニー|スカイ|SS席|S席|A席|B席|C席|席)',
      caseSensitive: false,
    );
    // '3열'이 '3일', '3얼', '3엘'로 오인식된 경우도 좌석 상세 라인으로 포착 (+ 일본어 ゲート/通路/ブロック/列/番/段)
    final detailRegex = RegExp(
      r'(?:\d+|[A-Za-z])\s*(?:블록|블럭|블력|불럭|볼럭|블랙|구역|구억|구여|섹션|열|얼|엘|일|번|빈|변|ゲート|通路|ブロック|列|番|段)',
    );
    final prefixLabelRegex = RegExp(r'^(?:좌석\s*(?:정보|번호|등급)?\s*[:：]\s*)');

    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceFirst(prefixLabelRegex, '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? gradeLine;
    int gradeIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (noiseRegex.hasMatch(line) ||
          dateOrMatchupRegex.hasMatch(line) ||
          teamOnlyRegex.hasMatch(line)) {
        continue;
      }
      if (gradeRegex.hasMatch(line) && line.length >= 2) {
        gradeLine = line;
        gradeIdx = i;
        // 이미 같은 줄에 블럭/구역/열/번 상세 정보까지 함께 적혀 있으면 오타 보정 후 반환
        if (detailRegex.hasMatch(line)) {
          return _normalizeSeatText(line);
        }
        break;
      }
    }

    // 좌석 등급 줄을 찾았다면 인접한 줄(다음 1~2줄 우선, 없으면 이전 1줄)에서 블럭/구역/열/번 상세 정보를 찾아 결합
    if (gradeLine != null) {
      final collectedDetails = <String>[];
      final candidateIndices = <int>[
        if (gradeIdx + 1 < lines.length) gradeIdx + 1,
        if (gradeIdx + 2 < lines.length) gradeIdx + 2,
      ];
      for (final idx in candidateIndices) {
        final neighbor = lines[idx];
        if (noiseRegex.hasMatch(neighbor) ||
            dateOrMatchupRegex.hasMatch(neighbor)) {
          continue;
        }
        if (detailRegex.hasMatch(neighbor) || gradeRegex.hasMatch(neighbor)) {
          collectedDetails.add(neighbor);
        }
      }
      if (collectedDetails.isEmpty && gradeIdx - 1 >= 0) {
        final prev = lines[gradeIdx - 1];
        if (!noiseRegex.hasMatch(prev) &&
            !dateOrMatchupRegex.hasMatch(prev) &&
            detailRegex.hasMatch(prev)) {
          collectedDetails.add(prev);
        }
      }
      if (collectedDetails.isNotEmpty) {
        return _normalizeSeatText('$gradeLine ${collectedDetails.join(' ')}');
      }
      return _normalizeSeatText(gradeLine);
    }

    // 등급명 없이 블럭/구역/열/번만 표기된 경우 (예: "1층 A구역 2열 7번", "306블럭 3열 39번")
    for (final line in lines) {
      if (noiseRegex.hasMatch(line) || dateOrMatchupRegex.hasMatch(line)) {
        continue;
      }
      if (detailRegex.hasMatch(line)) {
        return _normalizeSeatText(line);
      }
    }

    return null;
  }

  /// 좌석 텍스트 내 흔한 OCR 오인식 보정 (예: '3일' -> '3열', '306불럭' -> '306블럭', '39빈' -> '39번')
  static String _normalizeSeatText(String seat) {
    var s = seat.trim();

    // 1) 1루 / 3루 오인식 보정 (1투, 1류, I루, l루 -> 1루 / 3투, 3류 -> 3루)
    s = s.replaceAllMapped(
      RegExp(r'(^|\s)[Il1]\s*(?:루|투|류)(?=\s|[가-힣]|$)'),
      (m) => '${m.group(1)}1루',
    );
    s = s.replaceAllMapped(
      RegExp(r'(^|\s)3\s*(?:투|류)(?=\s|[가-힣]|$)'),
      (m) => '${m.group(1)}3루',
    );

    // 2) 블럭 / 블록 오인식 보정 (306불럭, 306블력, 306볼럭, 306블랙 -> 306블럭)
    s = s.replaceAllMapped(
      RegExp(r'(\d+|[A-Za-z])\s*(?:블력|불럭|볼럭|블랙|불록|볼록|블릭|불릭)'),
      (m) => '${m.group(1)}블럭',
    );

    // 3) 구역 오인식 보정 (102구억, A구여 -> 102구역)
    s = s.replaceAllMapped(
      RegExp(r'(\d+|[A-Za-z])\s*(?:구억|구여|구영|구연)'),
      (m) => '${m.group(1)}구역',
    );

    // 4) 열 오인식 보정 ('3일', '3얼', '3엘', '3연' -> '3열')
    // - 뒤에 '숫자+번/빈/변/호'가 오거나 줄 끝인 경우
    s = s.replaceAllMapped(
      RegExp(r'(\d+|[A-Za-z])\s*(?:일|얼|엘|연)(?=\s+\d+\s*(?:번|빈|변|반|호)?|\s*$)'),
      (m) => '${m.group(1)}열',
    );
    // - 앞에 '블럭/블록/구역/섹션/존/석/층/루'가 있는 경우
    s = s.replaceAllMapped(
      RegExp(r'((?:블럭|블록|구역|섹션|존|석|층|루)\s+[A-Za-z0-9\-]+\s*)(?:일|얼|엘|연)(?=\s|$)'),
      (m) => '${m.group(1)}열',
    );

    // 5) 번 오인식 보정 ('39빈', '39변', '39반' -> '39번')
    s = s.replaceAllMapped(
      RegExp(r'(\d+)\s*(?:빈|변|반|벉)(?=\s|$)'),
      (m) => '${m.group(1)}번',
    );

    // 6) 좌석 등급 '~석' 오인식 보정 ('네이비식', '오렌지서' -> '네이비석', '오렌지석')
    s = s.replaceAllMapped(
      RegExp(
        r'(네이비|오렌지|레드|블루|옐로우|버건디|그린|지정|자유|테이블|탁자|내야|외야|중앙|응원|프리미엄|VIP|패밀리|커플|스카이|다크|로얄|다이아|익사이팅)(?:식|서|셔)(?=\s|$)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}석',
    );

    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
