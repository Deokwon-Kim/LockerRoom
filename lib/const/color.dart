// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

// 두산베어스
const ORANGE_PRIMARY_50 = Color(0xFFFFF3E0);
const korea = Color(0xff00022E);

const Doosan = Color.fromARGB(255, 13, 12, 40);

// SSG 랜더스
const Landers = Color(0xffCE0E2D);

// 한화 이글스
const Eagles = Color(0xffEC500F);

// 키움 히어로즈
const KIWOOM = Color(0xff570514);

// 삼성 라이온즈
const Samsung = Color(0xff004a88);

// LG 트윈스
const LG = Color(0xff9E0E31);

// 롯데 자이언츠
const Lotte = Color(0xff023255);

// NC 다이노스
const NC = Color(0xff315288);

// 기아 타이거즈
const Kia = Color(0xffBB1C22);

// KT 위즈
const KT = Color(0xff000000);

// GRAY
const GRAYSCALE_LABEL_50 = Color(0xFFF9FAFC); // background color 과 동일
const GRAYSCALE_LABEL_100 = Color(0xFFEEF0F3);
const GRAYSCALE_LABEL_200 = Color(0xFFDBDEE2);
const GRAYSCALE_LABEL_300 = Color(0xFFD5D9DD);
const GRAYSCALE_LABEL_400 = Color(0xFFA5ACB5);
const GRAYSCALE_LABEL_500 = Color(0xFF888F9C);
const GRAYSCALE_LABEL_600 = Color(0xFF717784);
const GRAYSCALE_LABEL_700 = Color(0xFF5F626E);
const GRAYSCALE_LABEL_800 = Color(0xFF4E515A);
const GRAYSCALE_LABEL_900 = Color(0xFF323439);
const GRAYSCALE_LABEL_950 = Color(0xFF202020);

// RED
const RED_DANGER_SURFACE_5 = Color(0xFFFFF2F4);
const RED_DANGER_BORDER_10 = Color(0xFFFCD4DE);
const RED_DANGER_TEXT_50 = Colors.red;

// YELLOW
const YELLOW_INFO_SURFACE_5 = Color(0xFFFFF8E9);
const YELLOW_INFO_BORDER_10 = Color(0xFFFFEAC1);
const YELLOW_INFO_BASE_30 = Color(0xFFFFB724);
const YELLOW_INFO_TEXT_50 = Color(0xFF66490E);

// GREEN
const GREEN_SUCCESS_SURFACE_5 = Color(0xFFEEF7F0);
const GREEN_SUCCESS_BORDER_10 = Color(0xFFCEE9D4);
const GREEN_SUCCESS_TEXT_50 = Color(0xFF006E18);

// BACKGROUND
const BACKGROUND_COLOR = Color(0xFFF9FAFC);

// HEART FILL COLOR
const HEART_FILL = Color(0xFFFF6262);

// HOME BUTTON COLOR (ILU Deep Navy + Coral Accent)
const BUTTON = Color(0xFF141B2D);
const ACCENT_CORAL = Color(0xFFFF5B37);

// PRIMARY
const ORANGE_PRIMARY_200 = Color(0xFFFFF2DF);
const ORANGE_PRIMARY_300 = Color(0xFFFFD59A);
const ORANGE_PRIMARY_400 = Color(0xFFFFC26A);
const ORANGE_PRIMARY_500 = Color(0xFFFFB03A); // mainColor
const ORANGE_PRIMARY_600 = Color(0xFFEA9935);
const ORANGE_PRIMARY_700 = Color(0xFFDA8A2E);
const ORANGE_PRIMARY_800 = Color(0xFFC97A27);
const ORANGE_PRIMARY_900 = Color(0xFFB36A20);
const ORANGE_PRIMARY_950 = Color(0xFF9B5A19);

// secondary_BLUE
const BLUE_SECONDARY_200 = Color(0xFFE1FBFF);
const BLUE_SECONDARY_300 = Color(0xFFBFE9F0);
const BLUE_SECONDARY_400 = Color(0xFF93CBD8);
const BLUE_SECONDARY_500 = Color(0xFF73AEC0);
const BLUE_SECONDARY_600 = Color(0xFF4A8DA3);
const BLUE_SECONDARY_700 = Color(0xFF2C718D);
const BLUE_SECONDARY_800 = Color(0xFF164F6D);

// secondary_GREEN
const GREEN_SECONDARY_300 = Color(0xFFF6FFE8);
const GREEN_SECONDARY_400 = Color(0xFFE5F1D1);
const GREEN_SECONDARY_500 = Color(0xFFCADCAE);
const GREEN_SECONDARY_600 = Color(0xFFADCC7C);
const GREEN_SECONDARY_700 = Color(0xFF8EAD5D);
const GREEN_SECONDARY_800 = Color(0XFF759248);

const WHITE = Color(0xFFFFFFFF);
const BLACK = Color(0xFF000000);

const MAP_BLUE = Color(0xFF4B70A6);
const PARK_IC = Color(0xFF74B17A);
const WALKING_IC = Color(0xFFE4697C);
const RECOMMEND_BACKGROUND = Color(0xFFE4F0FF);
const FIND_PARK_BACKGROUND = Color(0xFFEAF7EB);
const MY_RECORD_BACKGROUND = Color(0xFFFEF3F3);
const STORE_IMAGE_BUTTON = Color(0xFF4B70A6);

// DARK THEME PALETTE
const DARK_BACKGROUND_COLOR = Color(0xFF0B1020);
const DARK_CARD_COLOR = Color(0xFF141B2D);
const DARK_SURFACE_ALT_COLOR = Color(0xFF1E293B);
const DARK_BORDER_COLOR = Color(0xFF26324A);
const DARK_TEXT_PRIMARY = Color(0xFFF8FAFC);
const DARK_TEXT_SECONDARY = Color(0xFF94A3B8);

extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  String get appLogoAsset => isDarkMode
      ? 'assets/images/applogo/ilu_app_icon_dark.png'
      : 'assets/images/applogo/ilu_app_icon.png';
  Color get bgColor => isDarkMode ? DARK_BACKGROUND_COLOR : BACKGROUND_COLOR;
  Color get cardColor => isDarkMode ? DARK_CARD_COLOR : WHITE;
  Color get surfaceAltColor =>
      isDarkMode ? DARK_SURFACE_ALT_COLOR : GRAYSCALE_LABEL_100;
  Color get textPrimary => isDarkMode ? DARK_TEXT_PRIMARY : GRAYSCALE_LABEL_950;
  Color get textSecondary =>
      isDarkMode ? DARK_TEXT_SECONDARY : GRAYSCALE_LABEL_600;
  Color get textMuted => isDarkMode ? DARK_TEXT_SECONDARY : GRAYSCALE_LABEL_500;
  Color get borderColor => isDarkMode ? DARK_BORDER_COLOR : GRAYSCALE_LABEL_200;
  Color get dividerColor =>
      isDarkMode ? DARK_BORDER_COLOR : GRAYSCALE_LABEL_100;

  /// 다크모드에서 어두운 구단 컬러(두산, KT, 롯데, 키움 등)가 배경에 묻히지 않도록
  /// 명도를 보정한 읽기 쉬운 전경색을 반환합니다.
  Color readableColor(Color color) {
    if (!isDarkMode) return color;
    if (color.computeLuminance() < 0.22) {
      return Color.lerp(color, WHITE, 0.72) ?? DARK_TEXT_PRIMARY;
    }
    return color;
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: BACKGROUND_COLOR,
      cardColor: WHITE,
      dividerColor: GRAYSCALE_LABEL_100,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: BACKGROUND_COLOR,
        foregroundColor: GRAYSCALE_LABEL_950,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: WHITE),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GRAYSCALE_LABEL_50,
      ),
      colorScheme: const ColorScheme.light(
        primary: BUTTON,
        secondary: ACCENT_CORAL,
        surface: WHITE,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: DARK_BACKGROUND_COLOR,
      cardColor: DARK_CARD_COLOR,
      dividerColor: DARK_BORDER_COLOR,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: DARK_BACKGROUND_COLOR,
        foregroundColor: DARK_TEXT_PRIMARY,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: DARK_CARD_COLOR),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DARK_CARD_COLOR,
      ),
      colorScheme: const ColorScheme.dark(
        primary: ACCENT_CORAL,
        secondary: ACCENT_CORAL,
        surface: DARK_CARD_COLOR,
      ),
    );
  }
}
