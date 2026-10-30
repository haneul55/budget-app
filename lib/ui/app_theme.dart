import 'package:flutter/material.dart';

/// 앱 전체 색. 크림색 바탕, 피치색 포인트, 진한 회색 글자의 따뜻한 조합.
abstract final class AppColors {
  static const cream = Color(0xFFFFFBF0); // 바탕
  static const paper = Color(0xFFFFFDF8); // 카드·칸
  static const peach = Color(0xFFFFCBB0); // 머리줄, 선택 표시
  static const peachDeep = Color(0xFFF2A07B); // 버튼, 그래프 선
  static const peachLight = Color(0xFFFFEADF); // 금액 칩, 합계 줄
  static const peachText = Color(0xFFD27F5C); // 피치 칩 위 글자
  static const line = Color(0xFFDEDAD2); // 칸 테두리, 구분선
  static const selectedCell = Color(0xFFF2EEE8); // 오늘·선택한 칸
  static const text = Color(0xFF4A4744); // 본문 글자 (검정 대신 진한 회색)
  static const textSub = Color(0xFF7D7873); // 보조 글자
  static const textFaint = Color(0xFFB4AEA7); // 다른 달 날짜 등
  static const more = Color(0xFFD9765F); // 지난달보다 더 씀
  static const less = Color(0xFF7FA37A); // 지난달보다 덜 씀
  static const uncategorized = Color(0xFFB5AEA6); // 미분류
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.peachDeep,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.peachDeep,
        onPrimary: Colors.white,
        primaryContainer: AppColors.peach,
        onPrimaryContainer: AppColors.text,
        secondaryContainer: AppColors.peachLight,
        onSecondaryContainer: AppColors.text,
        surface: AppColors.cream,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textSub,
        surfaceContainerLowest: AppColors.paper,
        surfaceContainerLow: AppColors.paper,
        surfaceContainer: const Color(0xFFFBF5EA),
        surfaceContainerHigh: const Color(0xFFF6EFE4),
        surfaceContainerHighest: AppColors.selectedCell,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
        inverseSurface: AppColors.text,
        onInverseSurface: AppColors.cream,
        error: AppColors.more,
        surfaceTint: Colors.transparent,
      );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    iconTheme: const IconThemeData(color: AppColors.textSub),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
    cardTheme: CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.peachDeep,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.peachDeep,
        foregroundColor: Colors.white,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.paper,
      selectedColor: AppColors.peach,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(color: AppColors.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.peach
              : AppColors.paper,
        ),
        foregroundColor: const WidgetStatePropertyAll(AppColors.text),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.cream),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.peachDeep, width: 2),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.line),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.peachDeep,
      linearTrackColor: AppColors.selectedCell,
    ),
  );
}
