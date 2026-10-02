import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../models/facility.dart';
import '../widgets/facility_card.dart';
import 'building_info_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Facility> _results = List.from(mockFacilities);

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _results = List.from(mockFacilities);
      } else {
        _results = mockFacilities
            .where((f) =>
                f.name.toLowerCase().contains(query.toLowerCase()) ||
                f.category.toLowerCase().contains(query.toLowerCase()) ||
                f.location.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search buildings, rooms, facilities...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_results.length} result${_results.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off,
                            size: 48, color: AppColors.border),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No results found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final facility = _results[index];
                      return FacilityCard(
                        facility: facility,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BuildingInfoScreen(facility: facility),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
