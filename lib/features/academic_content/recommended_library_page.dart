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
import '../../widgets/app_background.dart';
import 'content_details_page.dart';

class RecommendedLibraryPage extends StatelessWidget {
  final AppUser user;
  const RecommendedLibraryPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Recommended for You', style: AppText.title.copyWith(fontSize: 16, color: ac.txt)),
      ),
      body: AppBackground(child: FutureBuilder<List<AcademicContent>>(
        future: AcademicContentRepository.instance.recommendedForUser(user.id.isEmpty ? null : user.id, limit: 30),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: 6,
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
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72),
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
      )),
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
