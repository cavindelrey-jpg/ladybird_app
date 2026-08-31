// lib/pages/profile_edit_page.dart
// Lets any signed-in user (school-linked or independent) update their own
// photo, ~100-word bio, education level, and favorite subjects. Photo
// uploads to Supabase Storage and is mirrored to a local file so it
// paints instantly next time.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_user.dart';
import '../models/academic_content.dart' show kAcademicSubjects;
import '../services/auth_service.dart';
import '../widgets/widgets.dart';

import '../widgets/app_background.dart';
const int kBioMaxWords = 100;

class ProfileEditPage extends StatefulWidget {
  final AppUser user;
  const ProfileEditPage({super.key, required this.user});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late String _educationLevel;
  late List<String> _favoriteSubjects;
  String? _photoUrl;
  File? _localPickedFile;
  bool _saving = false;
  bool _uploadingPhoto = false;

  int get _wordCount => _bioCtrl.text.trim().isEmpty
      ? 0
      : _bioCtrl.text.trim().split(RegExp(r'\s+')).length;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _educationLevel =
        widget.user.educationLevel.isNotEmpty ? widget.user.educationLevel : EducationLevels.all.last;
    _favoriteSubjects = List<String>.from(widget.user.favoriteSubjects);
    _photoUrl = widget.user.photoUrl;
    _bioCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _localPickedFile = File(picked.path));
    await _uploadPhoto();
  }

  Future<void> _uploadPhoto() async {
    if (_localPickedFile == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = widget.user.id;
      final path = 'avatars/$uid.jpg';
      final db = Supabase.instance.client;
      await db.storage.from('app-content').upload(
          path, _localPickedFile!, fileOptions: const FileOptions(upsert: true));
      final url = db.storage.from('app-content').getPublicUrl(path);

      // Mirror to local cache so the avatar paints instantly next launch.
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${dir.path}/academia_cache/avatar_$uid.jpg');
      await cacheFile.parent.create(recursive: true);
      await _localPickedFile!.copy(cacheFile.path);

      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) showToast(context, 'Photo upload failed. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_wordCount > kBioMaxWords) {
      showToast(context, 'Bio is over $kBioMaxWords words — trim it a bit.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateUser(widget.user, {
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'education_level': _educationLevel,
        'favorite_subjects': _favoriteSubjects,
        if (_photoUrl != null) 'photo_url': _photoUrl,
      });
      if (!mounted) return;
      showToast(context, 'Profile updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, 'Could not save changes.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Edit Profile',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ac.primary)),
          ),
        ],
      ),
      body: AppBackground(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Stack(children: [
                _photoUrl != null && _photoUrl!.isNotEmpty
                    ? CircleAvatar(radius: 48, backgroundImage: NetworkImage(_photoUrl!))
                    : CircleAvatar(
                        radius: 48, backgroundColor: ac.primaryBg,
                        child: Text(widget.user.initials, style: GoogleFonts.sora(
                            fontSize: 30, fontWeight: FontWeight.w700, color: ac.primary)),
                      ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: ac.gold, shape: BoxShape.circle),
                    child: _uploadingPhoto
                        ? SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ac.navy))
                        : Icon(Icons.camera_alt_rounded, size: 14, color: ac.navy),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap to change photo',
                style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
          ),
          const SizedBox(height: 28),

          _label('Full Name', ac),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: _fieldDecoration(ac, hint: 'Your name'),
          ),
          const SizedBox(height: 20),

          _label('Education Level', ac),
          Container(
            decoration: BoxDecoration(
                color: ac.surf, borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.bdr)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _educationLevel,
                isExpanded: true,
                icon: Icon(Icons.expand_more_rounded, color: ac.muted),
                style: GoogleFonts.inter(fontSize: 14, color: ac.txt),
                items: EducationLevels.all
                    .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl)))
                    .toList(),
                onChanged: (v) => setState(() => _educationLevel = v ?? _educationLevel),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _label('Favorite Subjects', ac),
          Text('Used to personalize what Library, Courses, Magazine, and Quizzes recommend to you.',
              style: GoogleFonts.inter(fontSize: 11.5, color: ac.txt2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kAcademicSubjects.map((s) {
              final selected = _favoriteSubjects.contains(s);
              return ChoiceChip(
                label: Text(s),
                selected: selected,
                onSelected: (_) => setState(() => selected
                    ? _favoriteSubjects.remove(s)
                    : _favoriteSubjects.add(s)),
                selectedColor: ac.primary,
                labelStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: selected ? Colors.white : ac.txt,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                backgroundColor: ac.surf,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: selected ? ac.primary : ac.bdr)),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Row(children: [
            _label('Bio', ac),
            const Spacer(),
            Text('$_wordCount / $kBioMaxWords words',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _wordCount > kBioMaxWords ? ac.red : ac.muted)),
          ]),
          TextField(
            controller: _bioCtrl,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: _fieldDecoration(ac, hint: 'Tell people a bit about yourself…'),
          ),
        ]),
      )),
    );
  }

  Widget _label(String text, AppColors ac) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: GoogleFonts.sora(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.txt2)),
      );

  InputDecoration _fieldDecoration(AppColors ac, {required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: ac.muted),
        filled: true,
        fillColor: ac.surf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.bdr)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.primary)),
      );
}
