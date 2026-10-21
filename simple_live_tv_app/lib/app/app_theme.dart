import 'package:flutter/material.dart';

/// TV 端的设计基调
///
/// 投影仪是 10 尺界面: 观看距离 2~3 米, 所以正文不小于 24px,
/// 焦点必须一眼可见, 颜色跟应用图标保持同一套蓝。
class AppTheme {
  /// 画布底色(深)
  static const Color background = Color(0xff0E1726);

  /// 画布中间色
  static const Color backgroundMid = Color(0xff16233C);

  /// 卡片表面
  static const Color surface = Color(0x14FFFFFF);

  /// 卡片描边
  static const Color surfaceBorder = Color(0x1FFFFFFF);

  /// 二级文字
  static const Color textSecondary = Color(0x99FFFFFF);

  /// 直播中徽标
  static const Color liveBadge = Color(0xff18A058);

  /// 圆角
  static const double radius = 16;

  /// 间距刻度
  static const double gap = 22;

  /// 默认主色, 与设置里的"主题色"默认值一致
  static const Color defaultAccent = Color(0xff3498DB);

  /// 可选主题色
  static const List<Color> presetAccents = [
    Color(0xff3498DB),
    Color(0xff2F80ED),
    Color(0xff12B886),
    Color(0xffe8590c),
    Color(0xffAE3EC9),
  ];

  /// 焦点色 = 主色提亮
  static Color focusColor(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
  }

  /// 构建应用主题
  static ThemeData build(Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: background,
      primary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: surfaceBorder,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 42, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 26),
        bodyMedium: TextStyle(fontSize: 24),
        labelLarge: TextStyle(fontSize: 22),
        labelMedium: TextStyle(fontSize: 20),
      ),
    );
  }
}
