import 'package:flutter/material.dart';
import '../models/facility.dart';
import '../theme/app_theme.dart';

class FacilityCard extends StatelessWidget {
  final Facility facility;
  final VoidCallback onTap;
  final bool selected;
  final String? subtitle;
  final EdgeInsetsGeometry margin;
  const FacilityCard({
    super.key,
    required this.facility,
    required this.onTap,
    this.selected = false,
    this.subtitle,
    this.margin = const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    color: selected ? AppColors.primaryTint : AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: .3)
            : AppColors.pathway,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                facility.icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? facility.category,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    ),
  );
}
