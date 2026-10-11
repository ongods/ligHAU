import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Paints the outline above its clipped content so maps and scrollable children
/// cannot cover the panel's edges.
class PanelFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const PanelFrame({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.panelBorder),
    ),
    child: child,
  );
}
