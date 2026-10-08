import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../widgets/app_header.dart';
import '../services/facility_repository.dart';
import '../widgets/catalog_status_banner.dart';

class BuildingInfoScreen extends StatelessWidget {
  final Facility facility;
  const BuildingInfoScreen({super.key, required this.facility});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Facility>>(
    valueListenable: FacilityRepository.instance,
    builder: (context, catalog, _) {
      final current = FacilityRepository.instance.current(this.facility);
      if (current == null && FacilityRepository.instance.loaded) {
        return const Scaffold(
          appBar: AppHeader(title: 'Place details'),
          body: Center(
            child: Text('This place has been removed from the directory.'),
          ),
        );
      }
      final facility = current ?? this.facility;
      final text = Theme.of(context).textTheme;
      return Scaffold(
        appBar: const AppHeader(title: 'Place details'),
        body: PageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CatalogStatusBanner(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              facility.icon,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const Icon(
                            Icons.location_on_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'HOLY ANGEL UNIVERSITY',
                        style: text.labelSmall?.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        facility.name,
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        facility.category,
                        style: text.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('About this place', style: text.titleLarge),
                const SizedBox(height: 12),
                Text(facility.description, style: text.bodyLarge),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _infoRow(
                          context,
                          Icons.schedule_rounded,
                          'Operating hours',
                          facility.hours,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),
                        _infoRow(
                          context,
                          Icons.layers_outlined,
                          'Floors',
                          facility.floors?.toString() ?? 'Not verified',
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(),
                        ),
                        _infoRow(
                          context,
                          Icons.place_outlined,
                          'Location',
                          facility.location,
                        ),
                      ],
                    ),
                  ),
                ),
                if (facility.facilities.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('What you’ll find here', style: text.titleLarge),
                  const SizedBox(height: 12),
                  for (final name in facility.facilities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(name, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Back to map'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ],
  );
}
