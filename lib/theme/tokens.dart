// lib/theme/tokens.dart — Design tokens: colors, spacing, radii, durations.
//
// Glassmorphism palette: cool dark gradient backdrop with neutral translucent
// surfaces. A single cool accent (cyan) plus status colors. Everything else
// lives as opacities on white.
import 'package:flutter/material.dart';

class Bk {
  Bk._();

  // ── Backdrop ────────────────────────────────────────────────────────────
  static const bgTop    = Color(0xFF0B0D1F);
  static const bgBottom = Color(0xFF05060F);
  static const bgOrbA   = Color(0xFF4F46E5); // top-left halo
  static const bgOrbB   = Color(0xFFF472B6); // bottom-right halo
  static const bgOrbC   = Color(0xFF22D3EE); // mid-right cyan halo

  // Enhanced gradient orbs for more depth
  static const bgOrbD   = Color(0xFF8B5CF6); // purple accent
  static const bgOrbE   = Color(0xFF10B981); // green accent

  // Aliases kept for legacy code paths during the migration.
  static const oled        = bgBottom;
  static const surface0    = Color(0xFF0A0C1C);
  static const surface1    = Color(0xFF12152A);
  static const surface2    = Color(0xFF1A1D33);

  // ── Text ────────────────────────────────────────────────────────────────
  static const textPri = Color(0xFFF5F7FA);
  static const textSec = Color(0xFFB4B8C5);
  static const textDim = Color(0xFF6A6F80);

  // Enhanced text colors for better hierarchy
  static const textMuted = Color(0xFF4A4F60);
  static const textHighlight = Color(0xFFE0E7FF);

  // ── Accent (single) ─────────────────────────────────────────────────────
  static const accent      = Color(0xFF7DD3FC); // sky-300
  static const accentSoft  = Color(0x337DD3FC); // 20%

  // Enhanced accent colors
  static const accentGlow  = Color(0x4C7DD3FC); // 30%
  static const accentSubtle = Color(0x1A7DD3FC); // 10%

  // ── Status ──────────────────────────────────────────────────────────────
  static const success = Color(0xFF34D399);
  static const warn    = Color(0xFFFBBF24);
  static const danger  = Color(0xFFF87171);

  // Enhanced status colors with better contrast
  static const successSoft = Color(0x3334D399);
  static const warnSoft    = Color(0x33FBBF24);
  static const dangerSoft  = Color(0x33F87171);

  // ── Legacy color aliases (mapped to new system) ─────────────────────────
  // Existing widgets reference Bk.cyan / Bk.amber / Bk.red / Bk.green / Bk.violet / Bk.orange / Bk.pink.
  // Remap them to keep behavior without adding new brand chaos.
  static const cyan     = accent;
  static const cyanDim  = Color(0xFF5FAFD1);
  static const cyanGlow = Color(0x337DD3FC);
  static const amber    = warn;
  static const red      = danger;
  static const green    = success;
  static const violet   = Color(0xFFA5B4FC);
  static const orange   = Color(0xFFFB923C);
  static const pink     = Color(0xFFF9A8D4);
  static const white    = textPri;

  // ── Glass surface colors (on top of the gradient) ───────────────────────
  // Use these as Container `color:` values. They're low-opacity whites that
  // look right above the dark gradient after BackdropFilter blur.
  static const glassSubtle   = Color(0x0FFFFFFF); // 6%
  static const glassDefault  = Color(0x14FFFFFF); // 8%
  static const glassRaised   = Color(0x1FFFFFFF); // 12%
  static const glassBorder   = Color(0x1AFFFFFF); // 10%
  static const glassBorderHi = Color(0x24FFFFFF); // 14%

  // Enhanced glass surfaces for better depth
  static const glassSurface  = Color(0x0DFFFFFF); // 5%
  static const glassElevated = Color(0x1CFFFFFF); // 11%
  static const glassFloating = Color(0x26FFFFFF); // 15%

  // Legacy glass-tint slots used by existing code — now real faint tints.
  static const glassTint       = Color(0x08FFFFFF);
  static const glassTintCyan   = Color(0x107DD3FC);
  static const glassTintAmber  = Color(0x10FBBF24);
  static const glassTintViolet = Color(0x10A5B4FC);
  static const glassTintRed    = Color(0x10F87171);

  // Legacy border color used by StatLabel, dividers, skeletons, etc.
  static const border     = Color(0x1AFFFFFF);
  static const borderGlow = Color(0x33FFFFFF);

  // Enhanced borders for better definition
  static const borderSubtle = Color(0x12FFFFFF);
  static const borderMedium = Color(0x1FFFFFFF);
  static const borderStrong = Color(0x26FFFFFF);

  // ── Chart gradients ─────────────────────────────────────────────────────
  static const List<Color> cpuGrad  = [Color(0xFF7DD3FC), Color(0xFFF5F7FA)];
  static const List<Color> ramGrad  = [Color(0xFFA5B4FC), Color(0xFFF5F7FA)];
  static const List<Color> tempGrad = [Color(0xFFFB923C), Color(0xFFF87171)];
  static const List<Color> diskGrad = [Color(0xFF6EE7B7), Color(0xFFF5F7FA)];
  static const List<Color> netGrad  = [Color(0xFF7DD3FC), Color(0xFFA5B4FC)];

  // Enhanced chart gradients with better depth
  static const List<Color> cpuGradEnhanced  = [Color(0xFF7DD3FC), Color(0xFF38BDF8), Color(0xFFF5F7FA)];
  static const List<Color> ramGradEnhanced  = [Color(0xFFA5B4FC), Color(0xFF818CF8), Color(0xFFF5F7FA)];
  static const List<Color> tempGradEnhanced = [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFF87171)];
  static const List<Color> diskGradEnhanced = [Color(0xFF6EE7B7), Color(0xFF34D399), Color(0xFFF5F7FA)];
  static const List<Color> netGradEnhanced  = [Color(0xFF7DD3FC), Color(0xFFA5B4FC), Color(0xFFC4B5FD)];
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  // Enhanced spacing for better visual rhythm
  static const xxs = 2.0;
  static const tiny = 6.0;
  static const section = 28.0;
  static const gap = 40.0;
}

class AppRadii {
  AppRadii._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 28.0;

  // Enhanced radii for more modern look
  static const xs = 4.0;
  static const xxs = 2.0;
  static const card = 20.0;
  static const dialog = 24.0;
}

class AppDurations {
  AppDurations._();
  static const fast   = Duration(milliseconds: 220);
  static const med    = Duration(milliseconds: 340);
  static const slow   = Duration(milliseconds: 520);
  static const xslow  = Duration(milliseconds: 680);

  // Enhanced durations for more polished animations
  static const instant = Duration(milliseconds: 150);
  static const quick   = Duration(milliseconds: 180);
  static const medium  = Duration(milliseconds: 280);
  static const relaxed = Duration(milliseconds: 420);
  static const leisure = Duration(milliseconds: 600);
}

/// Centralized motion curves. Using a slightly overshooting / strongly-eased
/// curve for "emphasized" transitions gives the UI a buttery, confident feel.
class AppCurves {
  AppCurves._();

  /// Smooth entrance with a soft settle; good for tab swaps, card reveals.
  static const enter = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Quick exit that clears out of the way without a snap.
  static const exit  = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Emphasized motion for selection indicators and pills.
  static const emphasized = Cubic(0.2, 0.9, 0.1, 1.0);

  /// Standard UI container sizing / color lerp.
  static const standard = Cubic(0.25, 0.8, 0.25, 1.0);

  // Enhanced curves for more natural motion
  static const smooth = Cubic(0.4, 0.0, 0.2, 1.0);
  static const bounce = Cubic(0.34, 1.56, 0.64, 1.0);
  static const gentle = Cubic(0.2, 0.0, 0.0, 1.0);
  static const swift = Cubic(0.0, 0.0, 0.2, 1.0);
}

// Legacy no-op settings objects referenced by a few places.
const kDefaultGlassSettings = null;
const kSubtleGlassSettings  = null;
const kNavGlassSettings     = null;
