// lib/features/clubs/create_club_page.dart
// Any signed-in (non-guest) user can create a club — the founder becomes
// its admin automatically (ClubRepository.createClub already sets this up).
// This screen was the missing piece: the backend supported it, there was
// just no UI to reach it.
//
// ── Clubs remake change ─────────────────────────────────────────────────
// The emoji picker grid is gone. A club's real logo is now
// Club.thumbnailUrl — an actual photo the founder picks here (separate
// from the wide banner, which already existed). `_emoji` is kept
// internally only as the invisible fallback icon key (see
// theme/club_visuals.dart's ClubLogo) shown until a thumbnail is
// uploaded, auto-derived from category rather than picked by anyone.

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
import '../../config/branding.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'clubs_page.dart';

const _kClubCategories = [
  'General', 'Academic', 'Debate', 'Sports', 'Arts',
  'Tech', 'Language', 'Volunteering',
];

class CreateClubPage extends StatefulWidget {
  final AppUser user;
  const CreateClubPage({super.key, required this.user});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  /// Invisible fallback only — see file header. Kept in sync with
  /// [_category] so a club that never uploads a thumbnail still shows a
  /// sensible icon rather than the generic default.
  String _emoji = ClubVisuals.categoryDefaultKey['General']!;
  String _category = 'General';
  bool _requiresApproval = false;
  File? _bannerFile;
  File? _thumbnailFile;
  bool _saving = false;
  String? _error;

  bool get _isSchoolLinked => (widget.user.schoolId ?? '').isNotEmpty;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _bannerFile = File(picked.path));
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _thumbnailFile = File(picked.path));
  }

  void _onCategoryChanged(String? v) {
    if (v == null) return;
    setState(() {
      _category = v;
      _emoji = ClubVisuals.categoryDefaultKey[v] ?? _emoji;
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final assignedSchoolId = ClubScope.resolveSchoolId(user: widget.user);
    final club = Club(
      id: '',
      name: _nameCtrl.text.trim(),
      emoji: _emoji,
      description: _descCtrl.text.trim(),
      moderatorName: widget.user.name,
      moderatorId: widget.user.id,
      category: _category,
      schoolId: assignedSchoolId,
      requiresApproval: _requiresApproval,
    );

    final repo = ClubRepository.instance;
    final result = await repo.createClub(
      club, widget.user.id,
      founderName: widget.user.name, founderPhotoUrl: widget.user.photoUrl,
      user: widget.user,
    );

    if (result is Failure<String>) {
      setState(() { _error = result.message; _saving = false; });
      return;
    }
    final newId = (result as Success<String>).value;

    // Banner and thumbnail are two independent uploads to two independent
    // Storage paths (see ClubRepository.uploadBanner/uploadThumbnail) —
    // one failing shouldn't block the other or the club's creation,
    // which has already succeeded by this point.
    String? bannerUrl;
    if (_bannerFile != null) {
      final upload = await repo.uploadBanner(clubId: newId, imageFile: _bannerFile!);
      if (upload is Success<String>) bannerUrl = upload.value;
    }
    String? thumbnailUrl;
    if (_thumbnailFile != null) {
      final upload = await repo.uploadThumbnail(clubId: newId, imageFile: _thumbnailFile!);
      if (upload is Success<String>) thumbnailUrl = upload.value;
    }
    if (bannerUrl != null || thumbnailUrl != null) {
      await repo.updateClub(Club(
        id: newId, name: club.name, emoji: club.emoji, description: club.description,
        moderatorName: club.moderatorName, moderatorId: club.moderatorId,
        category: club.category, bannerUrl: bannerUrl, thumbnailUrl: thumbnailUrl,
        schoolId: club.schoolId, requiresApproval: club.requiresApproval,
      ), user: widget.user);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    showToast(context, '${club.name} created — you\'re the admin.');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ClubDetailPage(
        club: Club(
          id: newId, name: club.name, emoji: club.emoji, description: club.description,
          moderatorName: club.moderatorName, moderatorId: club.moderatorId,
          category: club.category, bannerUrl: bannerUrl, thumbnailUrl: thumbnailUrl,
          memberCount: 1, schoolId: club.schoolId, requiresApproval: club.requiresApproval,
        ),
        user: widget.user,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Create a Group', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Rad.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.md),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _pickBanner();
                },
                child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(
                  color: ac.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _bannerFile != null
                      ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _bannerFile == null
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
            // set icon. Shown as the small badge on every club card and
            // the big circle on the club page until this is set, a
            // category-based icon fills in automatically (see ClubLogo).
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
                        image: _thumbnailFile != null
                            ? DecorationImage(image: FileImage(_thumbnailFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _thumbnailFile == null
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Group name is required' : null,
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short description' : null,
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
            if (Branding.current.isSchoolApp || _isSchoolLinked) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, size: 20, color: ac.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('School-exclusive group', style: GoogleFonts.inter(
                              fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                          const SizedBox(height: 2),
                          Text(
                            'This group is automatically created for ${widget.user.schoolName.isNotEmpty ? widget.user.schoolName : Branding.current.appName} and visible only within this school context.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Require approval to join', style: GoogleFonts.inter(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
                subtitle: Text(
                    _requiresApproval
                        ? 'People must request to join — you approve each one.'
                        : 'Anyone can join instantly.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
                value: _requiresApproval,
                activeThumbColor: ac.gold,
                onChanged: (v) => setState(() => _requiresApproval = v),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: ac.red)),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ac.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: ac.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("You'll be the group's admin — you can add moderators later from Members.",
                      style: GoogleFonts.inter(fontSize: 11.5, color: ac.primary)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            PrimaryBtn(label: 'Create Group', onTap: _create, loading: _saving),
          ],
        ),
      )),
    );
  }
}
