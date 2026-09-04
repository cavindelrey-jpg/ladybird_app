// lib/features/testing/leaderboard_page.dart
// Spec item 12: two strictly separate rankings — School (item 12A,
// scoped server-side to the caller's own institution_id, see
// get_school_leaderboard()'s own boundary check) and Global (item 12B,
// platform-wide). The Global tab only renders when
// Branding.xpEconomyEnabled (Academia only, spec item 11) — a
// single-school white-label build (Green Hills, ...) has no "global
// Academia platform" for its students to be ranked against; its own
// School tab still works everywhere, matching item 12A's own
// Green-Hills-Academy example.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../config/branding.dart';
import '../../repositories/leaderboard_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class LeaderboardPage extends StatefulWidget {
  final AppUser user;
  const LeaderboardPage({super.key, required this.user});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with SingleTickerProviderStateMixin {
  late final bool _showGlobal = Branding.current.xpEconomyEnabled;
  late final TabController _tabs = TabController(length: _showGlobal ? 2 : 1, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Leaderboard', style: AppText.title),
        bottom: _showGlobal
            ? TabBar(
                controller: _tabs,
                labelColor: ac.primary, unselectedLabelColor: ac.muted,
                indicatorColor: ac.primary,
                tabs: const [Tab(text: 'My School'), Tab(text: 'Academia')],
              )
            : null,
      ),
      body: AppBackground(child: TabBarView(
        controller: _tabs,
        children: [
          _LeaderboardList(
            future: LeaderboardRepository.instance.getSchoolLeaderboard(widget.user.schoolId ?? ''),
            me: widget.user.id,
            emptySubtitle: widget.user.schoolId == null || widget.user.schoolId!.isEmpty
                ? 'Join a school to see its leaderboard.'
                : 'No ranked students yet — be the first to earn XP.',
          ),
          if (_showGlobal)
            _LeaderboardList(
              future: LeaderboardRepository.instance.getGlobalLeaderboard(),
              me: widget.user.id,
              emptySubtitle: 'No ranked students yet — be the first to earn XP.',
            ),
        ],
      )),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final Future<List<LeaderboardEntry>> future;
  final String me;
  final String emptySubtitle;
  const _LeaderboardList({required this.future, required this.me, required this.emptySubtitle});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<List<LeaderboardEntry>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
        }
        if (snap.hasError) return ErrorView(message: snap.error.toString());
        final entries = snap.data ?? const <LeaderboardEntry>[];
        if (entries.isEmpty) {
          return EmptyState(icon: Icons.leaderboard_outlined, title: 'No rankings yet', subtitle: emptySubtitle);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final isMe = e.userId == me;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ACard(
                color: isMe ? ac.primary.withValues(alpha: 0.08) : null,
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text('${e.rank}', style: AppText.title.copyWith(fontSize: 15, color: e.rank <= 3 ? ac.gold : ac.muted)),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 16, backgroundColor: ac.navy,
                    backgroundImage: e.photoUrl != null && e.photoUrl!.isNotEmpty ? NetworkImage(e.photoUrl!) : null,
                    child: e.photoUrl == null || e.photoUrl!.isEmpty
                        ? Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 13))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(isMe ? '${e.name} (You)' : e.name, style: AppText.title.copyWith(fontSize: 14))),
                  Text('${e.lifetimeXp} XP', style: AppText.title.copyWith(fontSize: 14, color: ac.primary)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
