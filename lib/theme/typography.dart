// lib/theme/typography.dart — Consistent typography for the whole app.
import 'package:flutter/material.dart';
import 'tokens.dart';

class T {
  T._();

  // Display / screen titles.
  static const display = TextStyle(
    color: Bk.textPri, fontSize: 26,
    fontWeight: FontWeight.w800, letterSpacing: -0.3,
  );

  // Enhanced display styles
  static const displayLarge = TextStyle(
    color: Bk.textPri, fontSize: 32,
    fontWeight: FontWeight.w900, letterSpacing: -0.4,
  );

  static const displaySmall = TextStyle(
    color: Bk.textPri, fontSize: 22,
    fontWeight: FontWeight.w800, letterSpacing: -0.2,
  );

  // Section / card titles.
  static const title = TextStyle(
    color: Bk.textPri, fontSize: 17,
    fontWeight: FontWeight.w700, letterSpacing: -0.2,
  );

  // Enhanced title styles
  static const titleLarge = TextStyle(
    color: Bk.textPri, fontSize: 20,
    fontWeight: FontWeight.w800, letterSpacing: -0.3,
  );

  static const titleSmall = TextStyle(
    color: Bk.textPri, fontSize: 15,
    fontWeight: FontWeight.w700, letterSpacing: -0.1,
  );

  // Small uppercase labels above values.
  static const label = TextStyle(
    color: Bk.textDim, fontSize: 10,
    fontWeight: FontWeight.w700, letterSpacing: 2.0,
  );

  // Enhanced label styles
  static const labelMedium = TextStyle(
    color: Bk.textSec, fontSize: 11,
    fontWeight: FontWeight.w600, letterSpacing: 1.5,
  );

  static const labelLarge = TextStyle(
    color: Bk.textSec, fontSize: 12,
    fontWeight: FontWeight.w600, letterSpacing: 1.2,
  );

  // Body copy.
  static const body = TextStyle(
    color: Bk.textSec, fontSize: 13, height: 1.35,
  );

  // Enhanced body styles
  static const bodyLarge = TextStyle(
    color: Bk.textPri, fontSize: 15,
    fontWeight: FontWeight.w500, height: 1.4,
  );

  static const bodySmall = TextStyle(
    color: Bk.textSec, fontSize: 12,
    fontWeight: FontWeight.w400, height: 1.3,
  );

  // Numeric values inside cards.
  static const value = TextStyle(
    color: Bk.textPri, fontSize: 22,
    fontWeight: FontWeight.w900, letterSpacing: -0.5,
  );

  // Enhanced value styles
  static const valueLarge = TextStyle(
    color: Bk.textPri, fontSize: 28,
    fontWeight: FontWeight.w900, letterSpacing: -0.6,
  );

  static const valueSmall = TextStyle(
    color: Bk.textPri, fontSize: 18,
    fontWeight: FontWeight.w800, letterSpacing: -0.4,
  );

  // Small secondary labels next to values.
  static const caption = TextStyle(
    color: Bk.textDim, fontSize: 11, letterSpacing: 0.2,
  );

  // Enhanced caption styles
  static const captionMedium = TextStyle(
    color: Bk.textSec, fontSize: 12,
    fontWeight: FontWeight.w500, letterSpacing: 0.3,
  );

  static const captionSmall = TextStyle(
    color: Bk.textDim, fontSize: 10,
    fontWeight: FontWeight.w400, letterSpacing: 0.1,
  );

  // Monospace (terminal, IPs, PIDs).
  static const mono = TextStyle(
    color: Bk.textPri, fontSize: 12,
    fontFamily: 'monospace', height: 1.4,
  );

  // Enhanced mono styles
  static const monoLarge = TextStyle(
    color: Bk.textPri, fontSize: 14,
    fontFamily: 'monospace', height: 1.3,
  );

  static const monoSmall = TextStyle(
    color: Bk.textSec, fontSize: 11,
    fontFamily: 'monospace', height: 1.35,
  );

  // Button text
  static const button = TextStyle(
    color: Bk.textPri, fontSize: 14,
    fontWeight: FontWeight.w700, letterSpacing: 0.2,
  );

  static const buttonSmall = TextStyle(
    color: Bk.textPri, fontSize: 13,
    fontWeight: FontWeight.w700, letterSpacing: 0.2,
  );

  // Link text
  static const link = TextStyle(
    color: Bk.accent, fontSize: 13,
    fontWeight: FontWeight.w600, letterSpacing: 0.1,
  );

  // Error text
  static const error = TextStyle(
    color: Bk.danger, fontSize: 12,
    fontWeight: FontWeight.w500, letterSpacing: 0.1,
  );

  // Success text
  static const success = TextStyle(
    color: Bk.success, fontSize: 12,
    fontWeight: FontWeight.w500, letterSpacing: 0.1,
  );
}
