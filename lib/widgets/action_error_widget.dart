import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/connectivity_service.dart';

class ActionErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final bool isOfflineOverride;

  const ActionErrorWidget({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.isOfflineOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = Theme.of(context).extension<AppColors>()!;
    final isOffline = isOfflineOverride || !ConnectivityService().isOnline;
    
    // Humanize the error
    String errStr = error.toString().toLowerCase();
    String title = 'Something went wrong';
    String message = 'We couldn\'t load this content right now. Please check your connection and try again.';
    IconData icon = Icons.info_outline_rounded;
    Color iconColor = ac.muted;
    Color iconBg = ac.surf;
    
    if (isOffline || errStr.contains('socketexception') || errStr.contains('network is unreachable') || errStr.contains('failed host lookup')) {
      title = 'You are offline';
      message = 'Please connect to the internet or browse your downloaded offline library.';
      icon = Icons.wifi_off_rounded;
      iconColor = ac.gold;
      iconBg = ac.goldBg;
    } else if (errStr.contains('supabase') || errStr.contains('postgres') || errStr.contains('database')) {
      title = 'Content Unavailable';
      message = 'We could not retrieve this information right now. Please try again later.';
      iconColor = ac.muted;
      iconBg = ac.surf;
    } else if (errStr.contains('permission') || errStr.contains('jwt') || errStr.contains('unauthorized')) {
      title = 'Access Restricted';
      message = 'You do not have permission to view or modify this content.';
      icon = Icons.lock_outline_rounded;
      iconColor = ac.gold;
      iconBg = ac.goldBg;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ac.txt)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: ac.txt2, height: 1.4)),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: onRetry,
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ac.primary,
                    side: BorderSide(color: ac.primary.withValues(alpha: .3)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.library_books_rounded, size: 20),
                  label: const Text('Browse Library', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () {
                    // Navigate to library or dictionary
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
