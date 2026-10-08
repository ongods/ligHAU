import 'package:flutter/material.dart';
import '../data/campus_map_data.dart';
import '../data/campus_map_features.dart';
import '../data/mock_data.dart' show categories;
import '../services/facility_repository.dart';
import '../models/facility.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_lockup.dart';
import '../widgets/category_filter.dart';
import '../widgets/campus_vector_map.dart';
import '../widgets/facility_card.dart';
import '../widgets/catalog_status_banner.dart';
import 'building_info_screen.dart';
import 'chatbot_screen.dart';
import 'login_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapKey = GlobalKey<CampusVectorMapState>();
  final _searchController = TextEditingController();
  late final _locations = loadCampusMapLocations();
  String _category = 'All';
  String _query = '';
  Facility? _selected;
  final _repository = FacilityRepository.instance;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_catalogChanged);
    _repository.refresh();
  }

  void _catalogChanged() {
    if (mounted) {
      setState(() {
        if (_selected != null) _selected = _repository.current(_selected!);
      });
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_catalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _select(Facility facility, CampusMapLocation? location) {
    setState(() => _selected = facility);
    if (location != null) _mapKey.currentState?.focus(location);
  }

  List<Facility> get _filtered => _repository.value
      .where(
        (f) =>
            (_category == 'All' || f.category == _category) &&
            '${f.name} ${f.location} ${f.facilities.join(' ')}'
                .toLowerCase()
                .contains(_query),
      )
      .toList();

  void _openDetails() {
    final facility = _selected!;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuildingInfoScreen(facility: facility)),
    );
  }

  Future<void> _askAssistant() async {
    final facility = await Navigator.push<Facility>(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(canReturnToMap: true),
      ),
    );
    if (!mounted || facility == null) return;
    final locations = await _locations;
    if (!mounted) return;
    setState(() {
      _category = 'All';
      _query = '';
      _searchController.clear();
    });
    _select(facility, campusFacilityLocation(facility, locations));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: BrandLockup(
        compact: true,
        subtitle: MediaQuery.sizeOf(context).width >= 600
            ? 'HOLY ANGEL UNIVERSITY'
            : null,
      ),
      actions: [
        if (MediaQuery.sizeOf(context).width < 600)
          Padding(
            padding: EdgeInsets.zero,
            child: IconButton(
              tooltip: 'Ask ligHAU',
              onPressed: _askAssistant,
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.primary,
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.zero,
            child: TextButton.icon(
              onPressed: _askAssistant,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Ask ligHAU'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            tooltip: 'Exit campus guide',
            icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        const CatalogStatusBanner(),
        Expanded(
          child: SafeArea(
            top: false,
            child: FutureBuilder<Map<String, CampusMapLocation>>(
              future: _locations,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load campus locations.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final locations = snapshot.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final map = _map(locations);
                    if (wide) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 340, child: _directory(locations)),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(child: map),
                                  if (_selected != null) ...[
                                    const SizedBox(height: 12),
                                    _selection(locations),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                          child: _search(),
                        ),
                        CategoryFilter(
                          categories: categories,
                          selected: _category,
                          onSelected: _filter,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: map,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _selected == null
                              ? _browseBar(locations)
                              : _selection(locations),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    ),
  );

  void _filter(String value) => setState(() {
    _category = value;
    _selected = null;
  });

  Widget _search() => TextField(
    controller: _searchController,
    decoration: InputDecoration(
      hintText: 'Find a building or facility',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _selected = null;
                });
              },
            ),
    ),
    onChanged: (value) => setState(() {
      _query = value.trim().toLowerCase();
      _selected = null;
    }),
  );

  Widget _directory(Map<String, CampusMapLocation> locations) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.pathway),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CAMPUS GUIDE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore campus',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'A familiar place, an easier way to get there.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              _search(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _category == category
                            ? Colors.white
                            : AppColors.border,
                      ),
                      onSelected: (_) => _filter(category),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            '${_filtered.length} ${_filtered.length == 1 ? 'place' : 'places'} to explore',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(child: _placeList(locations)),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Holy Angel University, Angeles City',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _placeList(
    Map<String, CampusMapLocation> locations, {
    bool closeSheet = false,
  }) {
    final facilities = _filtered;
    if (facilities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No places found. Try another search or category.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: facilities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final facility = facilities[i];
        return FacilityCard(
          facility: facility,
          selected: _selected == facility,
          subtitle: campusFacilityLocation(facility, locations) != null
              ? facility.category
              : 'Location coming soon',
          margin: EdgeInsets.zero,
          onTap: () {
            _select(facility, campusFacilityLocation(facility, locations));
            if (closeSheet) Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showDirectory(Map<String, CampusMapLocation> locations) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        builder: (_) => ValueListenableBuilder<List<Facility>>(
          valueListenable: _repository,
          builder: (context, facilities, _) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Campus places',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                '${_filtered.length} places in your selection',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close directory',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _placeList(locations, closeSheet: true)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _browseBar(Map<String, CampusMapLocation> locations) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.explore_outlined, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore campus',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${_filtered.length} places to discover',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => _showDirectory(locations),
        child: const Text('Browse'),
      ),
    ],
  );

  Widget _selection(Map<String, CampusMapLocation> locations) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _selected!.icon,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campusFacilityLocation(_selected!, locations) != null
                          ? _selected!.category
                          : 'Map location coming soon',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close selection',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _openDetails,
                  child: const Text('View place'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showDirectory(locations),
                child: const Text('All places'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _map(Map<String, CampusMapLocation> locations) => CampusVectorMap(
    key: _mapKey,
    facilities: _filtered,
    locations: locations,
    selected: _selected,
    onSelected: (facility) =>
        _select(facility, campusFacilityLocation(facility, locations)),
    onClear: () => setState(() => _selected = null),
  );
}
