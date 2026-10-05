import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/facility.dart';
import '../data/mock_data.dart';
import '../widgets/app_header.dart';
import 'login_screen.dart';
import 'admin_login_screen.dart';
import '../services/admin_access.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late List<Facility> _buildings;

  @override
  void initState() {
    super.initState();
    _buildings = List.from(
      mockFacilities.where(
        (f) => f.category == 'Buildings' || f.category == 'Offices',
      ),
    );
  }

  void _logout() {
    AdminAccess.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showEditDialog(Facility facility, int index) {
    final nameCtrl = TextEditingController(text: facility.name);
    final catCtrl = TextEditingController(text: facility.category);
    final hoursCtrl = TextEditingController(text: facility.hours);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Building Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: hoursCtrl,
              decoration: const InputDecoration(labelText: 'Operating Hours'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Building updated successfully.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Remove "${_buildings[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _buildings.removeAt(index));
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

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Building Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: hoursCtrl,
              decoration: const InputDecoration(labelText: 'Operating Hours'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _buildings.add(
                    Facility(
                      name: nameCtrl.text,
                      category: catCtrl.text.isEmpty
                          ? 'Buildings'
                          : catCtrl.text,
                      location: 'Campus',
                      description: 'Newly added building.',
                      hours: hoursCtrl.text.isEmpty
                          ? '7:00 AM – 7:00 PM'
                          : hoursCtrl.text,
                      floors: 1,
                      icon: Icons.apartment,
                    ),
                  );
                });
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Building added successfully.')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminAccess.isAuthenticated) return const AdminLoginScreen();
    final theme = Theme.of(context);

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
        maxWidth: 1000,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      theme,
                      'Buildings',
                      '24',
                      Icons.apartment,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _summaryCard(
                      theme,
                      'Facilities',
                      '38',
                      Icons.meeting_room,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _summaryCard(
                      theme,
                      'Locations',
                      '62',
                      Icons.location_on,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
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
                    onPressed: _showAddDialog,
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(_buildings.length, (index) {
                final b = _buildings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.pathway,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(b.icon, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      b.name,
                      style: theme.textTheme.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      b.category,
                      style: theme.textTheme.labelSmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () => _showEditDialog(b, index),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteDialog(index),
                        ),
                      ],
                    ),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              count,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
