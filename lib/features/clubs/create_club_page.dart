// lib/features/clubs/create_club_page.dart
// Any signed-in (non-guest) user can create a club — the founder becomes
// its admin automatically (ClubRepository.createClub already sets this up).
// This screen was the missing piece: the backend supported it, there was
// just no UI to reach it.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../repositories/club_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import 'clubs_page.dart';

const _kClubCategories = [
  'General', 'Academic', 'Debate', 'Sports', 'Arts',
  'Tech', 'Language', 'Volunteering',
];

const _kEmojiSuggestions = [
  '🎓', '📚', '🎨', '⚽', '🎭', '🧪', '💻', '🎵', '♟️', '🌍', '🗣️', '📷',
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
  String _emoji = '🎓';
  String _category = 'General';
  bool _restrictToSchool = true;
  File? _bannerFile;
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

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final club = Club(
      id: '',
      name: _nameCtrl.text.trim(),
      emoji: _emoji,
      description: _descCtrl.text.trim(),
      moderatorName: widget.user.name,
      moderatorId: widget.user.id,
      category: _category,
      schoolId: (_isSchoolLinked && _restrictToSchool) ? widget.user.schoolId : null,
    );

    final repo = ClubRepository.instance;
    final result = await repo.createClub(
      club, widget.user.id,
      founderName: widget.user.name, founderPhotoUrl: widget.user.photoUrl,
    );

    if (result is Failure<String>) {
      setState(() { _error = result.message; _saving = false; });
      return;
    }
    final newId = (result as Success<String>).value;

    if (_bannerFile != null) {
      final upload = await repo.uploadBanner(clubId: newId, imageFile: _bannerFile!);
      if (upload is Success<String>) {
        await repo.updateClub(Club(
          id: newId, name: club.name, emoji: club.emoji, description: club.description,
          moderatorName: club.moderatorName, moderatorId: club.moderatorId,
          category: club.category, bannerUrl: upload.value, schoolId: club.schoolId,
        ));
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    showToast(context, '${club.name} created — you\'re the admin.');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ClubDetailPage(
        club: Club(
          id: newId, name: club.name, emoji: club.emoji, description: club.description,
          moderatorName: club.moderatorName, moderatorId: club.moderatorId,
          category: club.category, bannerUrl: _bannerFile != null ? null : club.bannerUrl,
          memberCount: 1, schoolId: club.schoolId,
        ),
        user: widget.user,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Create a Club', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickBanner,
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _bannerFile != null
                      ? DecorationImage(image: FileImage(_bannerFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _bannerFile == null
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white70, size: 28))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Banner (optional)', style: GoogleFonts.inter(fontSize: 11.5, color: C.muted)),
            ),
            const SizedBox(height: 20),
            Text('Emoji', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _kEmojiSuggestions.map((e) {
                final selected = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected ? C.goldp : C.surf3,
                      borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(color: selected ? C.gold : C.bdr),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: C.txt),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Club name is required' : null,
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short description' : null,
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
            if (_isSchoolLinked) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: C.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: C.bdr)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Restrict to my school', style: GoogleFonts.inter(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: C.txt)),
                  subtitle: Text(
                      _restrictToSchool
                          ? 'Only people at your school will see this club.'
                          : 'Open to everyone on Academia.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: C.txt2)),
                  value: _restrictToSchool,
                  activeColor: C.gold,
                  onChanged: (v) => setState(() => _restrictToSchool = v),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: C.red)),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: C.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("You'll be the club's admin — you can add moderators later from Members.",
                      style: GoogleFonts.inter(fontSize: 11.5, color: C.primary)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            PrimaryBtn(label: 'Create Club', onTap: _create, loading: _saving),
          ],
        ),
      ),
    );
  }
}
