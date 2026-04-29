// lib/theme/controls.dart — Buttons, section headers, and small stat primitives.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/motion.dart';
import 'glass.dart';
import 'tokens.dart';
import 'typography.dart';

enum ButtonVariant { primary, glass, destructive }

/// Uniform button used across the app. Primary = filled accent, glass = subtle
/// translucent, destructive = red accent. All share the same height + radius
/// for a consistent visual rhythm.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.size = ButtonSize.medium,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool loading;
  final bool expand;
  final ButtonSize size;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final (bg, fg, border) = switch (variant) {
      ButtonVariant.primary     => (Bk.accent,        const Color(0xFF06141E), null),
      ButtonVariant.glass       => (Bk.glassDefault,  Bk.textPri,              Bk.glassBorderHi),
      ButtonVariant.destructive => (Bk.danger.withOpacity(0.18), Bk.danger,    Bk.danger.withOpacity(0.45)),
    };

    final padding = switch (size) {
      ButtonSize.small  => const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
      ButtonSize.medium => const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 14),
      ButtonSize.large  => const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 18),
    };

    final fontSize = switch (size) {
      ButtonSize.small  => 13.0,
      ButtonSize.medium => 14.0,
      ButtonSize.large  => 16.0,
    };

    final iconSize = switch (size) {
      ButtonSize.small  => 16.0,
      ButtonSize.medium => 18.0,
      ButtonSize.large  => 20.0,
    };

    final radius = BorderRadius.circular(AppRadii.md);
    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: iconSize, height: iconSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else if (icon != null)
            Icon(icon, size: iconSize, color: fg),
          if ((loading || icon != null)) const SizedBox(width: 10),
          Text(label, style: TextStyle(
            color: fg, fontSize: fontSize, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ],
      ),
    );

    Widget body = variant == ButtonVariant.primary
      ? Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: disabled ? null : [
              BoxShadow(
                color: Bk.accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: content,
        )
      : ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                    border: border == null ? null : Border.all(color: border, width: 1),
                  ),
                  child: content,
                ),
                Positioned.fill(
                  child: LiquidGlassSheen(borderRadius: radius),
                ),
              ],
            ),
          ),
        );

    body = Opacity(opacity: disabled ? 0.55 : 1.0, child: body);
    body = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: disabled ? null : () {
          HapticFeedback.selectionClick();
          onPressed?.call();
        },
        borderRadius: radius,
        splashColor: Bk.accent.withOpacity(0.1),
        highlightColor: Bk.accent.withOpacity(0.05),
        child: body,
      ),
    );
    // Squeeze on press so every primary action in the app shares the same
    // tactile "something happened" cue.
    body = PressScale(enabled: !disabled, child: body);
    return expand ? SizedBox(width: double.infinity, child: body) : body;
  }
}

enum ButtonSize { small, medium, large }

/// Enhanced circular icon-only glass button with better visual feedback
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.tooltip,
    this.variant = IconButtonVariant.glass,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final IconButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor) = switch (variant) {
      IconButtonVariant.glass => (Bk.glassDefault, Bk.glassBorder, Bk.textPri),
      IconButtonVariant.accent => (Bk.accent.withOpacity(0.15), Bk.accent, Bk.accent),
      IconButtonVariant.danger => (Bk.danger.withOpacity(0.15), Bk.danger, Bk.danger),
    };

    Widget btn = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: SizedBox(
          width: size, height: size,
          child: Stack(
            children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1),
                ),
                child: Icon(icon, size: size * 0.48, color: iconColor),
              ),
              Positioned.fill(
                child: LiquidGlassSheen(
                  borderRadius: BorderRadius.circular(size / 2),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    btn = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed == null ? null : () {
          HapticFeedback.selectionClick();
          onPressed!.call();
        },
        splashColor: Bk.accent.withOpacity(0.15),
        highlightColor: Bk.accent.withOpacity(0.08),
        child: btn,
      ),
    );
    btn = PressScale(enabled: onPressed != null, child: btn);
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

enum IconButtonVariant { glass, accent, danger }

/// Enhanced section header with better visual hierarchy
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.label, {
    super.key,
    this.trailing,
    this.subtitle,
  });
  final String label;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: T.label)),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              color: Bk.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Modern stat card with enhanced visual design
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.trend,
    this.color = Bk.textPri,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final String? trend; // "+12%", "-5%", etc.
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trendColor = trend?.startsWith('-') == true ? Bk.danger : Bk.success;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Bk.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trend!,
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: TextStyle(
                    color: Bk.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Legacy primitives kept for the widgets that still use them ─────────────

class StatLabel extends StatelessWidget {
  const StatLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: const TextStyle(
        color: Bk.textDim, fontSize: 10,
        letterSpacing: 2.0, fontWeight: FontWeight.w700,
      ));
}

class StatValue extends StatelessWidget {
  const StatValue(this.value, {super.key, this.color = Bk.textPri, this.size = 22});
  final String value; final Color color; final double size;
  @override
  Widget build(BuildContext context) => Text(value, style: TextStyle(
    color: color, fontSize: size,
    fontWeight: FontWeight.w900, letterSpacing: -0.5,
  ));
}

class ThinBar extends StatelessWidget {
  const ThinBar({
    super.key,
    required this.value,
    required this.gradient,
    this.height = 4,
    this.radius = 4,
  });
  final double value;
  final List<Color> gradient;
  final double height, radius;
  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        Container(height: height, color: Bk.glassBorder),
        FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
