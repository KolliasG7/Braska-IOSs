// lib/theme/modern_components.dart — Modern UI components for enhanced user experience
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/motion.dart';
import 'glass.dart';
import 'tokens.dart';
import 'typography.dart';

/// Modern badge component with enhanced styling
class ModernBadge extends StatelessWidget {
  const ModernBadge({
    super.key,
    required this.label,
    this.color = Bk.accent,
    this.variant = BadgeVariant.filled,
    this.size = BadgeSize.medium,
  });

  final String label;
  final Color color;
  final BadgeVariant variant;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      BadgeVariant.filled => (color, Bk.textPri, null),
      BadgeVariant.outlined => (Colors.transparent, color, color),
      BadgeVariant.soft => (color.withOpacity(0.15), color, color.withOpacity(0.3)),
    };

    final padding = switch (size) {
      BadgeSize.small => const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      BadgeSize.medium => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      BadgeSize.large => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    };

    final fontSize = switch (size) {
      BadgeSize.small => 10.0,
      BadgeSize.medium => 11.0,
      BadgeSize.large => 12.0,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: border == null ? null : Border.all(color: border!, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

enum BadgeVariant { filled, outlined, soft }
enum BadgeSize { small, medium, large }

/// Modern avatar component
class ModernAvatar extends StatelessWidget {
  const ModernAvatar({
    super.key,
    required this.label,
    this.size = AvatarSize.medium,
    this.backgroundColor,
    this.onTap,
  });

  final String label;
  final AvatarSize size;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatarSize = switch (size) {
      AvatarSize.small => 32.0,
      AvatarSize.medium => 40.0,
      AvatarSize.large => 48.0,
      AvatarSize.xlarge => 64.0,
    };

    final fontSize = switch (size) {
      AvatarSize.small => 12.0,
      AvatarSize.medium => 14.0,
      AvatarSize.large => 18.0,
      AvatarSize.xlarge => 24.0,
    };

    final bg = backgroundColor ?? Bk.accent;
    final initials = label.split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join();

    Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Bk.textPri,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    return avatar;
  }
}

enum AvatarSize { small, medium, large, xlarge }

/// Modern divider with enhanced styling
class ModernDivider extends StatelessWidget {
  const ModernDivider({
    super.key,
    this.height = 1,
    this.thickness = 1,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double height;
  final double thickness;
  final Color? color;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: EdgeInsets.only(left: indent, right: endIndent),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            (color ?? Bk.glassBorder).withOpacity(0),
            color ?? Bk.glassBorder,
            (color ?? Bk.glassBorder).withOpacity(0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Modern chip component
class ModernChip extends StatelessWidget {
  const ModernChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.onDeleted,
    this.selected = false,
    this.color = Bk.accent,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: AppRadii.pill,
      style: selected ? GlassStyle.raised : GlassStyle.subtle,
      tint: selected ? color.withOpacity(0.1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: selected ? color : Bk.textSec),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? color : Bk.textPri,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onDeleted!();
              },
              child: Icon(
                Icons.close,
                size: 16,
                color: Bk.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modern progress indicator
class ModernProgress extends StatelessWidget {
  const ModernProgress({
    super.key,
    required this.value,
    this.color = Bk.accent,
    this.height = 6,
    this.showLabel = false,
    this.label,
  });

  final double value;
  final Color color;
  final double height;
  final bool showLabel;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel || label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: T.labelMedium,
                ),
              Text(
                '${(clampedValue * 100).toInt()}%',
                style: T.captionMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Bk.glassBorder,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: clampedValue,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Modern toggle switch
class ModernToggle extends StatefulWidget {
  const ModernToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.color = Bk.accent,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  State<ModernToggle> createState() => _ModernToggleState();
}

class _ModernToggleState extends State<ModernToggle> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onChanged(!widget.value);
      },
      child: AnimatedContainer(
        duration: AppDurations.quick,
        curve: AppCurves.smooth,
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: widget.value ? widget.color : Bk.glassBorder,
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.value ? [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: AppDurations.quick,
            curve: AppCurves.smooth,
            alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
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

/// Modern alert banner
class ModernAlert extends StatelessWidget {
  const ModernAlert({
    super.key,
    required this.message,
    this.type = AlertType.info,
    this.onClose,
  });

  final String message;
  final AlertType type;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (type) {
      AlertType.info => (Icons.info_outline, Bk.accent, Bk.accent.withOpacity(0.1)),
      AlertType.success => (Icons.check_circle_outline, Bk.success, Bk.success.withOpacity(0.1)),
      AlertType.warning => (Icons.warning_amber_outlined, Bk.warn, Bk.warn.withOpacity(0.1)),
      AlertType.error => (Icons.error_outline, Bk.danger, Bk.danger.withOpacity(0.1)),
    };

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadii.md,
      tint: bg,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Bk.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onClose!();
              },
              child: Icon(
                Icons.close,
                size: 18,
                color: Bk.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum AlertType { info, success, warning, error }

/// Modern skeleton loader
class ModernSkeleton extends StatelessWidget {
  const ModernSkeleton({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF1A1D33),
    this.highlightColor = const Color(0xFF2A2D43),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// Modern card with hover effects
class ModernCard extends StatefulWidget {
  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.lg,
    this.elevation = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevation;

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.quick,
        curve: AppCurves.smooth,
        decoration: BoxDecoration(
          color: _hovered && widget.onTap != null
              ? Bk.glassRaised
              : Bk.glassDefault,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _hovered && widget.onTap != null
                ? Bk.glassBorderHi
                : Bk.glassBorder,
            width: 1,
          ),
          boxShadow: widget.elevation || (_hovered && widget.onTap != null)
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Bk.accent.withOpacity(0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: widget.onTap != null
            ? Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(widget.radius),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
                  borderRadius: BorderRadius.circular(widget.radius),
                  splashColor: Bk.accent.withOpacity(0.1),
                  highlightColor: Bk.accent.withOpacity(0.05),
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              )
            : Padding(
                padding: widget.padding,
                child: widget.child,
              ),
      ),
    );
  }
}