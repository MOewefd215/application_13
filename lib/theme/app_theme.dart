import 'package:flutter/material.dart';

/// Design tokens for "มือโปรวัยเรียน" (Student Pro)
/// Colors and shapes are matched to the reference mockups:
/// navy header, white rounded cards, amber rating stars.
class AppColors {
  static const Color navy = Color(0xFF4DC2F0);
  static const Color navyDark = Color(0xFF178ABA);
  static const Color blue = Color(0xFF55C4F1);
  static const Color background = Color(0xFFFAFDFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263544);
  static const Color textSecondary = Color(0xFF81909D);
  static const Color border = Color(0xFFE8F0F5);
  static const Color success = Color(0xFF55C9AE);
  static const Color danger = Color(0xFFEF737A);
  static const Color star = Color(0xFFFFB33F);
  static const Color purple = Color(0xFF7F8DCC);
  static const Color mint = Color(0xFF59D0CD);
  static const Color yellow = Color(0xFFFFC454);
  static const Color coral = Color(0xFFFFA66E);
  static const Color paleBlue = Color(0xFFEAF8FF);
  static const Color paleMint = Color(0xFFE8FBF7);
  static const Color paleYellow = Color(0xFFFFF6DC);
  static const Color paleOrange = Color(0xFFFFEEE2);
}

class AppRadius {
  static const double card = 28;
  static const double field = 22;
  static const double button = 24;
  static const double chip = 24;
}

class AppShadows {
  static const card = [
    BoxShadow(
      color: Color(0x120B7AA9),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color(0x1A168BB7),
      blurRadius: 24,
      offset: Offset(0, 9),
    ),
  ];
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'NotoSansThai',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.blue,
        secondary: AppColors.mint,
        surface: AppColors.card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          fontFamily: 'NotoSansThai',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.blue,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paleBlue,
        selectedColor: AppColors.blue,
        secondarySelectedColor: AppColors.blue,
        disabledColor: AppColors.border,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: const BorderSide(color: AppColors.border),
        ),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.paleBlue,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 2,
          shadowColor: AppColors.navy.withValues(alpha: 0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary),
        titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      dividerColor: AppColors.border,
    );
  }
}

/// A plain empty-state block, reused across every screen so lists,
/// histories, chats, etc. render with no seed data.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                  color: AppColors.paleYellow, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.blue)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
