// lib/widgets/paper_unlock_sheet.dart
// Shown when a student taps to open a past paper they haven't unlocked
// yet. Premium subscribers never see this — isPaperUnlocked() already
// returns true for them before this sheet would ever be triggered.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../models/xp_transaction.dart';
import '../repositories/xp_repository.dart';
import '../core/result.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';

/// Returns true if the paper ended up unlocked just now via XP —
/// false if the user backed out.
Future<bool> showPaperUnlockSheet(
  BuildContext context, {
  required AppUser user,
  required String paperId,
  required String paperTitle,
  int cost = kPaperUnlockCost,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PaperUnlockSheetContent(user: user, paperId: paperId, paperTitle: paperTitle, cost: cost),
  );
  return result ?? false;
}

class _PaperUnlockSheetContent extends StatefulWidget {
  final AppUser user;
  final String paperId, paperTitle;
  final int cost;
  const _PaperUnlockSheetContent({required this.user, required this.paperId, required this.paperTitle, required this.cost});

  @override
  State<_PaperUnlockSheetContent> createState() => _PaperUnlockSheetContentState();
}

class _PaperUnlockSheetContentState extends State<_PaperUnlockSheetContent> {
  bool _unlocking = false;
  String? _error;

  Future<void> _unlockWithXp() async {
    HapticFeedback.mediumImpact();
    setState(() { _unlocking = true; _error = null; });
    final result = await XpRepository.instance.spendXp(
      userId: widget.user.id, paperId: widget.paperId, cost: widget.cost,
    );
    if (!mounted) return;
    if (result is Success) {
      showToast(context, '✅ Unlocked with ${widget.cost} XP');
      Navigator.pop(context, true);
    } else {
      setState(() { _error = (result as Failure).message; _unlocking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: ac.goldBg, shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, color: ac.gold, size: 26),
          ),
          const SizedBox(height: 14),
          Text('Unlock this paper', style: AppText.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 4),
          Text(widget.paperTitle, style: AppText.bodySm, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                        'Or unlock everything instantly with Premium.',
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
                    label: 'Unlock with XP',
                    loading: _unlocking,
                    onTap: canAfford && !_unlocking ? _unlockWithXp : () {},
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
