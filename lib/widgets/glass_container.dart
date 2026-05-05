import 'dart:ui';
import 'dart:math' show pi;
import 'package:flutter/material.dart';

/// Premium 3D Glass Container with frosted backdrop blur and entry animation.
///
/// Entry Animation (0.6s):
///   perspective(1000px) rotateX(10deg) translateY(20px) opacity(0)
///   → rotateX(0deg) translateY(0) opacity(1)
///
/// Curve: cubic-bezier(0.25, 0.8, 0.25, 1)
class GlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final BoxShape shape;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity = 0.40,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.border,
    this.shape = BoxShape.rectangle,
    this.boxShadow,
    this.gradient,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _entry;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entry = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Cubic(0.25, 0.8, 0.25, 1),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = widget.shape == BoxShape.circle
        ? BorderRadius.circular(1000)
        : BorderRadius.circular(widget.borderRadius);

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, child) {
        final t = _entry.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective(1000px)
            ..rotateX((1 - t) * 10 * pi / 180) // 10deg → 0deg
            ..setEntry(1, 3, (1 - t) * 20.0), // translateY 20px → 0px
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: resolvedBorderRadius,
          boxShadow: widget.boxShadow ?? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.37),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: resolvedBorderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                shape: widget.shape,
                borderRadius: widget.shape == BoxShape.circle
                    ? null
                    : BorderRadius.circular(widget.borderRadius),
                border: widget.border ?? Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                gradient: widget.gradient ?? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.03, 1.0],
                  colors: [
                    Colors.white.withValues(alpha: 0.10), // Inset highlight (top)
                    Color(0xFF191919).withValues(alpha: widget.opacity),
                    Color(0xFF191919).withValues(alpha: widget.opacity),
                  ],
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A clickable wrapper with hover/touch float micro-interaction.
///
/// Hover/Touch Animation (0.3s):
///   translateY(-4px) scale(1.02)
///
/// Curve: cubic-bezier(0.25, 0.8, 0.25, 1)
/// Supports both mouse hover (Web Desktop) and touch (Mobile PWA).
class PremiumClickable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const PremiumClickable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 24.0,
    this.margin,
  });

  @override
  State<PremiumClickable> createState() => _PremiumClickableState();
}

class _PremiumClickableState extends State<PremiumClickable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.25, 0.8, 0.25, 1),
      reverseCurve: const Cubic(0.25, 0.8, 0.25, 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _activate() {
    if (widget.onTap != null) _controller.forward();
  }

  void _deactivate() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _activate(),
      onExit: (_) => _deactivate(),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => _activate(),
        onTapUp: (_) => _deactivate(),
        onTapCancel: () => _deactivate(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = _animation.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                    1.0 + 0.02 * t, 1.0 + 0.02 * t, 1.0) // scale(1.02)
                ..setEntry(1, 3, -4.0 * t),           // translateY(-4px)
              child: child,
            );
          },
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
