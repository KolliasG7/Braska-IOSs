// lib/theme/shell.dart — App shell (gradient backdrop) and glass bottom nav.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/motion.dart';
import 'glass.dart';
import 'tokens.dart';

/// Shared background used under every screen. Stack content on top and make
/// sure your `Scaffold.backgroundColor` is `Colors.transparent` so the
/// gradient shows through.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Bk.bgTop, Bk.bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Colored halos so glass surfaces have something to refract.
          // Opacities are tuned so frosted panels read as translucent-
          // coloured rather than flat grey.
          const Positioned(
            top: -120, left: -100,
            child: _Orb(color: Bk.bgOrbA, size: 360, opacity: 0.34),
          ),
          const Positioned(
            top: 160, right: -140,
            child: _Orb(color: Bk.bgOrbC, size: 320, opacity: 0.22),
          ),
          const Positioned(
            bottom: -140, right: -120,
            child: _Orb(color: Bk.bgOrbB, size: 400, opacity: 0.28),
          ),
          const Positioned(
            bottom: 60, left: -160,
            child: _Orb(color: Bk.bgOrbA, size: 340, opacity: 0.18),
          ),
          // Soft vertical glass veils to mimic iOS-like refracted layers.
          const Positioned(
            top: -40,
            right: -30,
            child: _GlassVeil(
              width: 220,
              height: 420,
              angleDeg: -18,
              opacity: 0.08,
            ),
          ),
          const Positioned(
            bottom: -50,
            left: -20,
            child: _GlassVeil(
              width: 260,
              height: 360,
              angleDeg: 14,
              opacity: 0.06,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha:opacity),
            color.withValues(alpha:0),
          ]),
        ),
      ),
    );
  }
}

class _GlassVeil extends StatelessWidget {
  const _GlassVeil({
    required this.width,
    required this.height,
    required this.angleDeg,
    required this.opacity,
  });

  final double width;
  final double height;
  final double angleDeg;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angleDeg * 3.1415926535897932 / 180,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(52),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: opacity * 1.6),
                  Colors.white.withValues(alpha: opacity),
                  Colors.white.withValues(alpha: opacity * 0.3),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: opacity * 1.8),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating glass bottom navigation bar.
///
/// Pass a list of `NavDestination`s — keep it to 3–5 items so pill-style
/// selection fits on all phones.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    this.reduceMotion = false,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            children: [
              Container(
            decoration: BoxDecoration(
              color: Bk.glassRaised,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: Bk.glassBorderHi, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: LayoutBuilder(builder: (context, constraints) {
              // Shared-element selection pill: instead of each item fading
              // its own background (which reads as 5 disconnected
              // animations), we position a single translucent pill behind
              // the row and slide it to the selected index. That spatial
              // continuity is what makes the bar feel designed.
              final slotWidth = constraints.maxWidth / destinations.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: reduceMotion
                        ? Duration.zero
                        : AppDurations.med,
                    curve: AppCurves.emphasized,
                    left: slotWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: slotWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Bk.accent.withValues(alpha:0.18),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: Bk.accent.withValues(alpha:0.42), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Bk.accent.withValues(alpha:0.18),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(destinations.length, (i) {
                      return Expanded(
                        child: _NavItem(
                          dest: destinations[i],
                          selected: i == selectedIndex,
                          reduceMotion: reduceMotion,
                          onTap: () {
                            if (i == selectedIndex) return;
                            HapticFeedback.selectionClick();
                            onTap(i);
                          },
                        ),
                      );
                    }),
                  ),
                ],
              );
            }),
              ),
              Positioned.fill(
                child: LiquidGlassSheen(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  intensity: 1.2,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    this.badge = false,
  });
  final IconData icon;
  final String label;
  final bool badge;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
    required this.reduceMotion,
  });
  final NavDestination dest;
  final bool selected;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion ? Duration.zero : AppDurations.med;
    // The shared pill carries the selection background; each item just
    // animates its own icon/text color so the two layers stay in lockstep.
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: selected ? 1.0 : 0.0),
                  duration: duration,
                  curve: AppCurves.standard,
                  builder: (_, v, __) => Icon(
                    dest.icon,
                    size: 20,
                    color: Color.lerp(Bk.textSec, Bk.accent, v),
                  ),
                ),
                if (dest.badge)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: Bk.danger, shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppCurves.standard,
                style: TextStyle(
                  color: selected ? Bk.accent : Bk.textDim,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                child: Text(dest.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top screen header with optional leading/trailing widgets and subtitle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: Bk.textPri, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3,
                )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(
                    color: Bk.textSec, fontSize: 12,
                  )),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
