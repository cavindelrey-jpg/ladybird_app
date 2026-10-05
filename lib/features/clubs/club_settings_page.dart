// lib/features/clubs/club_settings_page.dart
// Admin-only club settings: edit name/description/category/logo/banner/
// approval-gating, plus delete the club. The create flow already covered
// "make a club"; this was the missing "manage an existing one" half.
//
// ── Clubs remake changes ────────────────────────────────────────────────
// - The emoji picker grid is gone entirely. A club's real logo is now
//   Club.thumbnailUrl — an actual photo the admin uploads here, separate
//   from the existing wide banner. `_emoji` is kept only as the
//   invisible fallback icon key shown until a thumbnail exists (see
//   theme/club_visuals.dart's ClubLogo), auto-derived from category
//   rather than picked by anyone.
// - This page previously had ZERO role gating of its own — it relied
//   entirely on its one entry point (the detail page's gear icon, itself
//   admin-gated) to keep non-admins out. It's now gated here too
//   (defense in depth, matching how club_repository.dart's member
//   management already documents "enforced both here and in
//   firestore.rules" as the pattern this codebase uses elsewhere) — a
//   non-admin who somehow reaches this route sees a clear "you don't
//   have permission" view instead of a form that would fail silently or
//   confusingly on save.
// - Added a "Your Role" section up top with live member/moderator/admin
//   counts and a link into ClubMembersPage. Role management (promote,
//   demote, remove) already fully existed in ClubMembersPage/
//   ClubRepository — this settings screen just never surfaced that it
//   existed or linked to it, so an admin editing their club's settings
//   had no idea member roles were even manageable unless they separately
//   discovered the Members tab.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../theme/club_visuals.dart';
import '../../core/club_scope.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'club_members_page.dart';

const _kClubCategories = [
  'General', 'Academic', 'Debate', 'Sports', 'Arts',
  'Tech', 'Language', 'Volunteering',
];

class ClubSettingsPage extends StatefulWidget {
  final Club club;
  final AppUser currentUser;
  const ClubSettingsPage({super.key, required this.club, required this.currentUser});

  @override
  State<ClubSettingsPage> createState() => _ClubSettingsPageState();
}

class _ClubSettingsPageState extends State<ClubSettingsPage> {
  late final _nameCtrl = TextEditingController(text: widget.club.name);
  late final _descCtrl = TextEditingController(text: widget.club.description);
  late String _emoji = widget.club.emoji;
  late String _category = widget.club.category;
  late bool _requiresApproval = widget.club.requiresApproval;
  File? _newBannerFile;
  File? _newThumbnailFile;
  bool _saving = false;
  bool _deleting = false;

  bool get _isFounder => widget.club.moderatorId == widget.currentUser.id;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _newBannerFile = File(picked.path));
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _newThumbnailFile = File(picked.path));
  }

  void _onCategoryChanged(String? v) {
    if (v == null) return;
    // Only nudges the invisible fallback forward if the club is still on
    // its OLD category's default icon — if an admin's club already has a
    // custom fallback for some other reason, changing category shouldn't
    // silently overwrite it.
    final oldDefault = ClubVisuals.categoryDefaultKey[_category];
    setState(() {
      if (_emoji == oldDefault) {
        _emoji = ClubVisuals.categoryDefaultKey[v] ?? _emoji;
      }
      _category = v;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Group name is required');
      return;
    }
    setState(() => _saving = true);
    final repo = ClubRepository.instance;
    var bannerUrl = widget.club.bannerUrl;
    if (_newBannerFile != null) {
      final upload = await repo.uploadBanner(clubId: widget.club.id, imageFile: _newBannerFile!);
      if (upload is Success<String>) bannerUrl = upload.value;
    }
    var thumbnailUrl = widget.club.thumbnailUrl;
    if (_newThumbnailFile != null) {
      final upload = await repo.uploadThumbnail(clubId: widget.club.id, imageFile: _newThumbnailFile!);
      if (upload is Success<String>) thumbnailUrl = upload.value;
    }
    final result = await repo.updateClub(Club(
      id: widget.club.id,
      name: _nameCtrl.text.trim(),
      emoji: _emoji,
      description: _descCtrl.text.trim(),
      moderatorName: widget.club.moderatorName,
      moderatorId: widget.club.moderatorId,
      category: _category,
      bannerUrl: bannerUrl,
      thumbnailUrl: thumbnailUrl,
      memberCount: widget.club.memberCount,
      schoolId: widget.club.schoolId,
      requiresApproval: _requiresApproval,
    ), user: widget.currentUser);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      showToast(context, 'Group settings saved.');
      Navigator.of(context).pop(true);
    } else {
      showToast(context, (result as Failure).message);
    }
  }

  Future<void> _confirmDelete() async {
    final ac = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this group?'),
        content: Text('"${widget.club.name}" and its chat history will be permanently deleted. '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: ac.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final result = await ClubRepository.instance.deleteClub(widget.club.id, user: widget.currentUser);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (result is Success) {
      // Pop settings AND the club detail page underneath it -- the club
      // no longer exists, nothing left to show there.
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/clubs');
      showToast(context, 'Group deleted.');
    } else {
      showToast(context, (result as Failure).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (!ClubScope.canAccessClub(widget.club, user: widget.currentUser)) {
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
        title: Text('Group Settings', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      // Defense-in-depth role gate — see file header. The detail page's
      // gear icon already only shows for admins, but this page shouldn't
      // rely solely on that being the only way in.
      body: AppBackground(child: StreamBuilder<ClubRole>(
        stream: ClubRepository.instance.watchUserRole(widget.club.id, widget.currentUser.id),
        builder: (context, roleSnap) {
          if (roleSnap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final role = roleSnap.data ?? ClubRole.visitor;
          if (role != ClubRole.admin) {
            return EmptyState(
              icon: Icons.lock_outline_rounded,
              title: "You don't have permission",
              subtitle: role == ClubRole.moderator
                  ? 'Only admins can change group settings. Ask an admin, or manage members from the Members tab.'
                  : 'Only this group\'s admins can access its settings.',
            );
          }
          return _settingsForm(context, role);
        },
      )),
    );
  }

  Widget _settingsForm(BuildContext context, ClubRole role) {
    final ac = AppColors.of(context);
    return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _roleAndMembersCard(context, role),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: () { HapticFeedback.selectionClick(); _pickBanner(); },
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(
                  color: ac.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _newBannerFile != null
                      ? DecorationImage(image: FileImage(_newBannerFile!), fit: BoxFit.cover)
                      : (widget.club.bannerUrl != null && widget.club.bannerUrl!.isNotEmpty)
                          ? DecorationImage(image: NetworkImage(widget.club.bannerUrl!), fit: BoxFit.cover)
                          : null,
                ),
                child: (_newBannerFile == null && (widget.club.bannerUrl ?? '').isEmpty)
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white70, size: 28))
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Banner — the wide cover photo on your group page', style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
          ),
          const SizedBox(height: 20),
          // The club's real logo — an actual picture, not a pick-from-a-
          // set icon. Until one's uploaded, a category-based icon fills
          // in automatically wherever this club's badge is shown (see
          // ClubLogo).
          Center(
            child: Column(children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () { HapticFeedback.selectionClick(); _pickThumbnail(); },
                  child: Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      color: ac.surf3, shape: BoxShape.circle,
                      border: Border.all(color: ac.bdr),
                      image: _newThumbnailFile != null
                          ? DecorationImage(image: FileImage(_newThumbnailFile!), fit: BoxFit.cover)
                          : (widget.club.thumbnailUrl != null && widget.club.thumbnailUrl!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(widget.club.thumbnailUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (_newThumbnailFile == null && (widget.club.thumbnailUrl ?? '').isEmpty)
                        ? Icon(Icons.add_a_photo_outlined, color: ac.muted, size: 26)
                        : Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 14),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Group logo', style: GoogleFonts.inter(fontSize: 11.5, color: ac.muted)),
            ]),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameCtrl,
            style: GoogleFonts.inter(fontSize: 14, color: ac.txt),
            decoration: InputDecoration(
              labelText: 'Group Name',
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14, color: ac.txt),
            decoration: InputDecoration(
              labelText: 'Description',
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            items: _kClubCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: _onCategoryChanged,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Require approval to join', style: GoogleFonts.inter(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
              value: _requiresApproval,
              activeThumbColor: ac.gold,
              onChanged: (v) => setState(() => _requiresApproval = v),
            ),
          ),
          const SizedBox(height: 28),
          PrimaryBtn(label: 'Save Changes', onTap: _save, loading: _saving),
          if (_isFounder) ...[
            const SizedBox(height: 28),
            Divider(color: ac.bdr2),
            const SizedBox(height: 12),
            Text('Danger Zone', style: GoogleFonts.sora(
                fontSize: 13, fontWeight: FontWeight.w800, color: ac.red)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                    foregroundColor: ac.red, side: BorderSide(color: ac.red)),
                icon: _deleting
                    ? SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ac.red))
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(_deleting ? 'Deleting…' : 'Delete Group'),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      );
  }

  /// The literal ask this section exists for: an admin editing club
  /// settings previously had no visibility into member roles at all
  /// unless they separately discovered the Members tab. Role
  /// promotion/demotion/removal already fully worked in
  /// ClubMembersPage/ClubRepository — this is just the missing surface
  /// pointing at it.
  Widget _roleAndMembersCard(BuildContext context, ClubRole myRole) {
    return StreamBuilder<List<ClubMember>>(
      stream: ClubRepository.instance.watchMembers(widget.club.id),
      builder: (context, snap) {
        final ac = AppColors.of(context);
        final members = snap.data ?? const <ClubMember>[];
        final adminCount = members.where((m) => m.role == ClubRole.admin).length;
        final modCount = members.where((m) => m.role == ClubRole.moderator).length;
        final memberCount = members.where((m) => m.role == ClubRole.member).length;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shield_outlined, size: 16, color: ac.primary),
              const SizedBox(width: 6),
              Text('Your role: ', style: GoogleFonts.inter(fontSize: 12.5, color: ac.primary)),
              Text(myRole == ClubRole.admin ? 'Admin' : myRole == ClubRole.moderator ? 'Moderator' : 'Member',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: ac.primary)),
            ]),
            const SizedBox(height: 8),
            Text('$adminCount admin${adminCount == 1 ? '' : 's'} · $modCount moderator${modCount == 1 ? '' : 's'} · $memberCount member${memberCount == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 11.5, color: ac.primary)),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.sm),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClubMembersPage(club: widget.club, currentUser: widget.currentUser))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Manage Members & Roles', style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.primary,
                      decoration: TextDecoration.underline)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: ac.primary),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
