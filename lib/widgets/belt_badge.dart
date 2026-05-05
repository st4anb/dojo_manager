import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';

/// Premium 3D Belt Badge with neon glow effect.
///
/// Renders a badge tridimensional with:
/// - Belt-colored background with depth gradient
/// - High-contrast text
/// - Subtle border for 3D edge
/// - Neon glow (box-shadow) emitting the belt's color
class BeltBadge extends StatefulWidget {
  final String faixa;
  final bool isSmall;

  const BeltBadge({super.key, required this.faixa, this.isSmall = false});

  static Color getBeltColor(String belt) {
    const beltColors = {
      'BRANCA': Colors.white,
      'CINZA': Colors.grey,
      'AMARELA': Colors.yellow,
      'LARANJA': Colors.orange,
      'VERDE': Colors.green,
      'AZUL': Colors.blue,
      'ROXA': Colors.purple,
      'MARROM': Colors.brown,
      'PRETA': Colors.black,
      'CORAL': Colors.redAccent,
      'VERMELHA': Colors.red,
    };
    return beltColors[belt.toUpperCase()] ?? Colors.white;
  }

  @override
  State<BeltBadge> createState() => _BeltBadgeState();
}

class _BeltBadgeState extends State<BeltBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    // Pulsating neon glow: cycles between 0.3 and 0.7 opacity continuously
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = BeltBadge.getBeltColor(widget.faixa);
    final isWhite = color == Colors.white;
    final isBlack = color == Colors.black;

    // Neon glow color: for black belt use gold, otherwise use belt color
    final glowColor = isBlack ? AppTheme.accentGold : color;

    // Text color: high contrast against the badge background
    final textColor = isWhite
        ? Colors.white
        : isBlack
            ? AppTheme.accentGold
            : color;

    // Icon color
    final iconColor = isWhite ? Colors.white70 : (isBlack ? AppTheme.accentGold : color);

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        final glowIntensity = _glowAnim.value;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSmall ? 10 : 16,
            vertical: widget.isSmall ? 4 : 8,
          ),
          decoration: BoxDecoration(
            // 3D depth: dark base with belt-color tint
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            // 3D edge: brighter top border, darker bottom
            border: Border(
              top: BorderSide(
                color: color.withValues(alpha: 0.7),
                width: 1.0,
              ),
              left: BorderSide(
                color: color.withValues(alpha: 0.5),
                width: 1.0,
              ),
              right: BorderSide(
                color: color.withValues(alpha: 0.3),
                width: 1.0,
              ),
              bottom: BorderSide(
                color: color.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            // Neon glow layers with pulsating animation
            boxShadow: [
              // Inner glow (tight)
              BoxShadow(
                color: glowColor.withValues(alpha: glowIntensity * 0.8),
                blurRadius: 12,
                spreadRadius: 1,
              ),
              // Mid glow
              BoxShadow(
                color: glowColor.withValues(alpha: glowIntensity * 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              // Outer glow (diffuse neon halo)
              BoxShadow(
                color: glowColor.withValues(alpha: glowIntensity * 0.25),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.shieldCheck,
                size: widget.isSmall ? 10 : 14,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Text(
                widget.faixa.toUpperCase(),
                style: TextStyle(
                  color: textColor,
                  fontSize: widget.isSmall ? 10 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  // Text shadow for extra depth and readability
                  shadows: [
                    Shadow(
                      color: glowColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
