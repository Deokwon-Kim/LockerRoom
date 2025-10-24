import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  const SvgIcon({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: width,
      height: height,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
      fit: fit,
    );
  }
}

// 자주 사용하는 아이콘들을 미리 정의
class AppIcons {
  static const String home = 'assets/icons/home.svg';
  static const String homeFill = 'assets/icons/home_fill.svg';
  static const String add = 'assets/icons/add.svg';
  static const String person = 'assets/icons/person.svg';
  static const String personFill = 'assets/icons/person_fill.svg';
  static const String shop = 'assets/icons/shop.svg';
  static const String shopFill = 'assets/icons/shop_fill.svg';

  // SVG 아이콘 위젯들
  static Widget homeIcon({double? size, Color? color}) {
    return SvgIcon(assetPath: home, width: size, height: size, color: color);
  }

  static Widget homeFillIcon({double? size, Color? color}) {
    return SvgIcon(
      assetPath: homeFill,
      width: size,
      height: size,
      color: color,
    );
  }

  static Widget addIcon({double? size, Color? color}) {
    return SvgIcon(assetPath: add, width: size, height: size, color: color);
  }

  static Widget personIcon({double? size, Color? color}) {
    return SvgIcon(assetPath: person, width: size, height: size, color: color);
  }

  static Widget personFillIcon({double? size, Color? color}) {
    return SvgIcon(
      assetPath: personFill,
      width: size,
      height: size,
      color: color,
    );
  }

  static Widget shopIcon({double? size, Color? color}) {
    return SvgIcon(assetPath: person, width: size, height: size, color: color);
  }

  static Widget shopFillIcon({double? size, Color? color}) {
    return SvgIcon(
      assetPath: personFill,
      width: size,
      height: size,
      color: color,
    );
  }
}
