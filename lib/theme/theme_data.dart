// lib/theme/theme_data.dart — MaterialApp theme.
import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildTheme() {
  final cs = const ColorScheme.dark().copyWith(
    primary:          Bk.accent,
    onPrimary:        const Color(0xFF06141E),
    secondary:        Bk.accent,
    tertiary:         Bk.accent,
    error:            Bk.danger,
    surface:          Bk.surface1,
    onSurface:        Bk.textPri,
    outline:          Bk.glassBorder,
    surfaceContainer: Bk.surface1,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashColor: Bk.accent.withOpacity(0.12),
    highlightColor: Bk.accent.withOpacity(0.06),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Bk.textPri, fontSize: 17,
        fontWeight: FontWeight.w800, letterSpacing: 0.4,
      ),
      iconTheme: IconThemeData(color: Bk.textPri),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Bk.accent,
      inactiveTrackColor: Bk.glassBorder,
      thumbColor: Bk.textPri,
      overlayColor: Bk.accent.withOpacity(0.12),
      trackHeight: 3.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    ),
    dividerTheme: const DividerThemeData(
      color: Bk.glassBorder, thickness: 1, space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Bk.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: Bk.glassBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Bk.surface1,
      contentTextStyle: const TextStyle(color: Bk.textPri, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Bk.textSec, fontSize: 13),
      labelSmall: TextStyle(color: Bk.textDim, fontSize: 10, letterSpacing: 2),
    ),
  );
}
