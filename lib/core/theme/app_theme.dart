import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

abstract final class AppSpacing {
  static const double x1 = 4.0;
  static const double x2 = 8.0;
  static const double x3 = 12.0;
  static const double x4 = 16.0;
  static const double x5 = 20.0;
  static const double x6 = 24.0;
  static const double x8 = 32.0;
  static const double x10 = 40.0;
  static const double x12 = 48.0;
}

abstract final class AppRadii {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double extraLarge = 22.0;
  static const double pill = 999.0;
}

abstract final class AppColors {
  // SWeShare Vibrant Royal Electric Blue & Accents
  static const Color primary = Color(0xFF0066FF); // SWeShare Signature Electric Blue
  static const Color primaryDark = Color(0xFF0052CC);
  static const Color primaryLight = Color(0xFF388BFD);
  static const Color primarySubtle = Color(0xFFEBF3FC); // Soft ice-blue background tint
  static const Color primaryGlow = Color(0x330066FF);

  static const Color secondary = Color(0xFF0284C7); // Sky blue secondary
  static const Color secondaryDark = Color(0xFF0369A1);
  static const Color secondaryLight = Color(0xFFBAE6FD);

  // Semantics
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF047857);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFFB45309);

  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorDark = Color(0xFFB91C1C);

  static const Color info = Color(0xFF0066FF); // Blue
  static const Color infoLight = Color(0xFFEFF6FF);

  static const Color offline = Color(0xFFEA580C); // Deep orange

  // SWeShare Light Palette: Clean White mixed with Soft Ice Blue
  static const Color lightBackground = Color(0xFFF4F7FC); // Air light ice-blue tinted canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure pristine white card
  static const Color lightSurfaceContainer = Color(0xFFEBF3FC); // Soft blue tint container
  static const Color lightSurfaceContainerHighest = Color(0xFFE1EDFA); // Interactive blue tint
  static const Color lightBorder = Color(0xFFE2EDF9); // Light blue-tinted border
  static const Color lightBorderStrong = Color(0xFFC7DCF5); // Accent outline
  static const Color lightTextPrimary = Color(0xFF0F172A); // Midnight navy slate
  static const Color lightTextSecondary = Color(0xFF475569); // Slate grey
  static const Color lightTextMuted = Color(0xFF94A3B8); // Muted slate

  // Dark Palette (Deep Navy Slate with crisp contrast — NO pure black)
  static const Color darkBackground = Color(0xFF0A0F1D); // Deep midnight navy
  static const Color darkSurface = Color(0xFF11192E); // Navy slate surface
  static const Color darkSurfaceContainer = Color(0xFF18223B); // Container
  static const Color darkSurfaceContainerHighest = Color(0xFF222F50); // Container highest
  static const Color darkBorder = Color(0xFF263556); // Navy border
  static const Color darkBorderStrong = Color(0xFF384D7A); // Strong border
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // White slate
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Soft grey
  static const Color darkTextMuted = Color(0xFF64748B); // Muted
}

abstract final class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF0052CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryLight = LinearGradient(
    colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroCard = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF1A73E8), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient iceBlue = LinearGradient(
    colors: [Color(0xFFEBF3FC), Color(0xFFF6F9FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient shimmerLight = LinearGradient(
    colors: [
      Color(0xFFEBF2FA),
      Color(0xFFFFFFFF),
      Color(0xFFEBF2FA),
    ],
    stops: [0.1, 0.5, 0.9],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  static const LinearGradient shimmerDark = LinearGradient(
    colors: [
      Color(0xFF18223B),
      Color(0xFF243254),
      Color(0xFF18223B),
    ],
    stops: [0.1, 0.5, 0.9],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}

abstract final class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0A0066FF),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x140066FF),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x400066FF),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.25,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle number = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static String formatCurrency(num amount, {bool symbol = true}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol ? '₹' : '',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E2D4E) : AppColors.primarySubtle,
      onPrimaryContainer: isDark ? const Color(0xFFBAE6FD) : AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF16324A) : const Color(0xFFE0F2FE),
      onSecondaryContainer: isDark ? const Color(0xFFBAE6FD) : AppColors.secondaryDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF5A1E1E) : AppColors.errorLight,
      onErrorContainer: isDark ? AppColors.errorLight : AppColors.errorDark,
      surface: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      surfaceContainerLowest: isDark ? const Color(0xFF070B16) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF0C1326) : const Color(0xFFF9FBFE),
      surfaceContainer: isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface,
      surfaceContainerHigh: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainer,
      surfaceContainerHighest: isDark ? const Color(0xFF2B3A60) : AppColors.lightSurfaceContainerHighest,
      outline: isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.heading2.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: 22,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: AppTypography.display.copyWith(color: colorScheme.onSurface),
        headlineLarge: AppTypography.heading1.copyWith(color: colorScheme.onSurface),
        headlineMedium: AppTypography.heading2.copyWith(color: colorScheme.onSurface),
        titleLarge: AppTypography.titleLarge.copyWith(color: colorScheme.onSurface),
        titleMedium: AppTypography.titleMedium.copyWith(color: colorScheme.onSurface),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurface),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
        labelLarge: AppTypography.button.copyWith(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceContainer.withValues(alpha: 0.6)
            : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3 + 2,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: AppTypography.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return IconThemeData(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTypography.button,
        unselectedLabelStyle: AppTypography.button.copyWith(fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.extraLarge)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.primarySubtle,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }
}
