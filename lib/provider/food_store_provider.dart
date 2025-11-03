import 'package:flutter/cupertino.dart';
import 'package:lockerroom/model/food_store_model.dart';

class FoodStoreProvider extends ChangeNotifier {
  final Map<String, List<FoodStoreModel>> _foodStoreList = {
    '잠실야구장': [
      FoodStoreModel(
        storeName: '통밥',
        location: '1루내야 2.5층, 3루내야 2층',
        type: '한식',
      ),
      FoodStoreModel(storeName: '원샷치킨', location: '3루외부', type: '치킨'),
      FoodStoreModel(storeName: '원샷치킨_1루광장', location: '1루광장', type: '치킨'),
      FoodStoreModel(storeName: '원샷치킨_3루광장', location: ' 3루광장', type: '치킨'),
      FoodStoreModel(
        storeName: '원샷치킨_내야상단',
        location: '331블럭 상단, 304블럭 상단',
        type: '치킨',
      ),
      FoodStoreModel(
        storeName: '이가네 떡볶이',
        location: '1루내야 2층, 3루광장',
        type: '분식',
      ),
      FoodStoreModel(
        storeName: '명인만두',
        location: '1,3루 내야 2층, 외야외부',
        type: '분식',
      ),
      FoodStoreModel(storeName: '미스터 피자', location: '3루 내야 2층', type: '피자'),
      FoodStoreModel(
        storeName: '프랭크 버거',
        location: '외부, 1,3루 내야 2층, 1루내야 3층',
        type: '버거',
      ),
      FoodStoreModel(storeName: 'BBQ/꼬꼬닭', location: '1,3루 내야 2층', type: '치킨'),
      FoodStoreModel(storeName: '죠스떡볶이', location: '3루광장', type: '분식'),
      FoodStoreModel(storeName: '브리쉘 프라이', location: '1루내야 2.5층', type: '감자튀김'),
      FoodStoreModel(storeName: '짝태패밀리', location: '3루내야 2.5층', type: '건어물'),
      FoodStoreModel(
        storeName: 'GS25',
        location: '외부 1,3루 내야, 외야',
        type: '편의점',
      ),
      FoodStoreModel(
        storeName: '신철판 야채곱창',
        location: '1루 내야 출입문 우측',
        type: '한식',
      ),
      FoodStoreModel(storeName: 'BBQ치킨', location: '3루외부', type: '치킨'),
      FoodStoreModel(storeName: 'BBQ치킨_외야', location: '외야외부', type: '치킨'),
      FoodStoreModel(storeName: 'BBQ치킨_3루내야 ', location: '3루내야 2층', type: '치킨'),

      FoodStoreModel(
        storeName: 'BBQ치킨_1루내야',
        location: '1루내야 2층, 1루내야 3층',
        type: '치킨',
      ),
      FoodStoreModel(storeName: 'BHC치킨', location: '3루외부', type: '치킨'),
      FoodStoreModel(storeName: '1994백미당', location: '1루내야 2층', type: '커피, 음료'),
      FoodStoreModel(storeName: 'OBC 수제맥주', location: '1루내야 2층', type: '수제맥주'),
      FoodStoreModel(storeName: '앤티엔스프레즐', location: '1루내야 2층', type: '프레즐'),
      FoodStoreModel(storeName: '미스터피자', location: '3루외부, 3루광장', type: '피자'),
      FoodStoreModel(storeName: '카페바른생활', location: '3루외부', type: '커피,음료'),
      FoodStoreModel(storeName: '자문밖', location: '3루외부', type: '국수,떡갈비'),
      FoodStoreModel(storeName: '수내닭꼬치', location: '외야외부, 3루광장', type: '닭꼬치'),
      FoodStoreModel(storeName: '달콤커피', location: '1루광장', type: '커피,음료'),
      FoodStoreModel(
        storeName: 'KFC치킨',
        location: '1루외부, 3루내야 2,3층',
        type: '치킨',
      ),
      FoodStoreModel(storeName: '광장식당', location: '1루외부', type: '분식'),
      FoodStoreModel(storeName: '꼬꼬닭 닭강정', location: '1루외부', type: '닭강정'),
      FoodStoreModel(storeName: '도미노 피자', location: '1루외부', type: '피자'),
      FoodStoreModel(storeName: '홈런마트', location: '1루외부', type: '편의점'),
      FoodStoreModel(storeName: 'XOXO핫도그', location: '3루광장', type: '핫도그,음료'),
      FoodStoreModel(
        storeName: '갑또리 닭강정',
        location: '1루내야 광장, 3루내야 2층',
        type: '닭강정',
      ),
      FoodStoreModel(storeName: '달콤커피', location: '3루내야 2층', type: '커피,음료'),
      FoodStoreModel(storeName: '요아정', location: '3루내야 2층', type: '요거트'),
      FoodStoreModel(storeName: '와팡', location: '3루내야 2,3층', type: '와플아이스크림'),
      FoodStoreModel(storeName: '카페그라운드', location: '3루내야 2층', type: '커피,음료'),
      FoodStoreModel(
        storeName: '피자헛',
        location: '1루내야 2층, 3루내야 2층',
        type: '피자',
      ),
      FoodStoreModel(
        storeName: '스테프핫도그',
        location: '1루내야3층, 3루내야 3층',
        type: '핫도그',
      ),
      FoodStoreModel(storeName: '야구애꼬치다', location: '316블럭 상단', type: '꼬치'),
      FoodStoreModel(storeName: '올떡', location: '318블럭 상단', type: '분식'),
    ],

    '고척스카이돔': [
      FoodStoreModel(
        storeName: '쉬림프 셰프_내야',
        location: '내야 3번 게이트 ',
        type: '크림새우',
      ),
      FoodStoreModel(
        storeName: '쉬림프 셰프_외야',
        location: '외야 4층 21번 게이트 ',
        type: '크림새우',
      ),
      FoodStoreModel(storeName: 'BHC치킨', location: '내야 3번 게이트 ', type: '치킨'),
      FoodStoreModel(
        storeName: '메머드커피_내야',
        location: '내야 3번, 11번 게이트 ',
        type: '커피,음료',
      ),
      FoodStoreModel(
        storeName: '메머드커피_외야',
        location: '외야 4번 게이트 ',
        type: '커피,음료',
      ),
      FoodStoreModel(storeName: '멕시카나치킨', location: '내야 4번 게이트 ', type: '치킨'),
      FoodStoreModel(storeName: '쉬림프 셰프', location: '내야 3번 게이트 ', type: '크림새우'),
      FoodStoreModel(
        storeName: '유부빚는마을',
        location: '내야 5번 게이트 , 외야 1번 게이트 ',
        type: '고기세트',
      ),
      FoodStoreModel(storeName: '제일버거', location: '내야 2번 게이트 ', type: '햄버거'),
      FoodStoreModel(storeName: '펠리스돔', location: '내야 5번 게이트 ', type: '샌드위치'),
      FoodStoreModel(storeName: '제일버거', location: '내야 2번 게이트 ', type: '햄버거'),
      FoodStoreModel(storeName: '편밀밀', location: '내야 4번 게이트 ', type: '분식'),
      FoodStoreModel(storeName: '편의점', location: '내야 2, 11번 게이트 ', type: '편의점'),
      FoodStoreModel(storeName: '피자', location: '내야 2번 게이트 ', type: '피자'),
      FoodStoreModel(
        storeName: 'BBQ, 맘스터치',
        location: '내야 10번 게이트 , 외야 4번 게이트 ',
        type: '치킨, 햄버거',
      ),
      FoodStoreModel(storeName: '마왕족발', location: '내야 9번 게이트 ', type: '족발'),
      FoodStoreModel(
        storeName: '스테프핫도그',
        location: '내야 11번 게이트 , 외야 4번 게이트 ',
        type: '핫도그',
      ),
      FoodStoreModel(
        storeName: '자담치킨',
        location: '내야 10번 게이트 , 외야 3번 게이트 ',
        type: '치킨',
      ),
      FoodStoreModel(storeName: '스트릿 츄러스', location: '내야 8번 게이트 ', type: '츄러스'),
      FoodStoreModel(
        storeName: '올떡볶이',
        location: '내야 4,9번 게이트 , 외야 2번 게이트 ',
        type: '분식',
      ),
      FoodStoreModel(storeName: '초장집', location: '내야 10번 게이트 ', type: '육회'),
      FoodStoreModel(
        storeName: '닭강정, BHC',
        location: '외야 4번 게이트 ',
        type: '닭강정, 치킨',
      ),
      FoodStoreModel(storeName: '멘야파이토', location: '외야 3번 게이트 ', type: '라멘'),
      FoodStoreModel(
        storeName: '제일버거, 요거트',
        location: '외야 4층 26번 게이트 ',
        type: '햄버거, 요거트',
      ),
    ],

    '랜더스필드': [
      FoodStoreModel(storeName: 'STATION', location: '1루 202섹션 ', type: '크림새우'),
      FoodStoreModel(storeName: 'BHC치킨', location: '1루 2층 203섹션 ', type: '치킨'),
      FoodStoreModel(storeName: '패밀리푸드존', location: '1루 2층 203섹션 ', type: '분식'),
      FoodStoreModel(storeName: '노랑통닭', location: '1루 2층 201섹션 ', type: '치킨'),
      FoodStoreModel(storeName: '노브랜드버거', location: '1루 2층 201섹션', type: '햄버거'),
      FoodStoreModel(storeName: '몬칩 팩토리', location: '1루 2층 202섹션', type: '닭강정'),
      FoodStoreModel(
        storeName: '허갈닭강정/문학철판삼겹',
        location: '1루 2층 202섹션',
        type: '닭강정/삼겹살',
      ),
      FoodStoreModel(
        storeName: '씬난다스테이크&마라새우',
        location: '1루 2층 202섹션',
        type: '스테이크/마라새우',
      ),
      FoodStoreModel(storeName: '스타벅스', location: '1루 2층 201섹션', type: '커피,음료'),
      FoodStoreModel(storeName: '커빙', location: '1루 2층 202섹션', type: '커피,음료'),
      FoodStoreModel(
        storeName: '우리동네 미미네',
        location: '1루 4층 316섹션',
        type: '편의점',
      ),
      FoodStoreModel(storeName: '파파존스', location: '1루 4층 313섹션', type: '피자'),
      FoodStoreModel(storeName: '먹거리 분식', location: '3루 2층 204섹션', type: '분식'),
      FoodStoreModel(
        storeName: '쌈빠치킨 떡볶이',
        location: '3루 2층 206섹션',
        type: '치킨,떡볶이',
      ),
      FoodStoreModel(storeName: '이마트24', location: '3루 2층 206섹션', type: '편의점'),
      FoodStoreModel(storeName: '킹콩떡볶이', location: '3루 2층 205섹션', type: '분식'),
      FoodStoreModel(
        storeName: 'BHC/드림마켓',
        location: '1루 1층 103섹션',
        type: '치킨,편의점',
      ),
      FoodStoreModel(
        storeName: '스타벅스2호점',
        location: '1루 1층 104섹션',
        type: '커피,음료',
      ),
      FoodStoreModel(storeName: '스트릿츄러스', location: '1루 1층 103섹션', type: '츄러스'),
      FoodStoreModel(
        storeName: 'pick me 31',
        location: '1루 1층 103섹션',
        type: '와인',
      ),
      FoodStoreModel(storeName: 'T mart', location: '1루 1층 105섹션', type: '편의점'),
      FoodStoreModel(storeName: '국대떡볶이', location: '1루 1층 105섹션', type: '분식'),
      FoodStoreModel(storeName: '버거트레일러', location: '1루 1층 102섹션', type: '햄버거'),
      FoodStoreModel(
        storeName: '우리동네 미미네_1층',
        location: '1루 1층 104섹션',
        type: '분식',
      ),
      FoodStoreModel(
        storeName: '이마트24_1층',
        location: '1루 1층 102섹션',
        type: '편의점',
      ),
      FoodStoreModel(storeName: '오레오츄러스', location: '3루 1층 109섹션', type: '츄러스'),
      FoodStoreModel(storeName: '북촌손만두', location: '3루 1층 107섹션', type: '만두'),
      FoodStoreModel(storeName: '푸라닭', location: '3루 1층 108섹션', type: '치킨'),
      FoodStoreModel(
        storeName: '오사카야끼,그루터기',
        location: '3루 1층 108섹션',
        type: '야끼소바, 스낵',
      ),
      FoodStoreModel(
        storeName: '순살싸다리',
        location: '1루외야 2층 바비큐존',
        type: '크림새우,치킨',
      ),
      FoodStoreModel(storeName: '명인만두', location: '1루 외야 2층', type: '만두,족발'),
      FoodStoreModel(
        storeName: 'BHC치킨_외야',
        location: '1루 외야 2층 204블럭',
        type: '치킨',
      ),
      FoodStoreModel(storeName: '크리스피도넛', location: '1루 외야 2층', type: '도넛'),
      FoodStoreModel(storeName: '스트릿츄러스', location: '1루 외야 2층', type: '츄러스'),
      FoodStoreModel(storeName: '우이락 고추튀김', location: '1루 외야 2층', type: '고추튀김'),
      FoodStoreModel(
        storeName: '블루시드 커피',
        location: '1루 외야 2층 204블럭',
        type: '커피,음료',
      ),
      FoodStoreModel(
        storeName: '야구사랑',
        location: '1루 외야 2층 204블럭',
        type: '크림새우',
      ),
      FoodStoreModel(storeName: '민영활어공장', location: '3루 외부', type: '초밥/물회'),
    ],

    '위즈파크': [
      FoodStoreModel(storeName: '끼부리또', location: '1루 2층 하단', type: '부리또,타코'),
      FoodStoreModel(storeName: '또리펍', location: '1루 2층 하단', type: '맥주'),
      FoodStoreModel(storeName: '롯데리아', location: '1루 2층 상단', type: '햄버거'),
      FoodStoreModel(storeName: '빅카페', location: '1루 2층 하단', type: '커피,음료'),
      FoodStoreModel(storeName: '세븐일레븐_1루', location: '1루 매장', type: '편의점'),
      FoodStoreModel(
        storeName: '세븐일레븐_1루내야',
        location: '1루 내야 GATE2',
        type: '편의점',
      ),
      FoodStoreModel(storeName: '솜사탕', location: '1루 GATE4', type: '솜사탕'),
      FoodStoreModel(storeName: '이대로 통삼겹', location: '1루 2층 하단', type: '삼겹살'),
      FoodStoreModel(storeName: '파파존스', location: '1루 2층 상단', type: '피자'),
      FoodStoreModel(storeName: 'BHC치킨', location: '1루 2층 하단', type: '치킨'),
      FoodStoreModel(storeName: '브리쉘프라이', location: '1루 2층 하단', type: '감자튀김'),
      FoodStoreModel(storeName: '오늘의 초밥', location: '1루 2층 하단', type: '초밥'),
      FoodStoreModel(storeName: '스트릿 츄러스', location: '1루 2층 상단', type: '츄러스'),
      FoodStoreModel(storeName: '완미족발', location: '1루 2층 싱단', type: '족발'),
      FoodStoreModel(storeName: '또리펍_3루', location: '3루 2층 하단', type: '맥주'),
      FoodStoreModel(storeName: '빅카페_3루', location: '3루 2층 하단', type: '커피,음료'),
      FoodStoreModel(storeName: '삼구삼진 휴게소', location: '3루 2층 싱단', type: '스낵'),
      FoodStoreModel(storeName: '샐러리아', location: '3루 2층 싱단', type: '포케'),
      FoodStoreModel(storeName: '세븐일레븐_3루', location: '3루 2층 하단', type: '편의점'),
      FoodStoreModel(storeName: '쉬림프 쉐프', location: '3루 2층 하단', type: '크림새우'),
      FoodStoreModel(storeName: '홈런분식', location: '3루 2층 하단', type: '분식'),
      FoodStoreModel(storeName: '메가닭꼬치', location: '3루 2층 싱단', type: '닭꼬치'),
      FoodStoreModel(storeName: '보영만두', location: '3루 2층 하단', type: '만두,쫄면'),
      FoodStoreModel(storeName: '본수원갈비', location: '3루 2층 하단', type: 'LA갈비'),
      FoodStoreModel(storeName: '삼미제빵소', location: '3루 2층 싱단', type: '빵,쿠키'),
      FoodStoreModel(
        storeName: '요거트월드',
        location: '3루 2층 하단',
        type: '요거트 아이스크림',
      ),
      FoodStoreModel(storeName: '전설의곱창', location: '3루 2층 히단', type: '곱창'),
      FoodStoreModel(storeName: '정지영커피', location: '3루 2층 하단', type: '커피,음료'),
      FoodStoreModel(storeName: '진미통닭', location: '3루 2층 하단', type: '치킨'),
      FoodStoreModel(storeName: '세븐일레븐_3루 5층', location: '3루 5층', type: '편의점'),
      FoodStoreModel(storeName: '세븐일레븐_3루 중앙', location: '3루 중앙', type: '편의점'),
      FoodStoreModel(storeName: '세븐일레븐_외야', location: '외야 중앙 테라스', type: '편의점'),
      FoodStoreModel(storeName: '빅또리카페', location: '외부 1층 중앙', type: '커피,음료'),
      FoodStoreModel(storeName: '세븐일레븐_외부', location: '외부 1층 중앙', type: '편의점'),
    ],

    '한화생명볼파크': [],

    '챔피언스필드': [],

    '라이온즈 파크': [],

    '창원NC파크': [],

    '사직야구장': [],
  };

  FoodStoreModel? _selectedStore;

  List<FoodStoreModel> getStore(String category) {
    return _foodStoreList[category] ?? [];
  }

  FoodStoreModel? get selectedStore => _selectedStore;

  void selectStore(FoodStoreModel food) {
    _selectedStore = food;
    notifyListeners();
  }

  void clearSelectStore() {
    _selectedStore = null;
    notifyListeners();
  }
}
