// lib/theme/shell.dart — App shell (gradient backdrop) and glass bottom nav.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          // Soft colored halos so glass cards have something to refract.
          const Positioned(
            top: -120, left: -100,
            child: _Orb(color: Bk.bgOrbA, size: 320, opacity: 0.18),
          ),
          const Positioned(
            bottom: -140, right: -120,
            child: _Orb(color: Bk.bgOrbB, size: 360, opacity: 0.12),
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
            color.withOpacity(opacity),
            color.withOpacity(0),
          ]),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: Bk.glassRaised,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: Bk.glassBorderHi, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: duration,
        curve: AppCurves.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Bk.accent.withOpacity(0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected
              ? Border.all(color: Bk.accent.withOpacity(0.45), width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(
                dest.icon,
                size: 20,
                color: selected ? Bk.accent : Bk.textSec,
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
