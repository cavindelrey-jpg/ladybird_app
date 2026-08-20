// Repository-driven. Zero static club list.
// Design pass matching the reference layout: header (bell + avatar),
// search + filter row, My Clubs (with Joined/Pending status), Discover
// Clubs (with Approval required/Open to all badges), and cross-promo
// info cards. Backed by a real approval workflow — Club.requiresApproval
// + ClubJoinRequest — that didn't exist before this pass; previously
// every club was instant-join regardless of what the UI implied.
//
// ── Clubs remake changes (see README_CLUBS_REMAKE.md for the full
//    writeup) ─────────────────────────────────────────────────────────
// - My Clubs was a plain vertical list of rows, each showing a raw
//   emoji glyph in a tinted circle regardless of whether the club had a
//   real banner photo. It's now a horizontal photo-card rail — matches
//   Discover Clubs' existing card treatment (which DID already try
//   bannerUrl first) and the new mockup.
// - Every club "logo" (My Clubs, Discover, the detail hero,
//   create/settings icon pickers) now renders through ClubVisuals
//   instead of a literal emoji character — see theme/club_visuals.dart
//   for why.
// - _recommendedClubsSection could render its header followed by a
//   visually empty strip: it computed candidates from the full club
//   pool without excluding clubs the user had already joined, relying
//   on each card silently collapsing to zero width once its own
//   member-check resolved. Now pre-filtered against watchMyClubs before
//   deciding whether to render anything.
// - ClubDetailPage's hero is a full rebuild: a real (not faked) "X
//   online" figure via ClubRepository.pingClubActive/watchOnlineCount
//   (same mechanism as Messages' conversation presence), an Admins row,
//   a Joined/Join status menu, and a school-verified badge for
//   school-linked clubs (schoolId != null) — never a fabricated
//   "verified" flag. The CHAT tab moved to its own icon-button route
//   (ClubChatPage, wrapping the same _ChatTab widget) so the visible tab
//   bar matches the mockup's five tabs without deleting the working
//   club-chat feature Messages' merged inbox already depends on.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../models/models.dart';
import '../../repositories/club_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../core/result.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/club_visuals.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../messages/messages_home_page.dart';
import 'create_club_page.dart';
import 'club_members_page.dart';
import 'club_settings_page.dart';
import 'club_discussion_page.dart';

class ClubsPage extends StatefulWidget {
  final AppUser user;
  const ClubsPage({super.key, required this.user});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  String _searchQuery = '';
  String? _selectedCategory; // null == "All Clubs"
  final _searchCtrl = TextEditingController();

  // Created once and reused across rebuilds -- StreamBuilder resets to its
  // "waiting" state (dropping the whole ListView, including the search bar
  // itself) whenever it's handed a stream with a different identity, and
  // building this inline in `build()` created a brand-new .snapshots()
  // stream on every keystroke's setState. That's what made the Clubs
  // search bar appear to vanish while typing.
  late final Stream<List<Club>> _clubsStream =
      ClubRepository.instance.watchClubs(schoolId: widget.user.schoolId);

  bool get _canCreate => !widget.user.isGuest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AppBackground(child: SafeArea(
        child: StreamBuilder<List<Club>>(
          stream: _clubsStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _ClubsSkeleton();
            }
            if (snap.hasError) {
              return ErrorView(message: snap.error.toString());
            }
            final allClubs = snap.data ?? const <Club>[];
            var filtered = _searchQuery.isEmpty
                ? allClubs
                : allClubs.where((c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
            if (_selectedCategory != null) {
              filtered = filtered.where((c) => c.category == _selectedCategory).toList();
            }
            final categories = allClubs.map((c) => c.category).toSet().toList()..sort();

            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _header(context),
                const SizedBox(height: 10),
                _searchAndFilter(),
                if (categories.length > 1) ...[
                  const SizedBox(height: 12),
                  _categoryChips(categories),
                ],
                const SizedBox(height: 20),
                // production_plan.md §7B — "Contextual recommendations should
                // exist throughout Academia." Only shown in the unfiltered
                // view, same "don't stack a recommendation rail on top of a
                // search/filter the user is already doing" gate every other
                // surface's rail uses (Library/Courses/Past Papers).
                if (_searchQuery.isEmpty && _selectedCategory == null) ...[
                  _recommendedClubsSection(context, allClubs),
                ],
                _myClubsSection(context, filtered),
                const SizedBox(height: 24),
                _discoverClubsSection(context, filtered, allClubs),
                const SizedBox(height: 20),
                _infoCards(context),
              ],
            );
          },
        ),
      )),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              backgroundColor: C.navy,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateClubPage(user: widget.user)));
              },
              icon: const Icon(Icons.add_rounded, color: C.gold),
              label: Text('Create Club', style: AppText.button.copyWith(fontSize: 13)),
            )
          : null,
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Clubs', style: AppText.h1.copyWith(fontSize: 22)),
            Text('Find your people. Share ideas. Grow together.', style: AppText.caption.copyWith(fontSize: 12)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: C.txt2),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: widget.user.id))),
        ),
        UserAvatar(initials: widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
            radius: 18, photoUrl: widget.user.photoUrl),
      ]),
    );
  }

  Widget _searchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppText.bodySm.copyWith(color: C.txt),
              decoration: InputDecoration(
                hintText: 'Search clubs by name, interest or subject…',
                hintStyle: AppText.bodySm.copyWith(color: C.muted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: C.muted),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
          child: Row(children: [
            const Icon(Icons.filter_list_rounded, size: 18, color: C.txt2),
            const SizedBox(width: 6),
            Text('Filter', style: AppText.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  /// "All Clubs" + every real category currently in use, driven by
  /// actual Club.category values (not a hardcoded list) — matches the
  /// mockup's chip row without inventing categories no club actually has.
  Widget _categoryChips(List<String> categories) {
    final chips = ['All Clubs', ...categories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = chips[i];
          final isAll = label == 'All Clubs';
          final active = isAll ? _selectedCategory == null : _selectedCategory == label;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = isAll ? null : label);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? C.navy : C.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? C.navy : C.bdr),
                ),
                child: Text(label, style: AppText.caption.copyWith(
                    fontSize: 12.5, fontWeight: FontWeight.w700,
                    color: active ? C.gold : C.txt2)),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Horizontal photo-card rail of clubs the user has joined, plus any
  /// they have a pending approval request for (kept visible so a pending
  /// request doesn't just disappear — Discover Clubs hides its own card
  /// for the same club once a request is pending). Pre-filtered against
  /// watchMyClubIds/watchMyPendingRequestClubIds BEFORE building any
  /// cards — same fix as _recommendedClubsSection below, and for the
  /// same reason: building a card per club in the whole (possibly
  /// search-filtered) pool and letting each one silently self-hide once
  /// its own status resolves can leave this rail rendering mostly empty
  /// space.
  Widget _myClubsSection(BuildContext context, List<Club> allClubs) {
    if (widget.user.isGuest) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('My Clubs', style: AppText.h2.copyWith(fontSize: 16))),
        ]),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: ClubRepository.instance.watchMyClubIds(widget.user.id),
          builder: (context, joinedSnap) {
            if (joinedSnap.hasError) {
              CrashService.instance.recordError(joinedSnap.error, joinedSnap.stackTrace,
                  context: 'ClubsPage.watchMyClubIds(${widget.user.id})');
            }
            final joinedIds = (joinedSnap.data ?? const <String>[]).toSet();
            return StreamBuilder<List<String>>(
              stream: ClubRepository.instance.watchMyPendingRequestClubIds(widget.user.id),
              builder: (context, pendingSnap) {
                if (joinedSnap.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 260,
                    child: ListView(scrollDirection: Axis.horizontal, children: const [
                      SizedBox(width: 200, child: ShimmerBlock(height: 260)),
                      SizedBox(width: 12),
                      SizedBox(width: 200, child: ShimmerBlock(height: 260)),
                    ]),
                  );
                }
                final pendingIds = (pendingSnap.data ?? const <String>[]).toSet();
                final myClubs = allClubs.where((c) => joinedIds.contains(c.id) || pendingIds.contains(c.id)).toList();
                if (myClubs.isEmpty) {
                  return Text('No clubs yet — discover one below or create your own.', style: AppText.bodySm);
                }
                return SizedBox(
                  height: 260,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: myClubs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _MyClubTile(
                      club: myClubs[i],
                      pending: !joinedIds.contains(myClubs[i].id),
                      onOpen: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ClubDetailPage(club: myClubs[i], user: widget.user))),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ]),
    );
  }

  /// production_plan.md §7B — "Contextual recommendations should exist
  /// throughout Academia," replacing the removed Clubs banner. Ranks the
  /// club list this page already streamed (`allClubs`) against the
  /// signed-in user's favorite subjects via
  /// RecommendationRepository.forClubs -- no second Firestore read, same
  /// "hide entirely rather than show an empty personalized rail"
  /// treatment as every other surface's recommendation rail.
  ///
  /// FIX: this previously computed `recommended` from the whole club
  /// pool without excluding clubs the user had already joined, then
  /// relied on each `_DiscoverClubCard` to silently collapse to
  /// `SizedBox.shrink()` once it separately discovered (async, per
  /// card) that the user was a member. If someone had already joined
  /// most or all of their category-matched clubs, this rendered a
  /// "Recommended for You" header followed by a visually empty
  /// 260px-tall strip — which reads as broken, not empty-and-hidden.
  /// Now pre-filtered against watchMyClubIds before deciding whether to
  /// render anything at all, matching the section's own "hide entirely"
  /// intent.
  Widget _recommendedClubsSection(BuildContext context, List<Club> allClubs) {
    if (widget.user.isGuest || widget.user.favoriteSubjects.isEmpty) {
      return const SizedBox.shrink();
    }
    final candidates = RecommendationRepository.instance
        .forClubs(pool: allClubs, favoriteSubjects: widget.user.favoriteSubjects);
    if (candidates.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<String>>(
      stream: ClubRepository.instance.watchMyClubIds(widget.user.id),
      builder: (context, joinedSnap) {
        if (joinedSnap.hasError) {
          CrashService.instance.recordError(joinedSnap.error, joinedSnap.stackTrace,
              context: 'ClubsPage._recommendedClubsSection.watchMyClubIds(${widget.user.id})');
        }
        final joinedIds = (joinedSnap.data ?? const <String>[]).toSet();
        final recommended = candidates.where((c) => !joinedIds.contains(c.id)).toList();
        if (recommended.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recommended for You', style: AppText.h2.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recommended.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _DiscoverClubCard(
                  club: recommended[i], user: widget.user,
                  onOpen: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ClubDetailPage(club: recommended[i], user: widget.user))),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }

  Widget _discoverClubsSection(BuildContext context, List<Club> allClubs, List<Club> unfilteredClubs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Discover Clubs', style: AppText.h2.copyWith(fontSize: 16))),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AllClubsPage(clubs: unfilteredClubs, user: widget.user))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: AppText.subtitle.copyWith(
                    color: C.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (allClubs.isEmpty)
          Text('No clubs on Academia yet — be the first to create one.', style: AppText.bodySm)
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: allClubs[i], user: widget.user,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: allClubs[i], user: widget.user))),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _infoCards(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.groups_rounded, color: C.blu, size: 20),
              const SizedBox(height: 8),
              Text('Clubs', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Shared spaces around common interests. Join open clubs or request to join those that require approval.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.chat_bubble_rounded, color: C.pur, size: 20),
              const SizedBox(height: 8),
              Text('Messages', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('One-to-one connections. Follow anyone or send a friend request to start a conversation.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.user.isGuest) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesHomePage(user: widget.user)));
                  },
                  child: Text('Go to Messages →', style: AppText.caption.copyWith(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: C.pur)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ClubsSkeleton extends StatelessWidget {
  const _ClubsSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const ShimmerLine(width: 100, height: 24),
        const SizedBox(height: 20),
        for (int i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(children: [
              ShimmerCircle(size: 44),
              SizedBox(width: 12),
              Expanded(child: ShimmerLine(height: 14)),
            ]),
          ),
      ],
    );
  }
}

/// A card in "My Clubs" — photo-card treatment matching the mockup
/// (real bannerUrl behind a ClubVisuals icon badge, a Joined/Pending
/// pill, name, description, member count). [pending] is resolved by the
/// caller (_myClubsSection) up front rather than re-queried per card —
/// see that method's doc comment.
class _MyClubTile extends StatelessWidget {
  final Club club;
  final bool pending;
  final VoidCallback onOpen;
  const _MyClubTile({required this.club, required this.pending, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final hasCover = (club.bannerUrl ?? '').isNotEmpty;
    final iconOption = ClubVisuals.fallbackIconFor(club);
    final accent = ClubVisuals.colorFor(club);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: pending ? null : () { HapticFeedback.selectionClick(); onOpen(); },
        child: Container(
          width: 200,
          decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              SizedBox(
                height: 96, width: double.infinity,
                child: hasCover
                    ? Image.network(club.bannerUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerFallback(accent, iconOption))
                    : _bannerFallback(accent, iconOption),
              ),
              // The club's own logo photo (Club.thumbnailUrl) — the
              // mockup's small corner badge, now a real uploaded picture
              // rather than a generic icon whenever the admin has set one.
              Positioned(
                left: 10, bottom: -14,
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(11))),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: C.surf, width: 2.5),
                  ),
                  child: ClubLogo(club: club, size: 40, borderRadius: BorderRadius.circular(11)),
                ),
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pending ? C.orgb : C.grnb,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(pending ? 'Pending' : 'Joined ✓', style: AppText.label.copyWith(
                      fontSize: 9.5, color: pending ? C.org : C.grn, letterSpacing: 0)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(club.name, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _MemberAvatarStack(clubId: club.id),
                  const SizedBox(width: 6),
                  Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bannerFallback(Color accent, ClubIconOption iconOption) => Container(
        color: accent.withValues(alpha: .16),
        alignment: Alignment.center,
        child: Icon(iconOption.icon, color: accent, size: 30),
      );
}

/// Discover card — join instantly if open, or request-to-join if the
/// club requires approval. Hides itself once the user is already a
/// member or has a pending request (those show up in My Clubs instead).
class _DiscoverClubCard extends StatelessWidget {
  final Club club;
  final AppUser user;
  final VoidCallback onOpen;
  final bool fullWidth;
  const _DiscoverClubCard({required this.club, required this.user, required this.onOpen, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    if (user.isGuest) return _card(context, joined: false, pending: false);
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final isMember = (roleSnap.data ?? ClubRole.visitor) != ClubRole.visitor;
        if (isMember) return const SizedBox.shrink();
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
              // Same reasoning as _MyClubTile above: this only gates
              // whether the join card still shows, so record the failure
              // and fall back to showing the card rather than an ErrorView
              // wedged into a horizontally-scrolling card list.
              CrashService.instance.recordError(reqSnap.error, reqSnap.stackTrace,
                  context: 'ClubsPage.watchMyRequestStatus(${club.id}, ${user.id})');
              return _card(context, joined: false, pending: false);
            }
            final pending = reqSnap.data == ClubJoinRequestStatus.pending;
            if (pending) return const SizedBox.shrink();
            return _card(context, joined: false, pending: false);
          },
        );
      },
    );
  }

  Widget _card(BuildContext context, {required bool joined, required bool pending}) {
    final hasCover = (club.bannerUrl ?? '').isNotEmpty;
    final iconOption = ClubVisuals.fallbackIconFor(club);
    final accent = ClubVisuals.colorFor(club);
    Widget fallback() => Container(
          color: accent.withValues(alpha: .16),
          alignment: Alignment.center,
          child: Icon(iconOption.icon, color: accent, size: 26),
        );
    return Container(
      width: fullWidth ? double.infinity : 200,
      decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(
            height: 84, width: double.infinity,
            child: hasCover
                ? Image.network(club.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
                : fallback(),
          ),
          // Real uploaded club logo photo when the admin has set one —
          // see ClubLogo / Club.thumbnailUrl.
          Positioned(
            left: 10, bottom: -14,
            child: Container(
              width: 36, height: 36,
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.surf, width: 2.5),
              ),
              child: ClubLogo(club: club, size: 36, borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(club.name, style: AppText.title.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Icon(club.requiresApproval ? Icons.lock_outline_rounded : Icons.public_rounded,
                  size: 12, color: club.requiresApproval ? C.pur : C.grn),
              const SizedBox(width: 4),
              Text(club.requiresApproval ? 'Approval required' : 'Open to all',
                  style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: club.requiresApproval ? C.pur : C.grn)),
            ]),
            const SizedBox(height: 6),
            // Expanded only makes sense inside the horizontal preview's fixed-
            // height card; the vertical "See all" list has no bounded height
            // to expand into, so it just wraps the text directly there.
            if (fullWidth)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              )
            else
              Expanded(
                child: Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Row(children: [
              _MemberAvatarStack(clubId: club.id),
              const SizedBox(width: 6),
              Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleJoin(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(club.requiresApproval ? 'Request to Join' : 'Join Club',
                    style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    if (user.isGuest) {
      showToast(context, 'Create an account to join clubs');
      return;
    }
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(
        club.id, user.id, name: user.name, photoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? '✅ Welcome to ${club.name}!' : 'Failed to join');
      }
    }
  }
}

/// The mockup's small overlapping-avatar cluster next to a member count
/// — a live preview of up to 3 members via
/// ClubRepository.watchMemberPreview (bounded, unlike the full Members
/// tab's unlimited watchMembers). Renders nothing while loading or if
/// the club has no members yet, rather than a placeholder shimmer that
/// would jitter the whole card's layout on every scroll.
class _MemberAvatarStack extends StatelessWidget {
  final String clubId;
  const _MemberAvatarStack({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClubMember>>(
      stream: ClubRepository.instance.watchMemberPreview(clubId),
      builder: (context, snap) {
        final members = snap.data ?? const <ClubMember>[];
        if (members.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: 16.0 + (members.length - 1) * 12.0,
          height: 20,
          child: Stack(children: [
            for (int i = 0; i < members.length; i++)
              Positioned(
                left: i * 12.0,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.surf, width: 1.5)),
                  child: UserAvatar(
                    initials: members[i].name.isEmpty ? '?' : members[i].name[0].toUpperCase(),
                    radius: 9.5, photoUrl: members[i].photoUrl,
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// Full scrollable list behind Discover Clubs' "See all" -- the homepage
/// section only shows a horizontally-scrolling preview of every club, so
/// this is the same data in an actually-scannable vertical list rather
/// than a real paginated fetch (there's nothing more to page in; the
/// preview already held every club).
class AllClubsPage extends StatelessWidget {
  final List<Club> clubs;
  final AppUser user;
  const AllClubsPage({super.key, required this.clubs, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Discover Clubs', style: AppText.title),
      ),
      body: AppBackground(child: clubs.isEmpty
          ? const EmptyState(icon: Icons.groups_outlined, title: 'No clubs on Academia yet',
              subtitle: 'Be the first to create one.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: clubs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: clubs[i], user: user, fullWidth: true,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: clubs[i], user: user))),
              ),
            )),
    );
  }
}

// ── Club Detail Page ──────────────────────────────────────
class ClubDetailPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  const ClubDetailPage({super.key, required this.club, required this.user});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Timer? _presenceHeartbeat;
  bool _pingedOnce = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _presenceHeartbeat?.cancel();
    super.dispose();
  }

  /// Starts the "X online" heartbeat, but only once we've actually
  /// confirmed (via the role stream the hero already needs) that the
  /// current user is a member — see
  /// ClubRepository.pingClubActive's doc comment for why calling it for
  /// a non-member must never happen even though the method itself is
  /// also defensive about it.
  void _maybeStartPresence(ClubRole role) {
    if (_pingedOnce || role == ClubRole.visitor) return;
    _pingedOnce = true;
    ClubRepository.instance.pingClubActive(widget.club.id, widget.user.id);
    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      ClubRepository.instance.pingClubActive(widget.club.id, widget.user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          StreamBuilder<ClubRole>(
            stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.user.id),
            builder: (context, roleSnap) {
              final role = roleSnap.data ?? ClubRole.visitor;
              _maybeStartPresence(role);
              return _Hero(club: widget.club, user: widget.user, role: role);
            },
          ),
          Material(
            color: C.surf,
            child: TabBar(
              controller: _tabs, isScrollable: true,
              labelColor: C.navy, unselectedLabelColor: C.muted,
              indicatorColor: C.gold, indicatorWeight: 2.5,
              labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              tabs: const [
                Tab(text: 'FEED'), Tab(text: 'DISCUSSIONS'), Tab(text: 'MEMBERS'),
                Tab(text: 'RESOURCES'), Tab(text: 'EVENTS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _FeedTab(club: widget.club, user: widget.user),
              _DiscussionsTab(club: widget.club, user: widget.user),
              ClubMembersBody(club: widget.club, currentUser: widget.user),
              _ResourcesTab(club: widget.club, user: widget.user),
              _EventsTab(club: widget.club, user: widget.user),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The club's banner + identity block. CHAT moved here as an icon
/// button (see the mockup: five tabs, no visible Chat tab) rather than
/// being deleted — it still opens the same fully-built, Firestore-backed
/// _ChatTab widget Messages' merged inbox already surfaces this club's
/// chat through, just via its own route (ClubChatPage) instead of a tab.
class _Hero extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ClubRole role;
  const _Hero({required this.club, required this.user, required this.role});

  bool get _isMember => role != ClubRole.visitor;
  bool get _isAdmin => role == ClubRole.admin;

  @override
  Widget build(BuildContext context) {
    final hasBanner = (club.bannerUrl ?? '').isNotEmpty;
    final iconOption = ClubVisuals.fallbackIconFor(club);
    final accent = ClubVisuals.colorFor(club);
    // A school-linked club (created under a real institution) gets the
    // verified badge — a real distinction already in the data model,
    // never a fabricated flag every club would otherwise get.
    final isVerified = (club.schoolId ?? '').isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(
          height: 176, width: double.infinity,
          child: hasBanner
              ? Image.network(club.bannerUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _bannerFallback(accent, iconOption))
              : _bannerFallback(accent, iconOption),
        ),
        Container(
          height: 176,
          decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Color(0x99000000), Color(0x1A000000), Color(0x33000000)],
              begin: Alignment.bottomCenter, end: Alignment.topCenter)),
        ),
        Positioned(
          left: 12, top: 8,
          child: _circleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          right: 12, top: 8,
          child: Row(children: [
            _circleIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Club chat',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ClubChatPage(club: club, user: user))),
            ),
            const SizedBox(width: 8),
            _circleIconButton(icon: Icons.more_horiz_rounded, onTap: () => _showMenu(context)),
          ]),
        ),
        Positioned(
          left: 20, bottom: -36,
          // Real uploaded club logo photo — see ClubLogo / Club.thumbnailUrl.
          child: Container(
            width: 84, height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: Shad.md),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: C.surf, width: 4),
            ),
            child: ClubLogo(club: club, size: 84),
          ),
        ),
      ]),
      const SizedBox(height: 44),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(club.name, style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: C.txt)),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'School-verified club',
                    child: Icon(Icons.verified_rounded, color: C.blu, size: 18),
                  ),
                ],
              ]),
            ),
            _joinedButton(context),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('${club.memberCount} members', style: AppText.bodySm.copyWith(fontSize: 12.5)),
            StreamBuilder<int>(
              stream: ClubRepository.instance.watchOnlineCount(club.id),
              builder: (context, snap) {
                final online = snap.data ?? 0;
                if (online <= 0) return const SizedBox.shrink();
                return Text(' • $online online', style: AppText.bodySm.copyWith(fontSize: 12.5, color: C.grn, fontWeight: FontWeight.w700));
              },
            ),
          ]),
          const SizedBox(height: 10),
          Text(club.description, style: AppText.bodySm.copyWith(fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          _AdminsRow(club: club, user: user),
        ]),
      ),
    ]);
  }

  Widget _bannerFallback(Color accent, ClubIconOption iconOption) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.black, .35)!])),
        alignment: Alignment.center,
        // A large, faint watermark of the club's own icon — a themed
        // backdrop every club gets automatically (no per-club custom
        // artwork required), rather than every fallback banner looking
        // identical regardless of what the club is about.
        child: Icon(iconOption.icon, color: Colors.white.withValues(alpha: .18), size: 120),
      );

  Widget _circleIconButton({required IconData icon, String? tooltip, required VoidCallback onTap}) {
    final button = Material(
      color: Colors.black.withValues(alpha: .32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _joinedButton(BuildContext context) {
    if (user.isGuest) return const SizedBox.shrink();
    if (!_isMember) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: () => _handleJoin(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(club.requiresApproval ? 'Request to Join' : 'Join Club',
              style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showJoinedMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: C.grnb, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Joined', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.grn)),
            const SizedBox(width: 3),
            Icon(Icons.expand_more_rounded, size: 15, color: C.grn),
          ]),
        ),
      ),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(club.id, user.id, name: user.name, photoUrl: user.photoUrl);
      if (context.mounted) {
        showToast(context, result is Success ? '✅ Welcome to ${club.name}!' : 'Failed to join');
      }
    }
  }

  void _showJoinedMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isAdmin)
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Club Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubSettingsPage(club: club, currentUser: user)));
              },
            ),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('View Members'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ClubMembersPage(club: club, currentUser: user)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Invite via Share'),
            onTap: () {
              Navigator.pop(context);
              Share.share('Join "${club.name}" on Academia!\n\n${club.description}\n\n'
                  'Open the Academia app, go to Clubs, and search for it to join.');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: C.red),
            title: const Text('Leave Club', style: TextStyle(color: C.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmLeave(context);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this club?'),
        content: Text('You can rejoin "${club.name}" any time${club.requiresApproval ? ", but you'll need approval again." : "."}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: C.red))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ClubRepository.instance.leaveClub(club.id, user.id);
    if (context.mounted) {
      if (result is Success) {
        Navigator.of(context).pop();
        showToast(context, 'Left ${club.name}.');
      } else {
        showToast(context, (result as Failure).message, isError: true);
      }
    }
  }

  void _showMenu(BuildContext context) => _showJoinedMenu(context);
}

/// "Admins" row — up to 3 admin avatars + a tappable "+N" — matches the
/// mockup. Sourced from the same full watchMembers() the Members tab
/// already reads (filtered client-side to admins), rather than a second
/// bespoke query, since a club's admin count is always small.
class _AdminsRow extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _AdminsRow({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClubMember>>(
      stream: ClubRepository.instance.watchMembers(club.id),
      builder: (context, snap) {
        final admins = (snap.data ?? const <ClubMember>[]).where((m) => m.role == ClubRole.admin).toList();
        if (admins.isEmpty) return const SizedBox.shrink();
        final shown = admins.take(3).toList();
        final extra = admins.length - shown.length;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ClubMembersPage(club: club, currentUser: user))),
            child: Row(children: [
              Text('Admins', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.txt2)),
              const SizedBox(width: 10),
              SizedBox(
                width: 20.0 + (shown.length - 1) * 16.0,
                height: 26,
                child: Stack(children: [
                  for (int i = 0; i < shown.length; i++)
                    Positioned(
                      left: i * 16.0,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.surf, width: 2)),
                        child: UserAvatar(
                          initials: shown[i].name.isEmpty ? '?' : shown[i].name[0].toUpperCase(),
                          radius: 13, photoUrl: shown[i].photoUrl,
                        ),
                      ),
                    ),
                ]),
              ),
              if (extra > 0) ...[
                const SizedBox(width: 6),
                Text('+$extra', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.txt2)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Club chat, moved off the visible tab bar (see the mockup: five tabs,
/// no Chat tab) into its own route — the underlying _ChatTab widget is
/// unchanged and still the same real-time, Firestore-backed thread
/// Messages' merged inbox already surfaces this club through.
class ClubChatPage extends StatefulWidget {
  final Club club;
  final AppUser user;
  const ClubChatPage({super.key, required this.club, required this.user});

  @override
  State<ClubChatPage> createState() => _ClubChatPageState();
}

class _ClubChatPageState extends State<ClubChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final msg = ClubMessage(
      id: '', senderId: widget.user.id, senderName: widget.user.name,
      senderInitials: widget.user.initials, text: text, time: DateTime.now(),
    );
    _ctrl.clear();
    await ClubRepository.instance.sendMessage(widget.club.id, msg);
    await Future.delayed(const Duration(milliseconds: 80));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('${widget.club.name} · Chat', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: _ChatTab(club: widget.club, user: widget.user, scroll: _scroll, ctrl: _ctrl, onSend: _send),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ScrollController scroll;
  final TextEditingController ctrl;
  final VoidCallback onSend;
  const _ChatTab({required this.club, required this.user,
    required this.scroll, required this.ctrl, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: StreamBuilder<List<ClubMessage>>(
          stream: ClubRepository.instance.watchMessages(club.id),
          builder: (context, snap) {
            final messagesList = snap.data ?? [];
            return ListView.builder(
              controller: scroll, padding: const EdgeInsets.all(16),
              itemCount: messagesList.length,
              itemBuilder: (_, i) {
                final m = messagesList[i];
                final isMe = m.senderId == user.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe)
                        Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                                color: C.goldp, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(m.senderInitials,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: C.gold)))),
                      Flexible(child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(padding: const EdgeInsets.only(left: 2, bottom: 2),
                                child: Text(m.senderName,
                                    style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600, color: C.muted))),
                          GestureDetector(
                            onLongPress: (isMe && !m.deleted) ? () => _confirmDelete(context, m) : null,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * .65),
                                decoration: BoxDecoration(
                                  color: m.deleted ? C.surf3 : (isMe ? C.primary : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: (isMe && !m.deleted) ? null : Border.all(color: C.bdr),
                                ),
                                child: Text(m.deleted ? 'This message was deleted' : m.text,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: m.deleted ? FontStyle.italic : FontStyle.normal,
                                        color: m.deleted ? C.muted : (isMe ? Colors.white : C.txt)))),
                          ),
                          Padding(padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                  '${m.time.hour.toString().padLeft(2, '0')}:'
                                      '${m.time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 9, color: C.muted))),
                        ],
                      )),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
        decoration: const BoxDecoration(
            color: C.surf, border: Border(top: BorderSide(color: C.bdr))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: ctrl,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                      hintText: 'Message ${club.name}…',
                      filled: true, fillColor: C.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: C.bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: C.bdr)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)))),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onSend();
              },
              child: Container(
                  width: 42, height: 42,
                  decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 18)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, ClubMessage m) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will replace it with "This message was deleted" for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ClubRepository.instance.deleteMessage(club.id, m.id, user.id);
    }
  }
}

/// The club's Feed — real posts (clubs/{id}/posts), replacing the old
/// static "no announcements yet" placeholder. Admins/moderators can flag
/// a post as an Announcement (pinned styling, matches the mockup's
/// "Physics Competition — Registration Open!" card); regular members can
/// post too.
class _FeedTab extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _FeedTab({required this.club, required this.user});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<ClubPost>>(
        stream: ClubRepository.instance.watchPosts(widget.club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final posts = snap.data ?? const <ClubPost>[];
          if (posts.isEmpty) {
            return const EmptyState(icon: Icons.campaign_outlined, title: 'No posts yet',
                subtitle: 'Be the first to post something for this club.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PostCard(club: widget.club, user: widget.user, post: posts[i]),
          );
        },
      ),
      floatingActionButton: widget.user.isGuest ? null : FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => _composePost(context),
        child: const Icon(Icons.edit_rounded, color: C.gold, size: 20),
      ),
    );
  }

  void _composePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ComposePostSheet(club: widget.club, user: widget.user),
    );
  }
}

class _ComposePostSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _ComposePostSheet({required this.club, required this.user});

  @override
  State<_ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends State<_ComposePostSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _announcement = false;
  bool _posting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showToast(context, 'Add a title and some text first.');
      return;
    }
    setState(() => _posting = true);
    final result = await ClubRepository.instance.createPost(widget.club.id, ClubPost(
      id: '', clubId: widget.club.id, authorId: widget.user.id, authorName: widget.user.name,
      authorPhotoUrl: widget.user.photoUrl, isAnnouncement: _announcement,
      title: title, body: body, createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _posting = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.user.id),
      builder: (context, roleSnap) {
        final canAnnounce = roleSnap.data == ClubRole.admin || roleSnap.data == ClubRole.moderator;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New Post', style: AppText.title.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: _titleCtrl,
                  decoration: const InputDecoration(hintText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _bodyCtrl, minLines: 3, maxLines: 6,
                  decoration: const InputDecoration(hintText: "What's on your mind?", border: OutlineInputBorder())),
              if (canAnnounce)
                CheckboxListTile(
                  value: _announcement, onChanged: (v) => setState(() => _announcement = v ?? false),
                  title: const Text('Post as Announcement'), contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _posting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _posting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Post'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final Club club;
  final AppUser user;
  final ClubPost post;
  const _PostCard({required this.club, required this.user, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(initials: post.authorName.isEmpty ? '?' : post.authorName[0].toUpperCase(),
              radius: 16, photoUrl: post.authorPhotoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.authorName, style: AppText.title.copyWith(fontSize: 13)),
              Text(_relativeTime(post.createdAt), style: AppText.caption.copyWith(fontSize: 10.5)),
            ]),
          ),
          if (post.isAnnouncement)
            const StatusBadge(label: 'ANNOUNCEMENT', color: C.gold),
        ]),
        const SizedBox(height: 10),
        Text(post.title, style: AppText.title.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(post.body, style: AppText.bodySm.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          _LikeChip(club: club, post: post, user: user),
          const SizedBox(width: 16),
          const Icon(Icons.mode_comment_outlined, size: 16, color: C.muted),
          const SizedBox(width: 4),
          Text('${post.commentCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
        ]),
      ]),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _LikeChip extends StatelessWidget {
  final Club club;
  final ClubPost post;
  final AppUser user;
  const _LikeChip({required this.club, required this.post, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isGuest) {
      return Row(children: [
        const Icon(Icons.favorite_border_rounded, size: 16, color: C.muted),
        const SizedBox(width: 4),
        Text('${post.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
      ]);
    }
    return StreamBuilder<bool>(
      stream: ClubRepository.instance.watchIsPostLiked(club.id, post.id, user.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: () {
              HapticFeedback.lightImpact();
              ClubRepository.instance.togglePostLike(club.id, post.id, user.id);
            },
            child: Row(children: [
              Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 16, color: liked ? C.red : C.muted),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: AppText.caption.copyWith(fontSize: 11.5)),
            ]),
          ),
        );
      },
    );
  }
}

/// The club's Discussions tab — Q&A threads with a mark-able best answer
/// and XP rewards. Matches the Physics Society mockup's second screen.
class _DiscussionsTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _DiscussionsTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<ClubDiscussion>>(
        stream: ClubRepository.instance.watchDiscussions(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 400));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final discussions = snap.data ?? const <ClubDiscussion>[];
          if (discussions.isEmpty) {
            return const EmptyState(icon: Icons.forum_outlined, title: 'No discussions yet',
                subtitle: 'Ask a question and earn XP when your answer helps someone.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: discussions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = discussions[i];
              return _DiscussionCard(
                discussion: d,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDiscussionDetailPage(club: club, user: user, discussion: d))),
              );
            },
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton.extended(
        backgroundColor: C.navy,
        icon: const Icon(Icons.add_rounded, color: C.gold),
        label: Text('Ask', style: AppText.button.copyWith(fontSize: 13)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AskQuestionPage(club: club, user: user))),
      ),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  final ClubDiscussion discussion;
  final VoidCallback onOpen;
  const _DiscussionCard({required this.discussion, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(initials: discussion.authorName.isEmpty ? '?' : discussion.authorName[0].toUpperCase(),
                  radius: 14, photoUrl: discussion.authorPhotoUrl),
              const SizedBox(width: 8),
              Expanded(child: Text(discussion.authorName, style: AppText.bodySm.copyWith(fontSize: 12))),
              if (discussion.bestAnswerReplyId != null)
                const Icon(Icons.check_circle_rounded, color: C.grn, size: 16),
            ]),
            const SizedBox(height: 8),
            Text(discussion.title, style: AppText.title.copyWith(fontSize: 14.5)),
            if ((discussion.tag ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              StatusBadge(label: discussion.tag!, color: C.pur),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.mode_comment_outlined, size: 14, color: C.muted),
              const SizedBox(width: 4),
              Text('${discussion.replyCount}', style: AppText.caption.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              const Icon(Icons.visibility_outlined, size: 14, color: C.muted),
              const SizedBox(width: 4),
              Text('${discussion.viewCount}', style: AppText.caption.copyWith(fontSize: 11)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Shared links/files — matches the mockup's RESOURCES tab. Any signed-in
/// member can add one; the uploader or club staff can remove it.
class _ResourcesTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _ResourcesTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<ClubResource>>(
        stream: ClubRepository.instance.watchResources(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 300));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final resources = snap.data ?? const <ClubResource>[];
          if (resources.isEmpty) {
            return const EmptyState(icon: Icons.folder_open_outlined, title: 'No resources yet',
                subtitle: 'Share a link or file useful to the whole club.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = resources[i];
              final canRemove = r.uploaderId == user.id;
              return ACard(
                onTap: () {
                  final uri = Uri.tryParse(r.url);
                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(r.isFile ? Icons.insert_drive_file_outlined : Icons.link_rounded, color: C.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, style: AppText.title.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Shared by ${r.uploaderName}', style: AppText.caption.copyWith(fontSize: 11)),
                    ]),
                  ),
                  if (canRemove)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: C.muted),
                      onPressed: () => ClubRepository.instance.deleteResource(club.id, r.id),
                    ),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddResourceSheet(club: club, user: user),
        ),
        child: const Icon(Icons.add_rounded, color: C.gold),
      ),
    );
  }
}

class _AddResourceSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _AddResourceSheet({required this.club, required this.user});

  @override
  State<_AddResourceSheet> createState() => _AddResourceSheetState();
}

class _AddResourceSheetState extends State<_AddResourceSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (title.isEmpty || url.isEmpty) {
      showToast(context, 'Add a title and a link.');
      return;
    }
    setState(() => _saving = true);
    final result = await ClubRepository.instance.addResource(widget.club.id, ClubResource(
      id: '', clubId: widget.club.id, title: title, url: url,
      uploaderId: widget.user.id, uploaderName: widget.user.name, uploaderPhotoUrl: widget.user.photoUrl,
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share a Resource', style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(hintText: 'Link (https://…)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Share'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Upcoming club events with lightweight RSVP — matches the mockup's
/// EVENTS tab.
class _EventsTab extends StatelessWidget {
  final Club club;
  final AppUser user;
  const _EventsTab({required this.club, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: StreamBuilder<List<ClubEvent>>(
        stream: ClubRepository.instance.watchEvents(club.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: ShimmerBlock(height: 300));
          }
          if (snap.hasError) return ErrorView(message: snap.error.toString());
          final events = (snap.data ?? const <ClubEvent>[])
              .where((e) => e.startAt.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
          if (events.isEmpty) {
            return const EmptyState(icon: Icons.event_outlined, title: 'No upcoming events',
                subtitle: 'Plan something for the club to look forward to.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _EventCard(club: club, event: events[i], user: user),
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton(
        backgroundColor: C.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddEventSheet(club: club, user: user),
        ),
        child: const Icon(Icons.add_rounded, color: C.gold),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Club club;
  final ClubEvent event;
  final AppUser user;
  const _EventCard({required this.club, required this.event, required this.user});

  String _fmt(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day} · $h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title, style: AppText.title.copyWith(fontSize: 14.5)),
        const SizedBox(height: 4),
        Text(_fmt(event.startAt), style: AppText.bodySm.copyWith(fontSize: 12, color: C.primary)),
        if ((event.location ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.place_outlined, size: 13, color: C.muted),
            const SizedBox(width: 3),
            Text(event.location!, style: AppText.caption.copyWith(fontSize: 11)),
          ]),
        ],
        if ((event.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(event.description!, style: AppText.bodySm.copyWith(fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Text('${event.rsvpCount} going', style: AppText.caption.copyWith(fontSize: 11)),
          const Spacer(),
          if (!user.isGuest)
            StreamBuilder<bool>(
              stream: ClubRepository.instance.watchIsGoingToEvent(club.id, event.id, user.id),
              builder: (context, snap) {
                final going = snap.data ?? false;
                return OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ClubRepository.instance.toggleEventRsvp(club.id, event.id, user.id, !going);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: going ? C.grnb : null,
                    side: BorderSide(color: going ? C.grn : C.bdr),
                  ),
                  child: Text(going ? 'Going ✓' : 'RSVP', style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: going ? C.grn : C.txt2)),
                );
              },
            ),
        ]),
      ]),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final Club club;
  final AppUser user;
  const _AddEventSheet({required this.club, required this.user});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Give the event a title.');
      return;
    }
    setState(() => _saving = true);
    final startAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final result = await ClubRepository.instance.addEvent(widget.club.id, ClubEvent(
      id: '', clubId: widget.club.id, title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      startAt: startAt, location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      creatorId: widget.user.id, creatorName: widget.user.name,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      Navigator.pop(context);
    } else {
      showToast(context, (result as Failure).message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Event', style: AppText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Event title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                      context: context, initialDate: _date,
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _date = picked);
                },
                child: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: Text(_time.format(context)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _locationCtrl, decoration: const InputDecoration(hintText: 'Location (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descCtrl, minLines: 2, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Description (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: C.navy, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Event'),
            ),
          ),
        ]),
      ),
    );
  }
}
