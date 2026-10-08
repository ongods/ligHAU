import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../services/facility_repository.dart';
import '../widgets/app_header.dart';
import '../widgets/building_editor_dialog.dart';
import '../widgets/catalog_status_banner.dart';
import 'building_info_screen.dart';
import 'login_screen.dart';
import 'admin_login_screen.dart';
import '../services/admin_access.dart';
import 'api_usage_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = FacilityRepository.instance;
  List<Facility> get _buildings => _repository.value
      .where((f) => f.category == 'Buildings' || f.category == 'Offices')
      .toList();
  bool _saving = false;
  final _searchController = TextEditingController();
  String _query = '';

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    _repository.removeListener(_catalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repository.addListener(_catalogChanged);
    _repository.refresh();
  }

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  void _logout() {
    AdminAccess.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _showBuildingEditor({Facility? facility, int? index}) async {
    if (_saving) return;
    final updated = await showDialog<Facility>(
      context: context,
      builder: (_) => BuildingEditorDialog(
        facility: facility,
        isNameAvailable: (name) => !_buildings.asMap().entries.any(
          (entry) =>
              entry.key != index &&
              entry.value.name.toLowerCase() == name.toLowerCase(),
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _saving = true);
    try {
      await _repository.save(updated, previous: facility);
    } on FacilitySaveException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          index == null
              ? 'Building added successfully.'
              : 'Building updated successfully.',
        ),
      ),
    );
  }

  void _showDeleteDialog(int index) {
    final facility = _buildings[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Remove "${facility.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_saving) return;
              setState(() => _saving = true);
              try {
                await _repository.delete(facility);
              } on FacilitySaveException catch (error) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
                return;
              } finally {
                if (mounted) setState(() => _saving = false);
              }
              if (!ctx.mounted || !mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Building deleted.')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminAccess.isAuthenticated) return const AdminLoginScreen();
    final theme = Theme.of(context);
    final terms = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final visibleBuildings = _buildings.asMap().entries.where((entry) {
      final building = entry.value;
      final text = [
        building.name,
        building.category,
        building.location,
        building.description,
        ...building.facilities,
      ].join(' ').toLowerCase();
      return terms.every(text.contains);
    }).toList();

    return Scaffold(
      appBar: AppHeader(
        title: 'Campus management',
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: PageBody(
        maxWidth: 1120,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CatalogStatusBanner(),
              if (_saving) const LinearProgressIndicator(),
              Text('Overview', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Manage campus places and monitor your services.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApiUsageScreen()),
                ),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('API usage & quota'),
              ),
              const SizedBox(height: AppSpacing.md),
              // Summary cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 650 ? 3 : 1;
                  final width =
                      (constraints.maxWidth - 16 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _summaryCard(
                          theme,
                          'Buildings',
                          _buildings
                              .where((b) => b.category == 'Buildings')
                              .length
                              .toString(),
                          Icons.apartment,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _summaryCard(
                          theme,
                          'Facilities',
                          _buildings
                              .expand((b) => b.facilities)
                              .toSet()
                              .length
                              .toString(),
                          Icons.meeting_room,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _summaryCard(
                          theme,
                          'Locations',
                          _buildings
                              .where((b) => b.location.trim().isNotEmpty)
                              .length
                              .toString(),
                          Icons.location_on,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              // Manage buildings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Manage Buildings',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add building',
                    onPressed: () => _showBuildingEditor(),
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                'Select a place to view its details. Use the pencil to edit.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('admin-building-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: 'Search campus places',
                  hintText: 'Name, location, or facility',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${visibleBuildings.length} of ${_buildings.length} places',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              if (visibleBuildings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.search_off, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(
                          'No places found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('Try another name, location, or facility.'),
                        if (_query.isNotEmpty)
                          TextButton(
                            onPressed: _clearSearch,
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  ),
                ),
              ...visibleBuildings.map((entry) {
                final index = entry.key;
                final b = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 600;
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            tooltip: 'Edit ${b.name}',
                            onPressed: () =>
                                _showBuildingEditor(facility: b, index: index),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.border,
                              size: 20,
                            ),
                            tooltip: 'Delete ${b.name}',
                            onPressed: () => _showDeleteDialog(index),
                          ),
                        ],
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BuildingInfoScreen(facility: b),
                                ),
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.pathway,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  b.icon,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                b.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                '${b.category} · ${b.location}',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: narrow ? null : actions,
                            ),
                            if (narrow)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 12,
                                  top: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: actions,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
    ThemeData theme,
    String title,
    String count,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(title, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
