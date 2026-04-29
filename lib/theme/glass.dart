// lib/theme/glass.dart — Real glassmorphism primitives using BackdropFilter.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'tokens.dart';

enum GlassStyle { subtle, normal, raised }

/// Specular sheen painted over a glass surface. Gives the top-edge bright
/// highlight + soft diagonal hotspot that reads as "liquid glass" rather
/// than a flat translucent panel. Fully decorative — absorbs no hit events.
class LiquidGlassSheen extends StatelessWidget {
  const LiquidGlassSheen({
    super.key,
    required this.borderRadius,
    this.intensity = 1.0,
    this.shape = BoxShape.rectangle,
  });

  final BorderRadius borderRadius;
  final double intensity;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    Widget stack = IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top-edge specular highlight: bright along the top, fading fast.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha:0.26 * intensity),
                  Colors.white.withValues(alpha:0.06 * intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.55],
              ),
            ),
          ),
          // Diagonal hotspot from top-left — mimics a soft overhead light.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1.0, -1.0),
                end: const Alignment(0.4, 0.3),
                colors: [
                  Colors.white.withValues(alpha:0.14 * intensity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Subtle bottom dim — reads as "thickness" / refractive depth.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha:0.10 * intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35],
              ),
            ),
          ),
        ],
      ),
    );
    // Clip so the sheen gradients never bleed past the glass edges.
    return shape == BoxShape.circle
        ? ClipOval(child: stack)
        : ClipRRect(borderRadius: borderRadius, child: stack);
  }
}

class _AnimatedSheenSweep extends StatefulWidget {
  const _AnimatedSheenSweep({
    required this.borderRadius,
    required this.intensity,
  });

  final BorderRadius borderRadius;
  final double intensity;

  @override
  State<_AnimatedSheenSweep> createState() => _AnimatedSheenSweepState();
}

class _AnimatedSheenSweepState extends State<_AnimatedSheenSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius;
    final sweep = AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final x = -1.2 + (t * 2.4);
        return Transform.translate(
          offset: Offset(220 * x, 0),
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.11 * widget.intensity),
                    Colors.white.withValues(alpha: 0.19 * widget.intensity),
                    Colors.white.withValues(alpha: 0.11 * widget.intensity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    final clipped = ClipRRect(borderRadius: radius, child: sweep);
    return IgnorePointer(child: Opacity(opacity: 0.7, child: clipped));
  }
}

/// Translucent frosted-glass card. Uses a BackdropFilter so the dark gradient
/// background shows through a blurred layer. Stack under an `AppShell` or any
/// scaffold with a non-opaque background for the effect to be visible.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius  = AppRadii.lg,
    this.style   = GlassStyle.normal,
    this.tint,
    this.onTap,
    this.margin,
    // Legacy params — ignored but preserved so existing call sites compile.
    @Deprecated('use style') this.settings,
    @Deprecated('use style: GlassStyle.subtle') this.subtle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassStyle style;
  final Color? tint;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Object? settings;
  final bool subtle;

  Color get _fill => switch (subtle ? GlassStyle.subtle : style) {
    GlassStyle.subtle => Bk.glassSubtle,
    GlassStyle.normal => Bk.glassDefault,
    GlassStyle.raised => Bk.glassRaised,
  };

  Color get _border => switch (subtle ? GlassStyle.subtle : style) {
    GlassStyle.subtle => Bk.glassBorder,
    GlassStyle.normal => Bk.glassBorder,
    GlassStyle.raised => Bk.glassBorderHi,
  };

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final sheenIntensity = switch (subtle ? GlassStyle.subtle : style) {
      GlassStyle.subtle => 0.7,
      GlassStyle.normal => 1.0,
      GlassStyle.raised => 1.15,
    };
    // Glass fill and the optional tint gradient live on separate layers so
    // the tint (which fades to transparent) never erases the frosted fill,
    // and the caller's intended alpha is preserved instead of being clobbered
    // by a hardcoded opacity.
    Widget body = Container(
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: borderRadius,
        border: Border.all(color: _border, width: 1),
      ),
      child: tint == null
          ? Padding(padding: padding, child: child)
          : Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tint!, tint!.withValues(alpha:0)],
                ),
              ),
              padding: padding,
              child: child,
            ),
    );
    // Layer the specular sheen over the body so the card reads as glass
    // rather than a flat translucent panel. `body` is the non-positioned
    // child so the Stack sizes to the padded content.
    body = Stack(
      children: [
        body,
        Positioned.fill(
          child: LiquidGlassSheen(
            borderRadius: borderRadius,
            intensity: sheenIntensity,
          ),
        ),
        if ((subtle ? GlassStyle.subtle : style) != GlassStyle.subtle)
          Positioned.fill(
            child: _AnimatedSheenSweep(
              borderRadius: borderRadius,
              intensity: sheenIntensity,
            ),
          ),
      ],
    );
    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: body,
      ),
    );

    if (style == GlassStyle.raised) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Bk.accent.withValues(alpha:0.08),
              blurRadius: 40,
              offset: const Offset(0, 4),
              spreadRadius: -8,
            ),
          ],
        ),
        child: content,
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }
    return content;
  }
}

/// A small glass capsule — used for chips, status pills, nav items.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.tint,
    this.onTap,
    this.selected = false,
    this.radius = AppRadii.pill,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final baseTint = tint ?? Bk.accent;
    final fill = selected ? baseTint.withValues(alpha:0.18) : Bk.glassDefault;
    final borderColor = selected ? baseTint.withValues(alpha:0.55) : Bk.glassBorder;

    Widget inner = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Stack(
          children: [
            Container(
              padding: padding,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: child,
            ),
            Positioned.fill(
              child: LiquidGlassSheen(
                borderRadius: borderRadius,
                intensity: selected ? 0.85 : 0.95,
              ),
            ),
            if (selected)
              Positioned.fill(
                child: _AnimatedSheenSweep(
                  borderRadius: borderRadius,
                  intensity: 0.9,
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: inner,
      ),
    );
  }
}

/// Bottom sheet / modal body wrapped in glass.
class GlassSheet extends StatelessWidget {
  const GlassSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: const BoxDecoration(
            color: Bk.glassDefault,
            border: Border(top: BorderSide(color: Bk.glassBorderHi, width: 1)),
          ),
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}

// ── Legacy aliases ──────────────────────────────────────────────────────────
// Some screens still import these names. Keep them as thin wrappers.

class FakeGlassCard extends GlassCard {
  const FakeGlassCard({
    super.key,
    required super.child,
    super.padding,
    super.radius,
    super.tint,
    super.onTap,
  });
}

class GlowGlassCard extends GlassCard {
  const GlowGlassCard({
    super.key,
    required super.child,
    super.padding,
    super.radius,
    super.onTap,
    Color? glowColor,
    super.tint,
  });
}
