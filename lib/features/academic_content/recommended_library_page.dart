// lib/features/academic_content/recommended_library_page.dart
// "See all" for the Academia Library home page's Recommended for You rail
// — same real recommendation pool, just a longer, browsable grid instead
// of a 5-card slide.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import 'content_details_page.dart';

class RecommendedLibraryPage extends StatelessWidget {
  final AppUser user;
  const RecommendedLibraryPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ApplicationShell(
      user: user,
      currentTitle: 'Recommended for You',
      subtitle: 'Curated materials tailored to your curriculum',
      currentDestination: AppNavDestination.academicLibrary,
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      contextualPanel: const _RecommendedRightPanel(),
      child: FutureBuilder<List<AcademicContent>>(
        future: AcademicContentRepository.instance.recommendedForUser(user.id.isEmpty ? null : user.id, limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72),
              itemCount: 8,
              itemBuilder: (_, __) => const ShimmerBlock(),
            );
          }
          final items = snap.data ?? const <AcademicContent>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Nothing to recommend yet',
              subtitle: 'Check back once there\'s more in the Library.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.72),
            itemCount: items.length,
            itemBuilder: (context, i) => _Card(
              item: items[i],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ContentDetailsPage(contentId: items[i].id, user: user)));
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecommendedRightPanel extends StatelessWidget {
  const _RecommendedRightPanel();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFE5A93C)),
                  const SizedBox(width: 8),
                  Text('SMART CURATION',
                      style: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Personalized Learning',
                style: AppText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 6),
              Text(
                'Green Hills curates materials, past examination papers, and revision notes aligned with your level and subject enrollments.',
                style: AppText.bodySm.copyWith(color: ac.txt2, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final AcademicContent item;
  final VoidCallback onTap;
  const _Card({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: (item.thumbnailUrl ?? '').isNotEmpty
                  ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(ac))
                  : _placeholder(ac),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: AppText.title.copyWith(fontSize: 12, color: ac.txt), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(item.contentType.label, style: AppText.caption.copyWith(fontSize: 10, color: ac.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(AppColors ac) => Container(color: ac.surf3, alignment: Alignment.center,
      child: Text(item.contentType.emoji, style: const TextStyle(fontSize: 24)));
}
