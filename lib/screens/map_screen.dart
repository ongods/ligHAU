import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../data/mock_data.dart';
import '../widgets/category_filter.dart';
import '../widgets/chatbot_button.dart';
import 'search_screen.dart';
import 'building_info_screen.dart';
import 'chatbot_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _selectedCategory = 'All';
  int? _selectedBuildingIndex;

  // Building positions on the mock map
  static const List<_BuildingMarker> _markers = [
    _BuildingMarker(name: 'SFJ Building', left: 0.12, top: 0.18, index: 0),
    _BuildingMarker(name: 'Library', left: 0.55, top: 0.12, index: 1),
    _BuildingMarker(name: 'Chapel', left: 0.38, top: 0.38, index: 2),
    _BuildingMarker(name: 'Registrar', left: 0.60, top: 0.52, index: 3),
    _BuildingMarker(name: 'Main Bldg', left: 0.22, top: 0.55, index: 4),
    _BuildingMarker(name: 'Parking', left: 0.50, top: 0.78, index: 5),
  ];

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _selectedBuildingIndex = null;
    });
  }

  void _onMarkerTap(int index) {
    setState(() => _selectedBuildingIndex = index);
  }

  void _openBuildingInfo(Facility facility) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BuildingInfoScreen(facility: facility)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.pathway),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.border),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Search buildings, rooms, facilities...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Category filter
          CategoryFilter(
            categories: categories,
            selected: _selectedCategory,
            onSelected: _onCategorySelected,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Mock campus map
          Expanded(
            child: Stack(
              children: [
                // Map background
                Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pathway, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        return Stack(
                          children: [
                            // Campus green areas
                            Positioned(
                              left: w * 0.05,
                              top: h * 0.05,
                              child: _greenArea(w * 0.90, h * 0.90),
                            ),
                            // Pathways
                            // Horizontal main pathway
                            Positioned(
                              left: w * 0.05,
                              top: h * 0.45,
                              child: Container(
                                width: w * 0.90,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.pathway,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            // Vertical pathway
                            Positioned(
                              left: w * 0.45,
                              top: h * 0.05,
                              child: Container(
                                width: 14,
                                height: h * 0.90,
                                decoration: BoxDecoration(
                                  color: AppColors.pathway,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            // Secondary horizontal pathway
                            Positioned(
                              left: w * 0.10,
                              top: h * 0.70,
                              child: Container(
                                width: w * 0.80,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.pathway.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            // Building markers
                            for (final marker in _markers)
                              Positioned(
                                left: w * marker.left,
                                top: h * marker.top,
                                child: GestureDetector(
                                  onTap: () => _onMarkerTap(marker.index),
                                  child: _BuildingPin(
                                    name: marker.name,
                                    isSelected:
                                        _selectedBuildingIndex == marker.index,
                                  ),
                                ),
                              ),
                            // Campus label
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Holy Angel University Campus',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // Zoom controls
                Positioned(
                  right: 28,
                  bottom: _selectedBuildingIndex != null ? 160 : 24,
                  child: Column(
                    children: [
                      _mapButton(Icons.add, () {}),
                      const SizedBox(height: AppSpacing.sm),
                      _mapButton(Icons.remove, () {}),
                    ],
                  ),
                ),
                // Selected building preview
                if (_selectedBuildingIndex != null)
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: _buildPreviewCard(
                      mockFacilities[_selectedBuildingIndex!],
                      theme,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ChatbotButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
      ),
    );
  }

  Widget _greenArea(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFDCEDC8),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onPressed) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.surface,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.onSurface),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Facility facility, ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.pathway,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(facility.icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    facility.name,
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(facility.category, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _openBuildingInfo(facility),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingMarker {
  final String name;
  final double left;
  final double top;
  final int index;

  const _BuildingMarker({
    required this.name,
    required this.left,
    required this.top,
    required this.index,
  });
}

class _BuildingPin extends StatelessWidget {
  final String name;
  final bool isSelected;

  const _BuildingPin({required this.name, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.secondary
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.primary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
        Icon(
          Icons.location_on,
          color: isSelected ? AppColors.secondary : AppColors.primary,
          size: 20,
        ),
      ],
    );
  }
}
