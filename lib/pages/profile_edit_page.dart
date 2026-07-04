// lib/pages/profile_edit_page.dart
// Lets any signed-in user (school-linked or independent) update their own
// photo, ~100-word bio, and education level. Photo uploads to Firebase
// Storage and is mirrored to a local file so it paints instantly next time
// (Firebase + local cache, per your call).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';

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
      final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
      await ref.putFile(_localPickedFile!);
      final url = await ref.getDownloadURL();

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
        'educationLevel': _educationLevel,
        if (_photoUrl != null) 'photoUrl': _photoUrl,
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
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Edit Profile',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Save', style: GoogleFonts.sora(
                    fontSize: 14, fontWeight: FontWeight.w700, color: C.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Center(
            child: GestureDetector(
              onTap: _uploadingPhoto ? null : _pickPhoto,
              child: Stack(children: [
                _photoUrl != null && _photoUrl!.isNotEmpty
                    ? CircleAvatar(radius: 48, backgroundImage: NetworkImage(_photoUrl!))
                    : CircleAvatar(
                        radius: 48, backgroundColor: C.primaryBg,
                        child: Text(widget.user.initials, style: GoogleFonts.sora(
                            fontSize: 30, fontWeight: FontWeight.w700, color: C.primary)),
                      ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                    child: _uploadingPhoto
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: C.navy))
                        : const Icon(Icons.camera_alt_rounded, size: 14, color: C.navy),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Tap to change photo',
                style: GoogleFonts.inter(fontSize: 12, color: C.txt2)),
          ),
          const SizedBox(height: 28),

          _label('Full Name'),
          TextField(
            controller: _nameCtrl,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: _fieldDecoration(hint: 'Your name'),
          ),
          const SizedBox(height: 20),

          _label('Education Level'),
          Container(
            decoration: BoxDecoration(
                color: C.surf, borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: C.bdr)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _educationLevel,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded, color: C.muted),
                style: GoogleFonts.inter(fontSize: 14, color: C.txt),
                items: EducationLevels.all
                    .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl)))
                    .toList(),
                onChanged: (v) => setState(() => _educationLevel = v ?? _educationLevel),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(children: [
            _label('Bio'),
            const Spacer(),
            Text('$_wordCount / $kBioMaxWords words',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _wordCount > kBioMaxWords ? C.red : C.muted)),
          ]),
          TextField(
            controller: _bioCtrl,
            maxLines: 5,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: _fieldDecoration(hint: 'Tell people a bit about yourself…'),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: GoogleFonts.sora(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: C.txt2)),
      );

  InputDecoration _fieldDecoration({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: C.muted),
        filled: true,
        fillColor: C.surf,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: const BorderSide(color: C.bdr)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: const BorderSide(color: C.bdr)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.md), borderSide: const BorderSide(color: C.primary)),
      );
}
