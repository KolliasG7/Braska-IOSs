// lib/widgets/motion.dart — Shared motion primitives used across the app.
//
// Keep the motion vocabulary in one place so the whole app reads like it
// was designed together: everything presses the same, peer destinations
// fade-through together, and tab bodies swap with the same depth cue.
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Scale-on-press wrapper for tappable surfaces. Squeezes the child to
/// 0.96× while the pointer is down, then springs back on release/cancel.
/// Pair this with whatever haptic/onTap your parent already handles — this
/// widget intentionally doesn't consume the gesture, it only listens for
/// pointer state so it composes cleanly with `InkWell`, `GestureDetector`,
/// etc. above or below it.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final Curve curve;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  void didUpdateWidget(PressScale old) {
    super.didUpdateWidget(old);
    // If the parent disables the button while the finger is still down,
    // our `onPointerUp` won't flip `_down` back to false because `_set`
    // short-circuits on `!enabled`. Without this reset, `AnimatedScale`
    // stays stuck at `pressedScale` until the user taps something else.
    if (!widget.enabled && _down) {
      setState(() => _down = false);
    }
  }

  void _set(bool v) {
    if (!widget.enabled) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:   (_) => _set(true),
      onPointerUp:     (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: _down
            ? AppDurations.quick
            : AppDurations.medium,
        curve: _down ? Curves.easeOut : AppCurves.bounce,
        child: widget.child,
      ),
    );
  }
}

/// Enhanced press animation with scale and opacity
class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.94,
    this.pressedOpacity = 0.8,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final double pressedOpacity;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:   (_) => _set(true),
      onPointerUp:     (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedOpacity(
        opacity: _down ? widget.pressedOpacity : 1.0,
        duration: AppDurations.quick,
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: AppDurations.quick,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Material-ish "fade-through" route for peer destinations (e.g. opening
/// Settings from the dashboard). Incoming page fades in while scaling up
/// from 0.96 → 1.0; outgoing page fades out while scaling up slightly from
/// 1.0 → 1.03 so it reads as receding instead of sliding.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({required Widget child})
    : super(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => child,
        transitionDuration:        AppDurations.medium,
        reverseTransitionDuration: AppDurations.quick,
        transitionsBuilder: (_, anim, secondary, child) {
          final enter = CurvedAnimation(parent: anim,      curve: AppCurves.enter);
          final exit  = CurvedAnimation(parent: secondary, curve: AppCurves.exit);

          final fadeIn  = Tween<double>(begin: 0.0, end: 1.0).animate(enter);
          final scaleIn = Tween<double>(begin: 0.96, end: 1.0).animate(enter);

          final fadeOut  = Tween<double>(begin: 1.0, end: 0.0).animate(exit);
          final scaleOut = Tween<double>(begin: 1.0, end: 1.03).animate(exit);

          return FadeTransition(
            opacity: fadeOut,
            child: ScaleTransition(
              scale: scaleOut,
              child: FadeTransition(
                opacity: fadeIn,
                child: ScaleTransition(scale: scaleIn, child: child),
              ),
            ),
          );
        },
      );
}

/// Enhanced slide-up route with better physics
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required Widget child})
    : super(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => child,
        transitionDuration: AppDurations.medium,
        reverseTransitionDuration: AppDurations.fast,
        transitionsBuilder: (_, anim, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: AppCurves.smooth));
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: AppCurves.enter),
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      );
}

/// `AnimatedSwitcher` transition builder for tab bodies: phased
/// fade-through, no horizontal slide. A naive cross-fade on glass
/// cards produces visible ghosting because both layers are
/// semi-transparent — you end up reading two stacked H1s through
/// each other. We avoid that by keeping each body invisible until
/// the last ~45% of its animation, so at any moment only one tab is
/// on stage. The outgoing body vanishes in the first ~45% of its
/// reverse, there's a brief empty gap, then the incoming body fades
/// up with a tiny 0.99 → 1.0 scale cue. The shared nav pill below
/// carries the spatial meaning; the body just needs to reveal cleanly.
Widget tabBodyTransition(Widget child, Animation<double> anim) {
  final phase = CurvedAnimation(
    parent: anim,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );
  final scale = Tween<double>(begin: 0.99, end: 1.0).animate(phase);
  return FadeTransition(
    opacity: phase,
    child: ScaleTransition(scale: scale, child: child),
  );
}

/// Enhanced tab transition with subtle slide effect
Widget tabBodyTransitionEnhanced(Widget child, Animation<double> anim) {
  final phase = CurvedAnimation(
    parent: anim,
    curve: const Interval(0.5, 1.0, curve: AppCurves.smooth),
  );
  final scale = Tween<double>(begin: 0.98, end: 1.0).animate(phase);
  final slide = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(phase);
  return FadeTransition(
    opacity: phase,
    child: SlideTransition(
      position: slide,
      child: ScaleTransition(scale: scale, child: child),
    ),
  );
}

/// Layout builder for [AnimatedSwitcher] that keeps the incoming child on
/// top of the outgoing one so the cross-fade doesn't briefly expose the
/// gradient between the two layers.
Widget stackedLayoutBuilder(Widget? currentChild, List<Widget> previousChildren) {
  return Stack(
    alignment: Alignment.topCenter,
    children: <Widget>[
      ...previousChildren,
      if (currentChild != null) currentChild,
    ],
  );
}

/// Staggered animation builder for list items
class StaggeredAnimation extends StatelessWidget {
  const StaggeredAnimation({
    super.key,
    required this.child,
    required this.index,
    this.totalItems = 5,
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  final Widget child;
  final int index;
  final int totalItems;
  final Duration staggerDelay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppDurations.medium,
      curve: AppCurves.enter,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF1A1D33),
    this.highlightColor = const Color(0xFF2A2D43),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0, -0.5),
              end: Alignment(1.0, 0.5),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
