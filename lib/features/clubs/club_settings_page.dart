// lib/features/clubs/club_settings_page.dart
// Admin-only club settings: edit name/description/category/emoji/banner/
// approval-gating, plus delete the club. The create flow already covered
// "make a club"; this was the missing "manage an existing one" half.

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
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

const _kClubCategories = [
  'General', 'Academic', 'Debate', 'Sports', 'Arts',
  'Tech', 'Language', 'Volunteering',
];

const _kEmojiSuggestions = [
  '🎓', '📚', '🎨', '⚽', '🎭', '🧪', '💻', '🎵', '♟️', '🌍', '🗣️', '📷',
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showToast(context, 'Club name is required');
      return;
    }
    setState(() => _saving = true);
    final repo = ClubRepository.instance;
    var bannerUrl = widget.club.bannerUrl;
    if (_newBannerFile != null) {
      final upload = await repo.uploadBanner(clubId: widget.club.id, imageFile: _newBannerFile!);
      if (upload is Success<String>) bannerUrl = upload.value;
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
      memberCount: widget.club.memberCount,
      schoolId: widget.club.schoolId,
      requiresApproval: _requiresApproval,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Success) {
      showToast(context, 'Club settings saved.');
      Navigator.of(context).pop(true);
    } else {
      showToast(context, (result as Failure).message);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this club?'),
        content: Text('"${widget.club.name}" and its chat history will be permanently deleted. '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final result = await ClubRepository.instance.deleteClub(widget.club.id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (result is Success) {
      // Pop settings AND the club detail page underneath it -- the club
      // no longer exists, nothing left to show there.
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/clubs');
      showToast(context, 'Club deleted.');
    } else {
      showToast(context, (result as Failure).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Club Settings', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Rad.md),
              onTap: () { HapticFeedback.selectionClick(); _pickBanner(); },
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.navy, borderRadius: BorderRadius.circular(Rad.md),
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
          const SizedBox(height: 20),
          Text('Emoji', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _kEmojiSuggestions.map((e) {
              final selected = e == _emoji;
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(Rad.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Rad.sm),
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _emoji = e); },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected ? C.goldp : C.surf3,
                      borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(color: selected ? C.gold : C.bdr),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameCtrl,
            style: GoogleFonts.inter(fontSize: 14, color: C.txt),
            decoration: InputDecoration(
              labelText: 'Club Name',
              filled: true, fillColor: C.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14, color: C.txt),
            decoration: InputDecoration(
              labelText: 'Description',
              filled: true, fillColor: C.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true, fillColor: C.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
            items: _kClubCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Require approval to join', style: GoogleFonts.inter(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: C.txt)),
              value: _requiresApproval,
              activeThumbColor: C.gold,
              onChanged: (v) => setState(() => _requiresApproval = v),
            ),
          ),
          const SizedBox(height: 28),
          PrimaryBtn(label: 'Save Changes', onTap: _save, loading: _saving),
          if (_isFounder) ...[
            const SizedBox(height: 28),
            const Divider(color: C.bdr2),
            const SizedBox(height: 12),
            Text('Danger Zone', style: GoogleFonts.sora(
                fontSize: 13, fontWeight: FontWeight.w800, color: C.red)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleting ? null : _confirmDelete,
                style: OutlinedButton.styleFrom(
                    foregroundColor: C.red, side: const BorderSide(color: C.red)),
                icon: _deleting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: C.red))
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(_deleting ? 'Deleting…' : 'Delete Club'),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}
