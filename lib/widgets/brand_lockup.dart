import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// App branding, independent of the university's official seal.
class BrandLockup extends StatelessWidget {
  final bool inverse;
  final bool compact;
  final String? subtitle;

  const BrandLockup({
    super.key,
    this.inverse = false,
    this.compact = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: compact ? 36 : 44, inverse: inverse),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ligHAU',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: inverse ? Colors.white : AppColors.primary,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: inverse ? Colors.white70 : AppColors.border,
              ),
            ),
        ],
      ),
    ],
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  final bool inverse;
  const BrandMark({super.key, this.size = 44, this.inverse = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: inverse ? Colors.white.withValues(alpha: 0.12) : AppColors.primary,
      borderRadius: BorderRadius.circular(size * 0.3),
      border: inverse ? Border.all(color: Colors.white24) : null,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.near_me_rounded, color: Colors.white, size: size * 0.52),
        Positioned(
          left: size * 0.19,
          bottom: size * 0.19,
          child: Container(
            width: size * 0.12,
            height: size * 0.12,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}
