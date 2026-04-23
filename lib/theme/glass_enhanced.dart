// lib/theme/glass_enhanced.dart — Enhanced glassmorphism with iOS 26 features
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tokens.dart';
import 'glass.dart';

/// Animated Liquid Glass Sheen with dynamic shimmer effect
class AnimatedLiquidGlassSheen extends StatefulWidget {
  const AnimatedLiquidGlassSheen({
    super.key,
    required this.borderRadius,
    this.intensity = 1.0,
    this.shape = BoxShape.rectangle,
    this.enableShimmer = true,
  });

  final BorderRadius borderRadius;
  final double intensity;
  final BoxShape shape;
  final bool enableShimmer;

  @override
  State<AnimatedLiquidGlassSheen> createState() => _AnimatedLiquidGlassSheenState();
}

class _AnimatedLiquidGlassSheenState extends State<AnimatedLiquidGlassSheen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget stack = IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Top-edge specular highlight
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.26 * widget.intensity),
                  Colors.white.withOpacity(0.06 * widget.intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.55],
              ),
            ),
          ),
          // Diagonal hotspot
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1.0, -1.0),
                end: const Alignment(0.4, 0.3),
                colors: [
                  Colors.white.withOpacity(0.14 * widget.intensity),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Animated shimmer overlay
          if (widget.enableShimmer)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    final progress = _controller.value;
                    return LinearGradient(
                      begin: Alignment(-1.0 - progress, -1.0 - progress * 0.5),
                      end: Alignment(1.0 + progress, 1.0 + progress * 0.5),
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.15 * widget.intensity),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds);
                  },
                  child: Container(color: Colors.white),
                );
              },
            ),
          // Bottom dim
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.10 * widget.intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35],
              ),
            ),
          ),
        ],
      ),
    );

    return widget.shape == BoxShape.circle
        ? ClipOval(child: stack)
        : ClipRRect(borderRadius: widget.borderRadius, child: stack);
  }
}

/// Depth Glass Card with parallax effect and multi-layer depth
class DepthGlassCard extends StatefulWidget {
  const DepthGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.lg,
    this.style = GlassStyle.normal,
    this.enableParallax = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassStyle style;
  final bool enableParallax;
  final VoidCallback? onTap;

  @override
  State<DepthGlassCard> createState() => _DepthGlassCardState();
}

class _DepthGlassCardState extends State<DepthGlassCard> {
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  void _updateParallax(Offset localPosition, Size size) {
    if (!widget.enableParallax) return;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    setState(() {
      _tiltX = ((localPosition.dy - centerY) / centerY) * 0.05;
      _tiltY = -((localPosition.dx - centerX) / centerX) * 0.05;
    });
  }

  void _resetParallax() {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  Color get _fill => switch (widget.style) {
    GlassStyle.subtle => Bk.glassSubtle,
    GlassStyle.normal => Bk.glassDefault,
    GlassStyle.raised => Bk.glassRaised,
  };

  Color get _border => switch (widget.style) {
    GlassStyle.subtle => Bk.glassBorder,
    GlassStyle.normal => Bk.glassBorder,
    GlassStyle.raised => Bk.glassBorderHi,
  };

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);
    final sheenIntensity = switch (widget.style) {
      GlassStyle.subtle => 0.7,
      GlassStyle.normal => 1.0,
      GlassStyle.raised => 1.15,
    };

    Widget body = MouseRegion(
      onHover: (event) => _updateParallax(
        event.localPosition,
        context.size ?? Size.zero,
      ),
      onExit: (_) => _resetParallax(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY),
        child: Stack(
          children: [
            // Base glass layer
            Container(
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: borderRadius,
                border: Border.all(color: _border, width: 1),
              ),
              padding: widget.padding,
              child: widget.child,
            ),
            // Animated liquid sheen
            Positioned.fill(
              child: AnimatedLiquidGlassSheen(
                borderRadius: borderRadius,
                intensity: sheenIntensity,
              ),
            ),
          ],
        ),
      ),
    );

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: body,
      ),
    );

    if (widget.style == GlassStyle.raised) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      );
    }

    if (widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: borderRadius,
          splashColor: Bk.accent.withOpacity(0.15),
          highlightColor: Bk.accent.withOpacity(0.08),
          child: content,
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}

/// Glass button with ripple effect
class GlassRippleButton extends StatelessWidget {
  const GlassRippleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.lg,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Bk.accent.withOpacity(0.2),
            highlightColor: Bk.accent.withOpacity(0.1),
            borderRadius: borderRadius,
            child: Ink(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    Bk.glassRaised,
                    Bk.glassDefault,
                  ],
                ),
                borderRadius: borderRadius,
                border: Border.all(color: Bk.glassBorder, width: 1),
              ),
              padding: padding,
              child: Stack(
                children: [
                  child,
                  Positioned.fill(
                    child: LiquidGlassSheen(
                      borderRadius: borderRadius,
                      intensity: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
