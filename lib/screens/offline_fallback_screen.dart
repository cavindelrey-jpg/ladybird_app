import 'package:flutter/material.dart';
import 'dictionary_screen.dart';

import '../features/academic_content/library_home_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class OfflineFallbackScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflineFallbackScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ac = Theme.of(context).extension<AppColors>() ?? AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: ac.gold),
            const SizedBox(height: 16),
            Text(
              'You are offline',
              style: AppText.h1.copyWith(fontSize: 22, color: ac.txt),
            ),
            const SizedBox(height: 12),
            Text(
              'You have lost internet connectivity, but your downloaded content and the Academia Dictionary remain fully accessible.',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: ac.txt2),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: const Text('Open Dictionary', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DictionaryScreen()));
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.primary,
                    side: BorderSide(color: ac.primary.withValues(alpha: .3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                  label: const Text('Offline Downloads', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LibraryHomePage(user: AppUser.guest())));
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.primary,
                    side: BorderSide(color: ac.primary.withValues(alpha: .3)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.school_rounded, size: 18),
                  label: const Text('Downloaded Courses', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CoursesHomePage(user: AppUser.guest())));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Reconnecting'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
