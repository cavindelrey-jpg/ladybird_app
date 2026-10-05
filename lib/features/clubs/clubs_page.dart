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
import '../../theme/app_colors.dart';
import '../../theme/club_visuals.dart';
import '../../config/branding.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../pages/notifications_page.dart';
import '../messages/messages_home_page.dart';
import '../../core/club_scope.dart';
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

  late Stream<List<Club>> _clubsStream;
  late Stream<List<String>> _myClubIdsStream;
  late Stream<List<String>> _myPendingIdsStream;

  bool get _canCreate => !widget.user.isGuest;

  @override
  void initState() {
    super.initState();
    _clubsStream = ClubRepository.instance.watchClubs(user: widget.user);
    _myClubIdsStream = ClubRepository.instance.watchMyClubIds(widget.user.id);
    _myPendingIdsStream = ClubRepository.instance.watchMyPendingRequestClubIds(widget.user.id);
    _searchCtrl.addListener(() {
      final text = _searchCtrl.text.trim();
      if (_searchQuery != text) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void didUpdateWidget(ClubsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.schoolId != widget.user.schoolId ||
        oldWidget.user.id != widget.user.id ||
        oldWidget.user.role != widget.user.role) {
      setState(() {
        _clubsStream = ClubRepository.instance.watchClubs(user: widget.user);
        _myClubIdsStream = ClubRepository.instance.watchMyClubIds(widget.user.id);
        _myPendingIdsStream = ClubRepository.instance.watchMyPendingRequestClubIds(widget.user.id);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return StreamBuilder<List<Club>>(
      stream: _clubsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
            backgroundColor: ac.bg,
            appBar: AppBar(
              backgroundColor: ac.bg,
              elevation: 0,
              title: Text('Academic Groups', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.bold, color: ac.navy)),
              iconTheme: IconThemeData(color: ac.navy),
            ),
            body: const _ClubsSkeleton(),
          );
        }
        if (snap.hasError && (!snap.hasData || snap.data!.isEmpty)) {
          return Scaffold(
            backgroundColor: ac.bg,
            appBar: AppBar(
              backgroundColor: ac.bg,
              elevation: 0,
              title: Text('Academic Groups', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.bold, color: ac.navy)),
              iconTheme: IconThemeData(color: ac.navy),
            ),
            body: Center(child: ErrorView(message: snap.error.toString())),
          );
        }

        final rawClubs = snap.data ?? const <Club>[];
        final allClubs = rawClubs.where((c) => ClubScope.canAccessClub(c, user: widget.user)).toList();
        var filtered = _searchQuery.isEmpty
            ? allClubs
            : allClubs.where((c) =>
                c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        if (_selectedCategory != null) {
          filtered = filtered.where((c) => c.category == _selectedCategory).toList();
        }
        final categories = allClubs.map((c) => c.category).toSet().toList()..sort();

        return StreamBuilder<List<String>>(
          stream: _myClubIdsStream,
          builder: (context, joinedSnap) {
            final joinedIds = (joinedSnap.data ?? const <String>[]).toSet();
            return StreamBuilder<List<String>>(
              stream: _myPendingIdsStream,
              builder: (context, pendingSnap) {
                final pendingIds = (pendingSnap.data ?? const <String>[]).toSet();

                final myClubs = filtered.where((c) => joinedIds.contains(c.id) || pendingIds.contains(c.id)).toList();
                final discoverClubs = filtered.where((c) => !c.isClassGroup && !joinedIds.contains(c.id) && !pendingIds.contains(c.id)).toList();

                final candidates = widget.user.favoriteSubjects.isEmpty
                    ? const <Club>[]
                    : RecommendationRepository.instance.forClubs(pool: allClubs, favoriteSubjects: widget.user.favoriteSubjects, user: widget.user);
                final recommendedClubs = candidates.where((c) => !c.isClassGroup && !joinedIds.contains(c.id) && !pendingIds.contains(c.id)).toList();

                return Scaffold(
                  backgroundColor: ac.bg,
                  appBar: AppBar(
                    backgroundColor: ac.bg,
                    elevation: 0,
                    title: Text(
                      'Academic Groups',
                      style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.bold, color: ac.navy),
                    ),
                    iconTheme: IconThemeData(color: ac.navy),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined, color: ac.txt2),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => NotificationsPage(user: widget.user))),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: UserAvatar(
                            initials: widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
                            radius: 17,
                            photoUrl: widget.user.photoUrl,
                          ),
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(categories.length > 1 ? 104 : 58),
                      child: Column(
                        children: [
                          _searchBar(ac),
                          if (categories.length > 1) ...[
                            const SizedBox(height: 8),
                            _categoryChips(categories, ac),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  body: AppBackground(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 12, bottom: 100),
                      children: [
                        if (_searchQuery.isEmpty && _selectedCategory == null && recommendedClubs.isNotEmpty) ...[
                          _recommendedClubsSection(context, recommendedClubs),
                        ],
                        _myClubsSection(context, myClubs, joinedIds),
                        const SizedBox(height: 24),
                        _discoverClubsSection(context, discoverClubs, allClubs),
                        const SizedBox(height: 20),
                        _infoCards(context),
                      ],
                    ),
                  ),
                  floatingActionButton: _canCreate
                      ? FloatingActionButton.extended(
                          backgroundColor: ac.navy,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CreateClubPage(user: widget.user)));
                          },
                          icon: Icon(Icons.add_rounded, color: ac.gold),
                          label: Text('Create Group', style: AppText.button.copyWith(fontSize: 13)),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _searchBar(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _searchCtrl,
        style: AppText.bodySm.copyWith(color: ac.txt),
        decoration: InputDecoration(
          hintText: 'Search groups by name, interest or subject…',
          hintStyle: AppText.bodySm.copyWith(color: ac.muted, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: ac.muted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          filled: true,
          fillColor: ac.surf,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.bdr),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.bdr),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        ),
      ),
    );
  }

  Widget _categoryChips(List<String> categories, AppColors ac) {
    final chips = ['All Groups', ...categories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = chips[i];
          final isAll = label == 'All Groups';
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
                  color: active ? ac.navy : ac.surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ac.navy : ac.bdr),
                ),
                child: Text(
                  label,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? ac.gold : ac.txt2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _myClubsSection(BuildContext context, List<Club> myClubs, Set<String> joinedIds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('My Groups', style: AppText.h2.copyWith(fontSize: 16))),
        ]),
        const SizedBox(height: 12),
        if (myClubs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No groups yet — discover one below or create your own.', style: AppText.bodySm),
          )
        else
          SizedBox(
            height: 245,
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
          ),
      ]),
    );
  }

  Widget _recommendedClubsSection(BuildContext context, List<Club> recommended) {
    if (recommended.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recommended for You', style: AppText.h2.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        SizedBox(
          height: 275,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommended.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _DiscoverClubCard(
              club: recommended[i],
              user: widget.user,
              isMember: false,
              isPending: false,
              onOpen: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ClubDetailPage(club: recommended[i], user: widget.user))),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _discoverClubsSection(BuildContext context, List<Club> discoverClubs, List<Club> unfilteredClubs) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Discover Groups', style: AppText.h2.copyWith(fontSize: 16))),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.xs),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AllClubsPage(clubs: unfilteredClubs, user: widget.user))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('See all', style: AppText.subtitle.copyWith(
                    color: ac.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (discoverClubs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No groups yet — be the first to create one.', style: AppText.bodySm),
          )
        else
          SizedBox(
            height: 275,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: discoverClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _DiscoverClubCard(
                club: discoverClubs[i],
                user: widget.user,
                isMember: false,
                isPending: false,
                onOpen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubDetailPage(club: discoverClubs[i], user: widget.user))),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _infoCards(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.groups_rounded, color: ac.blu, size: 20),
              const SizedBox(height: 8),
              Text('Groups', style: AppText.title.copyWith(fontSize: 13)),
              const SizedBox(height: 4),
              Text('Shared spaces around common interests. Join open groups or request to join those that require approval.',
                  style: AppText.caption.copyWith(fontSize: 10.5, height: 1.35)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.chat_bubble_rounded, color: ac.pur, size: 20),
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
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.pur)),
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
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const ShimmerLine(width: 120, height: 18),
        const SizedBox(height: 12),
        SizedBox(
          height: 245,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SizedBox(
              width: 200,
              child: ShimmerBlock(height: 245, borderRadius: Rad.md),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const ShimmerLine(width: 140, height: 18),
        const SizedBox(height: 12),
        SizedBox(
          height: 275,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => const SizedBox(
              width: 200,
              child: ShimmerBlock(height: 275, borderRadius: Rad.md),
            ),
          ),
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
    final ac = AppColors.of(context);
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
          decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
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
                    border: Border.all(color: ac.surf, width: 2.5),
                  ),
                  child: ClubLogo(club: club, size: 40, borderRadius: BorderRadius.circular(11)),
                ),
              ),
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pending ? ac.orgBg : ac.grnBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(pending ? 'Pending' : 'Joined ✓', style: AppText.label.copyWith(
                      fontSize: 9.5, color: pending ? ac.org : ac.grn, letterSpacing: 0)),
                ),
              ),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(club.name, style: AppText.title.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(club.description, style: AppText.caption.copyWith(fontSize: 10.5, height: 1.25),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    Row(children: [
                      _MemberAvatarStack(clubId: club.id),
                      const SizedBox(width: 6),
                      Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
                    ]),
                  ],
                ),
              ),
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
  final bool? isMember;
  final bool? isPending;
  const _DiscoverClubCard({
    required this.club,
    required this.user,
    required this.onOpen,
    this.fullWidth = false,
    this.isMember,
    this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    if (user.isGuest) return _card(context, joined: false, pending: false);

    // If caller pre-filtered membership and pending status, skip all per-card stream subscriptions!
    if (isMember != null && isPending != null) {
      if (isMember! || isPending!) return const SizedBox.shrink();
      return _card(context, joined: isMember!, pending: isPending!);
    }

    return StreamBuilder<ClubRole>(
      stream: ClubRepository.instance.watchUserRole(club.id, user.id),
      builder: (context, roleSnap) {
        final isJoined = (roleSnap.data ?? ClubRole.visitor) != ClubRole.visitor;
        if (isJoined) return const SizedBox.shrink();
        return StreamBuilder<ClubJoinRequestStatus?>(
          stream: ClubRepository.instance.watchMyRequestStatus(club.id, user.id),
          builder: (context, reqSnap) {
            if (reqSnap.hasError) {
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
    final ac = AppColors.of(context);
    final hasCover = (club.bannerUrl ?? '').isNotEmpty;
    final iconOption = ClubVisuals.fallbackIconFor(club);
    final accent = ClubVisuals.colorFor(club);
    Widget fallback() => Container(
          color: accent.withValues(alpha: .16),
          alignment: Alignment.center,
          child: Icon(iconOption.icon, color: accent, size: 26),
        );

    final cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: fullWidth ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                club.name,
                style: AppText.title.copyWith(fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(children: [
                Icon(club.requiresApproval ? Icons.lock_outline_rounded : Icons.public_rounded,
                    size: 12, color: club.requiresApproval ? ac.pur : ac.grn),
                const SizedBox(width: 4),
                Text(
                  club.requiresApproval ? 'Approval required' : 'Open to all',
                  style: AppText.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: club.requiresApproval ? ac.pur : ac.grn,
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Text(
                club.description,
                style: AppText.caption.copyWith(fontSize: 10.5, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (fullWidth) const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _MemberAvatarStack(clubId: club.id),
                const SizedBox(width: 6),
                Text('${club.memberCount} members', style: AppText.caption.copyWith(fontSize: 10.5)),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _handleJoin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    club.requiresApproval ? 'Request to Join' : 'Join Group',
                    style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onOpen();
        },
        child: Container(
          width: fullWidth ? double.infinity : 200,
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: ac.bdr),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 84,
                    width: double.infinity,
                    child: hasCover
                        ? Image.network(club.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback())
                        : fallback(),
                  ),
                  Positioned(
                    left: 10,
                    bottom: -14,
                    child: Container(
                      width: 36,
                      height: 36,
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ac.surf, width: 2.5),
                      ),
                      child: ClubLogo(club: club, size: 36, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              if (fullWidth)
                cardContent
              else
                Expanded(child: cardContent),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    if (user.isGuest) {
      showToast(context, 'Create an account to join groups');
      return;
    }
    if (!ClubScope.canAccessClub(club, user: user)) {
      showToast(context, 'This group belongs to another school.');
      return;
    }
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
        user: user,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(
        club.id, user.id, name: user.name, photoUrl: user.photoUrl,
        user: user,
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
        final ac = AppColors.of(context);
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
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ac.surf, width: 1.5)),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Discover Groups', style: AppText.title),
      ),
      body: AppBackground(child: clubs.isEmpty
          ? const EmptyState(icon: Icons.groups_outlined, title: 'No groups yet',
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
    final ac = AppColors.of(context);
    if (!ClubScope.canAccessClub(widget.club, user: widget.user)) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: ac.muted),
                const SizedBox(height: 16),
                Text(
                  'Access Restricted',
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold, color: ac.txt),
                ),
                const SizedBox(height: 8),
                Text(
                  'This academic group belongs to another school context and is not accessible.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: ac.txt2),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: ac.bg,
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
            color: ac.surf,
            child: TabBar(
              controller: _tabs, isScrollable: true,
              labelColor: ac.navy, unselectedLabelColor: ac.muted,
              indicatorColor: ac.gold, indicatorWeight: 2.5,
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
    final ac = AppColors.of(context);
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
              tooltip: 'Group chat',
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
              border: Border.all(color: ac.surf, width: 4),
            ),
            child: ClubLogo(club: club, size: 84),
          ),
        ),
      ]),
      const SizedBox(height: 44),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      club.name,
                      style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: ac.txt),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'School-verified group',
                      child: Icon(Icons.verified_rounded, color: ac.blu, size: 18),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
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
                return Text(' • $online online', style: AppText.bodySm.copyWith(fontSize: 12.5, color: ac.grn, fontWeight: FontWeight.w700));
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
    final ac = AppColors.of(context);
    
    if (!_isMember) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: () => _handleJoin(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: ac.navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(club.requiresApproval ? 'Request to Join' : 'Join Group',
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
          decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Joined', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.grn)),
            const SizedBox(width: 3),
            Icon(Icons.expand_more_rounded, size: 15, color: ac.grn),
          ]),
        ),
      ),
    );
  }

  Future<void> _handleJoin(BuildContext context) async {
    if (!ClubScope.canAccessClub(club, user: user)) {
      showToast(context, 'This group belongs to another school.');
      return;
    }
    HapticFeedback.mediumImpact();
    if (club.requiresApproval) {
      final result = await ClubRepository.instance.requestToJoin(
        clubId: club.id, clubName: club.name,
        userId: user.id, userName: user.name, userPhotoUrl: user.photoUrl,
        user: user,
      );
      if (context.mounted) {
        showToast(context, result is Success ? 'Request sent — pending admin approval.' : (result as Failure).message);
      }
    } else {
      final result = await ClubRepository.instance.joinClub(club.id, user.id, name: user.name, photoUrl: user.photoUrl, user: user);
      if (context.mounted) {
        showToast(context, result is Success ? '✅ Welcome to ${club.name}!' : 'Failed to join');
      }
    }
  }

  void _showJoinedMenu(BuildContext context) {
    final ac = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isAdmin)
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Group Settings'),
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
              Share.share('Join "${club.name}"!\n\n${club.description}\n\n'
                  'Open the ${Branding.current.appName} app, go to Groups, and search for it to join.');
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: ac.red),
            title: Text('Leave Group', style: TextStyle(color: ac.red)),
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
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this group?'),
        content: Text('You can rejoin "${club.name}" any time${club.requiresApproval ? ", but you'll need approval again." : "."}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Leave', style: TextStyle(color: ac.red))),
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
        final ac = AppColors.of(context);
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
              Text('Admins', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.txt2)),
              const SizedBox(width: 10),
              SizedBox(
                width: 20.0 + (shown.length - 1) * 16.0,
                height: 26,
                child: Stack(children: [
                  for (int i = 0; i < shown.length; i++)
                    Positioned(
                      left: i * 16.0,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ac.surf, width: 2)),
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
                Text('+$extra', style: AppText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: ac.txt2)),
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
    final res = await ClubRepository.instance.sendMessage(widget.club.id, msg, user: widget.user);
    if (!mounted) return;
    if (res is Failure<void>) {
      // Never silently drop what someone typed: put it back and say why.
      if (_ctrl.text.isEmpty) _ctrl.text = text;
      showToast(context, res.message, isError: true);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 80));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!ClubScope.canAccessClub(widget.club, user: widget.user)) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(backgroundColor: ac.bg, elevation: 0),
        body: const Center(child: Text('Access restricted to members of this institution.')),
      );
    }
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('${widget.club.name} · Chat', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
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
    final ac = AppColors.of(context);
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
                                color: ac.goldBg, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(m.senderInitials,
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700, color: ac.gold)))),
                      Flexible(child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(padding: const EdgeInsets.only(left: 2, bottom: 2),
                                child: Text(m.senderName,
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w600, color: ac.muted))),
                          GestureDetector(
                            onLongPress: (isMe && !m.deleted) ? () => _confirmDelete(context, m) : null,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * .65),
                                decoration: BoxDecoration(
                                  color: m.deleted ? ac.surf3 : (isMe ? ac.primary : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: (isMe && !m.deleted) ? null : Border.all(color: ac.bdr),
                                ),
                                child: Text(m.deleted ? 'This message was deleted' : m.text,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: m.deleted ? FontStyle.italic : FontStyle.normal,
                                        color: m.deleted ? ac.muted : (isMe ? Colors.white : ac.txt)))),
                          ),
                          Padding(padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                  '${m.time.hour.toString().padLeft(2, '0')}:'
                                      '${m.time.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 9, color: ac.muted))),
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
        decoration: BoxDecoration(
            color: ac.surf, border: Border(top: BorderSide(color: ac.bdr))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: ctrl,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                      hintText: 'Message ${club.name}…',
                      filled: true, fillColor: ac.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: ac.bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: ac.bdr)),
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
                  decoration: BoxDecoration(color: ac.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 18)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context, ClubMessage m) async {
    final ac = AppColors.of(context);
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
            child: Text('Delete', style: TextStyle(color: ac.red)),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                subtitle: 'Be the first to post something for this group.');
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
        backgroundColor: ac.navy,
        onPressed: () => _composePost(context),
        child: Icon(Icons.edit_rounded, color: ac.gold, size: 20),
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
        final ac = AppColors.of(context);
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
                  style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white,
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
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
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
            StatusBadge(label: 'ANNOUNCEMENT', color: ac.gold),
        ]),
        const SizedBox(height: 10),
        Text(post.title, style: AppText.title.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(post.body, style: AppText.bodySm.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          _LikeChip(club: club, post: post, user: user),
          const SizedBox(width: 16),
          Icon(Icons.mode_comment_outlined, size: 16, color: ac.muted),
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
    final ac = AppColors.of(context);
    if (user.isGuest) {
      return Row(children: [
        Icon(Icons.favorite_border_rounded, size: 16, color: ac.muted),
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
                  size: 16, color: liked ? ac.red : ac.muted),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
        backgroundColor: ac.navy,
        icon: Icon(Icons.add_rounded, color: ac.gold),
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
    final ac = AppColors.of(context);
    return Material(
      color: ac.surf,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(initials: discussion.authorName.isEmpty ? '?' : discussion.authorName[0].toUpperCase(),
                  radius: 14, photoUrl: discussion.authorPhotoUrl),
              const SizedBox(width: 8),
              Expanded(child: Text(discussion.authorName, style: AppText.bodySm.copyWith(fontSize: 12))),
              if (discussion.bestAnswerReplyId != null)
                Icon(Icons.check_circle_rounded, color: ac.grn, size: 16),
            ]),
            const SizedBox(height: 8),
            Text(discussion.title, style: AppText.title.copyWith(fontSize: 14.5)),
            if ((discussion.tag ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              StatusBadge(label: discussion.tag!, color: ac.pur),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.mode_comment_outlined, size: 14, color: ac.muted),
              const SizedBox(width: 4),
              Text('${discussion.replyCount}', style: AppText.caption.copyWith(fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.visibility_outlined, size: 14, color: ac.muted),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                subtitle: 'Share a link or file useful to the whole group.');
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
                    decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(r.isFile ? Icons.insert_drive_file_outlined : Icons.link_rounded, color: ac.primary, size: 18),
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
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: ac.muted),
                      onPressed: () => ClubRepository.instance.deleteResource(club.id, r.id),
                    ),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: user.isGuest ? null : FloatingActionButton(
        backgroundColor: ac.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddResourceSheet(club: club, user: user),
        ),
        child: Icon(Icons.add_rounded, color: ac.gold),
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
    ), user: widget.user);
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
    final ac = AppColors.of(context);
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
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
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
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
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
                subtitle: 'Plan something for the group to look forward to.');
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
        backgroundColor: ac.navy,
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _AddEventSheet(club: club, user: user),
        ),
        child: Icon(Icons.add_rounded, color: ac.gold),
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
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title, style: AppText.title.copyWith(fontSize: 14.5)),
        const SizedBox(height: 4),
        Text(_fmt(event.startAt), style: AppText.bodySm.copyWith(fontSize: 12, color: ac.primary)),
        if ((event.location ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.place_outlined, size: 13, color: ac.muted),
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
                    backgroundColor: going ? ac.grnBg : null,
                    side: BorderSide(color: going ? ac.grn : ac.bdr),
                  ),
                  child: Text(going ? 'Going ✓' : 'RSVP', style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: going ? ac.grn : ac.txt2)),
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
    ), user: widget.user);
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
    final ac = AppColors.of(context);
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
              style: ElevatedButton.styleFrom(backgroundColor: ac.navy, foregroundColor: Colors.white),
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
