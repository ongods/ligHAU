import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';

class BuildingInfoScreen extends StatelessWidget {
  final Facility facility;

  const BuildingInfoScreen({super.key, required this.facility});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Building Information')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.pathway,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(facility.icon, size: 56, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    facility.category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Building name
            Text(facility.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            // Category chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                facility.category,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Description
            Text(facility.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            // Info cards
            _infoRow(
              theme,
              Icons.access_time,
              'Operating Hours',
              facility.hours,
            ),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(
              theme,
              Icons.layers,
              'Floors',
              '${facility.floors}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(
              theme,
              Icons.location_on_outlined,
              'Location',
              facility.location,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Facilities section
            if (facility.facilities.isNotEmpty) ...[
              Text('Facilities', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: facility.facilities.map((f) {
                  return Chip(
                    label: Text(f, style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.background,
                    side: const BorderSide(color: AppColors.pathway),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Accessibility icons row
            Row(
              children: [
                _iconTag(Icons.accessible, 'Accessible'),
                const SizedBox(width: AppSpacing.sm),
                _iconTag(Icons.wifi, 'Wi-Fi'),
                const SizedBox(width: AppSpacing.sm),
                _iconTag(Icons.ac_unit, 'Air-conditioned'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Get Directions button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Route highlighted on campus map.'),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.labelLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pathway,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
