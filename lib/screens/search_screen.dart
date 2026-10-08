import 'package:flutter/material.dart';
import '../services/facility_repository.dart';
import '../models/facility.dart';
import '../widgets/app_header.dart';
import '../widgets/facility_card.dart';
import '../widgets/catalog_status_banner.dart';
import 'building_info_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _repository = FacilityRepository.instance;
  List<Facility> get _results {
    final q = _searchController.text.trim().toLowerCase();
    return _repository.value
        .where(
          (f) =>
              '${f.name} ${f.category} ${f.location} ${f.facilities.join(' ')}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
  }

  void _onSearchChanged(String query) => setState(() {});
  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _repository.addListener(_catalogChanged);
    _repository.refresh();
  }

  @override
  void dispose() {
    _repository.removeListener(_catalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader(title: 'Campus directory'),
    body: PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CatalogStatusBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your next stop.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Search buildings, offices, and campus essentials.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Find a building or facility',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_results.length} ${_results.length == 1 ? 'place' : 'places'} found',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text('No places found. Try a different search.'),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemBuilder: (_, i) => FacilityCard(
                      facility: _results[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BuildingInfoScreen(facility: _results[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
