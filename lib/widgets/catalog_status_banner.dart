import 'package:flutter/material.dart';
import '../models/facility.dart';
import '../services/facility_repository.dart';

/// Keeps cached or sample data visibly distinct from the current saved catalog.
class CatalogStatusBanner extends StatelessWidget {
  const CatalogStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FacilityRepository.instance;
    return ValueListenableBuilder<List<Facility>>(
      valueListenable: repository,
      builder: (context, _, _) {
        if (repository.syncStatus == CatalogSyncStatus.current) {
          return const SizedBox.shrink();
        }
        final loading = repository.syncStatus == CatalogSyncStatus.loading;
        final last = repository.lastSuccessfulRefresh;
        final checked = last == null
            ? ''
            : ' Last updated at ${TimeOfDay.fromDateTime(last).format(context)}.';
        final message = switch (repository.syncStatus) {
          CatalogSyncStatus.loading => 'Loading current campus information…',
          CatalogSyncStatus.stale =>
            'Campus updates are unavailable. Showing previously loaded information; it may be out of date.$checked',
          _ =>
            'Current campus information is unavailable. Showing sample information; check with the campus office.',
        };
        return Semantics(
          liveRegion: true,
          child: Material(
            color: loading ? const Color(0xFFF0F2F5) : const Color(0xFFFFF3D6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    loading ? Icons.sync : Icons.cloud_off_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!loading) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: repository.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
