class StadiumSeatPrice {
  final String seatType;
  final int weekdayPrice;
  final int weekendPrice;
  final int? weekdayTeenPrice;
  final int? weekendTeenPrice;
  final int? weekdayChildPrice;
  final int? weekendChildPrice;
  final int? weekdaySpecialPrice;
  final int? weekendSpecialPrice;

  const StadiumSeatPrice({
    required this.seatType,
    required this.weekdayPrice,
    required this.weekendPrice,
    this.weekdayTeenPrice,
    this.weekendTeenPrice,
    this.weekdayChildPrice,
    this.weekendChildPrice,
    this.weekdaySpecialPrice,
    this.weekendSpecialPrice,
  });
}

class StadiumPriceData {
  static const Map<String, List<StadiumSeatPrice>> prices = {
    '잠실': [
      StadiumSeatPrice(
        seatType: '중앙석',
        weekdayPrice: 90000,
        weekendPrice: 90000,
      ),
      StadiumSeatPrice(
        seatType: '테이블석',
        weekdayPrice: 56000,
        weekendPrice: 62000,
      ),
      StadiumSeatPrice(
        seatType: '익사이팅존',
        weekdayPrice: 30000,
        weekendPrice: 35000,
      ),
      StadiumSeatPrice(
        seatType: '블루석',
        weekdayPrice: 24000,
        weekendPrice: 26000,
      ),
      StadiumSeatPrice(
        seatType: '오렌지석',
        weekdayPrice: 22000,
        weekendPrice: 24000,
      ),
      StadiumSeatPrice(
        seatType: '레드석',
        weekdayPrice: 19000,
        weekendPrice: 21000,
      ),
      StadiumSeatPrice(
        seatType: '네이비석',
        weekdayPrice: 16000,
        weekendPrice: 18000,
      ),
      StadiumSeatPrice(
        seatType: '외야응원석',
        weekdayPrice: 8000,
        weekendPrice: 10000,
        weekdayTeenPrice: 6000,
        weekendTeenPrice: 7000,
        weekdayChildPrice: 4000,
        weekendChildPrice: 5000,
        weekdaySpecialPrice: 4000,
        weekendSpecialPrice: 5000,
      ),
    ],
    '고척': [
      StadiumSeatPrice(
        seatType: '다이아몬드클럽',
        weekdayPrice: 60000,
        weekendPrice: 90000,
      ),
      StadiumSeatPrice(
        seatType: '테이블석',
        weekdayPrice: 45000,
        weekendPrice: 75000,
      ),
      StadiumSeatPrice(
        seatType: '내야커플석',
        weekdayPrice: 25000,
        weekendPrice: 40000,
      ),
      StadiumSeatPrice(
        seatType: '다크버건디석',
        weekdayPrice: 17000,
        weekendPrice: 25000,
      ),
      StadiumSeatPrice(
        seatType: '버건디석',
        weekdayPrice: 15000,
        weekendPrice: 22000,
      ),
      StadiumSeatPrice(
        seatType: '외야석',
        weekdayPrice: 9000,
        weekendPrice: 13000,
      ),
    ],
    '문학': [
      StadiumSeatPrice(
        seatType: '그린존',
        weekdayPrice: 30000,
        weekendPrice: 40000,
      ),
      StadiumSeatPrice(
        seatType: '테이블석',
        weekdayPrice: 35000,
        weekendPrice: 45000,
      ),
      StadiumSeatPrice(
        seatType: '의자지정석',
        weekdayPrice: 15000,
        weekendPrice: 20000,
      ),
      StadiumSeatPrice(
        seatType: '홈런커플존',
        weekdayPrice: 40000,
        weekendPrice: 50000,
      ),
    ],
    '수원': [
      StadiumSeatPrice(
        seatType: '내야지정석',
        weekdayPrice: 12000,
        weekendPrice: 15000,
      ),
      StadiumSeatPrice(
        seatType: '테이블석',
        weekdayPrice: 35000,
        weekendPrice: 45000,
      ),
      StadiumSeatPrice(
        seatType: '스카이존',
        weekdayPrice: 9000,
        weekendPrice: 12000,
      ),
    ],
    '기타': [
      StadiumSeatPrice(
        seatType: '일반석',
        weekdayPrice: 10000,
        weekendPrice: 12000,
      ),
    ],
  };

  /// 구장 명칭 정규화
  static String normalizeStadiumName(String stadium) {
    if (stadium.contains('잠실')) return '잠실';
    if (stadium.contains('고척')) return '고척';
    if (stadium.contains('문학') || stadium.contains('랜더스필드')) return '문학';
    if (stadium.contains('수원') || stadium.contains('위즈파크')) return '수원';
    if (stadium.contains('대구') || stadium.contains('라이온즈파크')) return '대구';
    if (stadium.contains('광주') || stadium.contains('챔피언스필드')) return '광주';
    if (stadium.contains('대전') || stadium.contains('이글스파크')) return '대전';
    if (stadium.contains('창원') || stadium.contains('NC파크')) return '창원';
    if (stadium.contains('사직')) return '사직';
    if (stadium.contains('울산') || stadium.contains('문수')) return '울산';
    if (stadium.contains('포항')) return '포항';
    return '기타';
  }

  /// 특정 구장, 좌석, 날짜, 권종에 따른 가격 조회
  static int getPrice(
    String stadium,
    String seatType,
    DateTime date, {
    String category = '성인',
  }) {
    final String key = normalizeStadiumName(stadium);
    bool isWeekend = date.weekday >= 5;

    final stadiumData = prices[key] ?? prices['기타']!;
    final seat = stadiumData.firstWhere(
      (s) => s.seatType == seatType,
      orElse: () => stadiumData.first,
    );

    if (category == '청소년') {
      return isWeekend
          ? (seat.weekendTeenPrice ?? seat.weekendPrice)
          : (seat.weekdayTeenPrice ?? seat.weekdayPrice);
    } else if (category == '어린이') {
      return isWeekend
          ? (seat.weekendChildPrice ?? seat.weekendPrice)
          : (seat.weekdayChildPrice ?? seat.weekdayPrice);
    } else if (category == '특별할인') {
      return isWeekend
          ? (seat.weekendSpecialPrice ?? seat.weekendPrice)
          : (seat.weekdaySpecialPrice ?? seat.weekdayPrice);
    }

    return isWeekend ? seat.weekendPrice : seat.weekdayPrice;
  }

  /// 특정 구장의 좌석 등급 리스트 조회
  static List<String> getSeatTypes(String stadium) {
    final String key = normalizeStadiumName(stadium);
    final stadiumData = prices[key] ?? prices['기타']!;
    return stadiumData.map((s) => s.seatType).toList();
  }
}
