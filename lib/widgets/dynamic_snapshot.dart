import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/organization_provider.dart';
import 'snapshot_modules/module_registry.dart';

/// Replaces the hardcoded "School Snapshot" section. Renders whatever
/// module ids the active organization returns — school, university,
/// corporate, or independent — using the exact same layout and cards.
/// No branching on organization type happens here; the *backend*
/// decided the module list, this widget just paints it.
class DynamicSnapshot extends StatelessWidget {
  const DynamicSnapshot({super.key});

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().organization;
    final modules = org.snapshotModules
        .map((id) => SnapshotModuleRegistry.build(context, id))
        .whereType<SnapshotModuleData>() // drop unknown module ids safely
        .toList();

    if (modules.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Snapshot',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // navigate to full snapshot / school detail screen
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: modules
                .map((m) => Expanded(child: SnapshotCard(data: m)))
                .toList(),
          ),
        ],
      ),
    );
  }
}
