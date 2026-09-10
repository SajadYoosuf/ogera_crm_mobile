import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ogera_colors.dart';

/// One Material 3 theme for the whole app so every screen inherits the same
/// radii, contrast, and touch-target rules without repeating them.
class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: OgeraColors.blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: OgeraColors.blue,
          onPrimary: Colors.white,
          surface: OgeraColors.surface,
          onSurface: OgeraColors.ink,
          error: OgeraColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: OgeraColors.canvas,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OgeraColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: OgeraColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: OgeraColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
          side: const BorderSide(color: OgeraColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9BAAB8), fontSize: 14),
        labelStyle: const TextStyle(color: OgeraColors.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: OgeraColors.blue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        border: _fieldBorder(OgeraColors.line),
        enabledBorder: _fieldBorder(OgeraColors.line),
        focusedBorder: _fieldBorder(OgeraColors.blue, width: 1.6),
        errorBorder: _fieldBorder(OgeraColors.danger),
        focusedErrorBorder: _fieldBorder(OgeraColors.danger, width: 1.6),
        errorStyle: const TextStyle(color: OgeraColors.danger, fontSize: 12.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OgeraColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OgeraColors.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: OgeraColors.line),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OgeraColors.blue,
          minimumSize: const Size(0, OgeraSpacing.touchTarget),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: OgeraColors.blueSoft,
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? OgeraColors.blue : OgeraColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? OgeraColors.blue : OgeraColors.muted,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: OgeraColors.line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: OgeraColors.line,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: OgeraColors.canvas,
        side: const BorderSide(color: OgeraColors.line),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: OgeraColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OgeraSpacing.chipRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OgeraColors.ink,
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: OgeraColors.blue,
        linearTrackColor: OgeraColors.line,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: OgeraColors.muted,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: OgeraColors.ink, displayColor: OgeraColors.ink);
  }
}
