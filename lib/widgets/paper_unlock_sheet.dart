// lib/widgets/paper_unlock_sheet.dart
// Shown when a student taps to open a past paper, note or book they haven't unlocked
// yet. Silver & Gold subscribers never see this — isContentUnlocked() already
// returns true for them before this sheet would ever be triggered.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../models/academic_content.dart';
import '../models/entitlement.dart';
import '../models/xp_transaction.dart';
import '../repositories/xp_repository.dart';
import '../core/result.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';
import 'premium_unlock_sheet.dart';

/// Returns true if the content ended up unlocked just now via XP —
/// false if the user backed out.
Future<bool> showContentUnlockSheet(
  BuildContext context, {
  required AppUser user,
  required String contentId,
  required String contentTitle,
  ContentType contentType = ContentType.pastPaper,
  int? cost,
}) async {
  final effectiveCost = cost ?? XpRepository.costForContentType(contentType);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ContentUnlockSheetContent(
      user: user,
      contentId: contentId,
      contentTitle: contentTitle,
      contentType: contentType,
      cost: effectiveCost,
    ),
  );
  return result ?? false;
}

/// Backward-compatible alias for past paper unlock
Future<bool> showPaperUnlockSheet(
  BuildContext context, {
  required AppUser user,
  required String paperId,
  required String paperTitle,
  int cost = kPaperUnlockCost,
}) => showContentUnlockSheet(
  context,
  user: user,
  contentId: paperId,
  contentTitle: paperTitle,
  contentType: ContentType.pastPaper,
  cost: cost,
);

class _ContentUnlockSheetContent extends StatefulWidget {
  final AppUser user;
  final String contentId, contentTitle;
  final ContentType contentType;
  final int cost;
  const _ContentUnlockSheetContent({
    required this.user,
    required this.contentId,
    required this.contentTitle,
    required this.contentType,
    required this.cost,
  });

  @override
  State<_ContentUnlockSheetContent> createState() => _ContentUnlockSheetContentState();
}

class _ContentUnlockSheetContentState extends State<_ContentUnlockSheetContent> {
  bool _unlocking = false;
  String? _error;

  Future<void> _unlockWithXp() async {
    if (_unlocking) return;
    HapticFeedback.mediumImpact();
    setState(() { _unlocking = true; _error = null; });
    final result = await XpRepository.instance.spendXp(
      userId: widget.user.id, paperId: widget.contentId, cost: widget.cost,
    );
    if (!mounted) return;
    if (result is Success) {
      showToast(context, '✅ Unlocked with ${widget.cost} XP');
      Navigator.pop(context, true);
    } else {
      setState(() { _error = (result as Failure).message; _unlocking = false; });
    }
  }

  void _openUpgradeSheet() {
    Navigator.pop(context, false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl)),
      ),
      builder: (_) => PremiumUnlockSheet(
        userId: widget.user.id,
        initialTier: EntitlementTier.silver,
        onUnlockSuccess: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final typeName = switch (widget.contentType) {
      ContentType.pastPaper => 'Past Paper',
      ContentType.note => 'Lecture Notes',
      ContentType.book => 'Book / Textbook',
      _ => 'Academic Resource',
    };

    final typeIcon = switch (widget.contentType) {
      ContentType.pastPaper => Icons.assignment_outlined,
      ContentType.note => Icons.description_outlined,
      ContentType.book => Icons.menu_book_rounded,
      _ => Icons.article_outlined,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: ac.goldBg, shape: BoxShape.circle),
            child: Icon(typeIcon, color: ac.gold, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Unlock this $typeName', style: AppText.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(widget.contentTitle, style: AppText.bodySm, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          FutureBuilder<(int, int)>(
            future: XpRepository.instance.getBalance(widget.user.id),
            builder: (context, snap) {
              final balance = snap.data?.$1 ?? 0;
              final canAfford = balance >= widget.cost;
              return Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(Rad.md)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Cost', style: AppText.caption),
                        Row(children: [
                          Icon(Icons.bolt_rounded, size: 16, color: ac.gold),
                          Text('${widget.cost} XP', style: AppText.title.copyWith(fontSize: 15)),
                        ]),
                      ]),
                    ),
                    Container(width: 1, height: 32, color: ac.bdr),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(left: 12), child: Text('Your balance', style: AppText.caption)),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text('$balance XP', style: AppText.title.copyWith(
                              fontSize: 15, color: canAfford ? ac.grn : ac.red)),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (!canAfford)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Not enough XP yet — need ${widget.cost - balance} more. '
                        'Earn XP by completing quizzes and daily challenges, or unlock all resources with Silver/Gold.',
                        style: AppText.caption.copyWith(color: ac.red), textAlign: TextAlign.center),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: AppText.caption.copyWith(color: ac.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryBtn(
                    label: canAfford ? 'Unlock with ${widget.cost} XP' : 'Upgrade to Silver (Unlimited)',
                    loading: _unlocking,
                    onTap: canAfford
                        ? (!_unlocking ? _unlockWithXp : () {})
                        : _openUpgradeSheet,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Not now', style: AppText.bodySm.copyWith(color: ac.muted)),
                ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
