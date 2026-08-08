// lib/features/admin/hero_slide_manager_page.dart
// CRUD UI over the already-complete HeroSlideRepository — manages the Home
// banner carousel (headline, subtext, CTA, destination, image, order,
// active toggle). Reachable from Admin Panel > Platform tab and from the
// superAdmin nudge shown when the carousel is empty.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/hero_slide.dart';
import '../../repositories/hero_slide_repository.dart';
import '../../core/result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class HeroSlideManagerPage extends StatefulWidget {
  final String createdByUid;
  const HeroSlideManagerPage({super.key, required this.createdByUid});

  @override
  State<HeroSlideManagerPage> createState() => _HeroSlideManagerPageState();
}

class _HeroSlideManagerPageState extends State<HeroSlideManagerPage> {
  HeroPlacement _placement = HeroPlacement.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text('Banners', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: C.txt),
            onPressed: () => _openEditor(context, null),
          ),
        ],
      ),
      body: AppBackground(child: Column(children: [
        // One admin system, every page that needed its own banner
        // (Home/Courses/Library/Past Questions/Clubs) -- this picks which
        // surface's slides are being managed below.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: HeroPlacement.values.map((p) {
            final selected = p == _placement;
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (_) => setState(() => _placement = p),
              selectedColor: C.primary,
              labelStyle: TextStyle(color: selected ? Colors.white : C.txt),
              backgroundColor: C.surf2,
            );
          }).toList()),
        ),
        Expanded(child: StreamBuilder<List<HeroSlide>>(
          stream: HeroSlideRepository.instance.watchAll(placement: _placement),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            final slides = snap.data ?? const <HeroSlide>[];
            if (slides.isEmpty) {
              return EmptyState(
                icon: Icons.image_outlined,
                title: 'No ${_placement.label} banners yet',
                subtitle: 'Add one to start filling this carousel.',
                actionLabel: 'Add Banner',
                onAction: () => _openEditor(context, null),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: slides.length,
              itemBuilder: (context, i) {
                final s = slides[i];
                return _SlideCard(
                  slide: s,
                  canMoveUp: i > 0,
                  canMoveDown: i < slides.length - 1,
                  onEdit: () => _openEditor(context, s),
                  onDelete: () => _confirmDelete(context, s),
                  onMoveUp: () => _swap(slides, i, i - 1),
                  onMoveDown: () => _swap(slides, i, i + 1),
                  onToggleActive: (v) {
                    s.active = v;
                    HeroSlideRepository.instance.update(s);
                  },
                );
              },
            );
          },
        )),
      ])),
    );
  }

  Future<void> _swap(List<HeroSlide> slides, int a, int b) async {
    final reordered = List<HeroSlide>.from(slides);
    final tmp = reordered[a];
    reordered[a] = reordered[b];
    reordered[b] = tmp;
    await HeroSlideRepository.instance.reorder(reordered);
  }

  void _confirmDelete(BuildContext context, HeroSlide slide) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete banner?'),
        content: Text('This removes "${slide.headline}" from the ${_placement.label} carousel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              HeroSlideRepository.instance.delete(slide.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, HeroSlide? existing) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SlideEditorPage(
          existing: existing, createdByUid: widget.createdByUid, initialPlacement: _placement),
    ));
  }
}

class _SlideCard extends StatelessWidget {
  final HeroSlide slide;
  final bool canMoveUp, canMoveDown;
  final VoidCallback onEdit, onDelete, onMoveUp, onMoveDown;
  final ValueChanged<bool> onToggleActive;
  const _SlideCard({
    required this.slide, required this.canMoveUp, required this.canMoveDown,
    required this.onEdit, required this.onDelete,
    required this.onMoveUp, required this.onMoveDown, required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return ACard(
      color: slide.active ? C.surf : C.surf2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if ((slide.imageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.sm),
              child: Image.network(slide.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56, color: C.surf3,
                      child: const Icon(Icons.image_not_supported_outlined, color: C.muted))),
            )
          else
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(Rad.sm)),
              child: const Icon(Icons.image_outlined, color: Colors.white54),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slide.headline, style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
              const SizedBox(height: 3),
              Text(slide.destination.label, style: GoogleFonts.inter(fontSize: 11.5, color: C.txt2)),
            ]),
          ),
          Switch(value: slide.active, activeThumbColor: C.gold, onChanged: onToggleActive),
        ]),
        const Divider(height: 20, color: C.bdr2),
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              onPressed: canMoveUp ? onMoveUp : null, color: C.txt2),
          IconButton(icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              onPressed: canMoveDown ? onMoveDown : null, color: C.txt2),
          const Spacer(),
          TextButton.icon(onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
          TextButton.icon(onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: C.red),
              label: const Text('Delete', style: TextStyle(color: C.red))),
        ]),
      ]),
    );
  }
}

class _SlideEditorPage extends StatefulWidget {
  final HeroSlide? existing;
  final String createdByUid;
  final HeroPlacement initialPlacement;
  const _SlideEditorPage({this.existing, required this.createdByUid, required this.initialPlacement});

  @override
  State<_SlideEditorPage> createState() => _SlideEditorPageState();
}

class _SlideEditorPageState extends State<_SlideEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final _headlineCtrl = TextEditingController(text: widget.existing?.headline ?? '');
  late final _subtextCtrl = TextEditingController(text: widget.existing?.subtext ?? '');
  late final _ctaCtrl = TextEditingController(text: widget.existing?.ctaLabel ?? 'Explore Now');
  late final _customRouteCtrl = TextEditingController(text: widget.existing?.customRoute ?? '');
  late HeroDestination _destination = widget.existing?.destination ?? HeroDestination.magazine;
  late HeroPlacement _placement = widget.existing?.placement ?? widget.initialPlacement;
  File? _pickedImage;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _subtextCtrl.dispose();
    _ctaCtrl.dispose();
    _customRouteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final repo = HeroSlideRepository.instance;
    var slide = widget.existing ?? HeroSlide(
      id: '', headline: '', subtext: '', createdBy: widget.createdByUid, placement: _placement,
    );
    slide.headline = _headlineCtrl.text.trim();
    slide.subtext = _subtextCtrl.text.trim();
    slide.ctaLabel = _ctaCtrl.text.trim().isEmpty ? 'Explore Now' : _ctaCtrl.text.trim();
    slide.destination = _destination;
    slide.customRoute = _destination == HeroDestination.custom ? _customRouteCtrl.text.trim() : null;
    slide.placement = _placement;

    Result<String>? createResult;
    if (_isNew) {
      createResult = await repo.create(slide);
      if (createResult is Failure<String>) {
        setState(() { _error = (createResult as Failure).message; _saving = false; });
        return;
      }
      // slide.id is final — rebuild with the id Firestore assigned.
      final newId = (createResult as Success<String>).value;
      slide = HeroSlide(
        id: newId,
        headline: slide.headline, subtext: slide.subtext, ctaLabel: slide.ctaLabel,
        destination: slide.destination, customRoute: slide.customRoute,
        imageUrl: slide.imageUrl, order: slide.order, active: slide.active,
        placement: slide.placement,
        createdBy: slide.createdBy,
      );
    }

    if (_pickedImage != null) {
      final uploadResult = await repo.uploadImage(slideId: slide.id, imageFile: _pickedImage!);
      if (uploadResult is Success<String>) {
        slide.imageUrl = (uploadResult).value;
      }
    }

    final saveResult = await repo.update(slide);
    if (mounted) {
      setState(() => _saving = false);
      if (saveResult is Failure) {
        setState(() => _error = (saveResult).message);
      } else {
        showToast(context, _isNew ? 'Banner added.' : 'Banner updated.');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
        title: Text(_isNew ? 'Add Banner' : 'Edit Banner', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(
                  color: C.navy, borderRadius: BorderRadius.circular(Rad.md),
                  image: _pickedImage != null
                      ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                      : (widget.existing?.imageUrl != null
                          ? DecorationImage(image: NetworkImage(widget.existing!.imageUrl!), fit: BoxFit.cover)
                          : null),
                ),
                child: (_pickedImage == null && widget.existing?.imageUrl == null)
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white70, size: 32))
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _text(_headlineCtrl, 'Headline', required: true),
            const SizedBox(height: 14),
            _text(_subtextCtrl, 'Subtext', maxLines: 2),
            const SizedBox(height: 14),
            _text(_ctaCtrl, 'Button Label'),
            const SizedBox(height: 14),
            DropdownButtonFormField<HeroPlacement>(
              initialValue: _placement,
              decoration: InputDecoration(
                labelText: 'Shows on',
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              items: HeroPlacement.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: (v) => setState(() => _placement = v!),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<HeroDestination>(
              initialValue: _destination,
              decoration: InputDecoration(
                labelText: 'Destination',
                filled: true, fillColor: C.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              items: HeroDestination.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                  .toList(),
              onChanged: (v) => setState(() => _destination = v!),
            ),
            if (_destination == HeroDestination.custom) ...[
              const SizedBox(height: 14),
              _text(_customRouteCtrl, 'Custom Route'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: C.red)),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryBtn(label: _isNew ? 'Add Banner' : 'Save Changes', onTap: _save, loading: _saving),
          ],
        ),
      ),
    );
  }

  Widget _text(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: C.txt),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true, fillColor: C.surf3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
      ),
    );
  }
}
