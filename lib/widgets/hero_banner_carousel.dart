// lib/widgets/hero_banner_carousel.dart
// The admin-editable, swipeable Home banner carousel. Backed entirely by
// HeroSlideRepository -- this widget just picks a placement and renders.
//
// production_plan.md §7B retired every other HeroPlacement (Courses,
// Library, Past Questions, Clubs, Messages) in favor of automatic content
// recommendations (see RecommendationRepository), so HeroPlacement now has
// only [HeroPlacement.home] -- this widget is still generalized over
// [HeroPlacement] rather than hardcoded to Home, since Home is itself just
// the one remaining value, not a special case.
//
// A superAdmin viewing an empty carousel gets an inline "Add your first
// {Placement} banner" nudge that opens HeroSlideManagerPage pre-scoped to
// this placement; everyone else just sees nothing (SizedBox.shrink).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../models/hero_slide.dart';
import '../repositories/hero_slide_repository.dart';
import '../repositories/library_folder_repository.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';
import '../features/admin/hero_slide_manager_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/academic_content/library_folder_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/messages/messages_home_page.dart';

class HeroBannerCarousel extends StatefulWidget {
  final HeroPlacement placement;
  final AppUser? user;
  /// Called when a tapped slide's destination is [HeroDestination.section]
  /// with the slide's `customRoute` as the section key. The host page
  /// decides what keys mean (a filter, a category, a scroll target) --
  /// this widget only knows how to hand the key off, not what it does.
  /// If null, section-destination slides fall back to a toast.
  final ValueChanged<String>? onSectionSelect;
  const HeroBannerCarousel({
    super.key,
    required this.placement,
    required this.user,
    this.onSectionSelect,
  });

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  final _pageCtrl = PageController();
  late final Stream<List<HeroSlide>> _slidesStream =
      HeroSlideRepository.instance.watchActive(placement: widget.placement);
  Timer? _autoTimer;
  int _index = 0;
  int _slideCount = 0;

  bool get _isGuest => widget.user == null;
  AppUser? get _u => widget.user;

  AppColors get ac => AppColors.of(context);

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _ensureAutoAdvance(int slideCount) {
    _slideCount = slideCount;
    if (_autoTimer != null || slideCount <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_pageCtrl.hasClients || _slideCount <= 1) return;
      final next = (_index + 1) % _slideCount;
      _pageCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HeroSlide>>(
      stream: _slidesStream,
      builder: (context, snap) {
        final slides = snap.data ?? const <HeroSlide>[];
        if (slides.isEmpty) {
          if (!_isGuest && _u!.isSuperAdmin) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HeroSlideManagerPage(
                        createdByUid: _u!.id, initialPlacement: widget.placement))),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Add your first ${widget.placement.label} banner'),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        _ensureAutoAdvance(slides.length);
        return SizedBox(
          height: 176,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: slides.length,
                itemBuilder: (_, i) => _bannerCard(context, slides[i], slides.length),
              ),
              if (!_isGuest && _u!.isSuperAdmin)
                Positioned(
                  top: 8,
                  right: 24,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    tooltip: 'Manage Banners',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => HeroSlideManagerPage(
                            createdByUid: _u!.id, initialPlacement: widget.placement))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _bannerCard(BuildContext context, HeroSlide slide, int totalSlides) {
    final radius = BorderRadius.circular(Rad.xl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: ac.navy,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openHeroSlide(context, slide);
          },
          child: Ink(
            height: 160,
            decoration: BoxDecoration(
              image: (slide.imageUrl != null && slide.imageUrl!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(slide.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xD1000000), Colors.transparent],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slide.headline, style: GoogleFonts.sora(
                    fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(slide.subtext, style: GoogleFonts.inter(
                    fontSize: 12.5, color: Colors.white70, height: 1.3)),
                if (slide.statLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.workspace_premium_outlined, color: Colors.white60, size: 15),
                    const SizedBox(width: 6),
                    Text(slide.statLine,
                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white)),
                  ]),
                ],
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: ac.gold, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(slide.ctaLabel, style: GoogleFonts.sora(
                          fontSize: 12, fontWeight: FontWeight.w700, color: ac.navy)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: ac.navy),
                    ]),
                  ),
                  if (totalSlides > 1)
                    Row(children: List.generate(totalSlides, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? ac.gold : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Deep-links straight into a Library root folder by name (e.g. "Past
  /// Papers") — falls back to the Academia Library home page if that root
  /// folder was renamed or removed since this shortcut was wired up.
  Future<void> _openLibraryFolderByName(BuildContext context, AppUser user, String name) async {
    final folder = await LibraryFolderRepository.instance.rootFolderByName(name);
    if (!context.mounted) return;
    if (folder == null) {
      _open(context, LibraryHomePage(user: user));
      return;
    }
    _open(context, LibraryFolderPage(folderId: folder.id, folderName: folder.name, user: user));
  }

  void _openHeroSlide(BuildContext context, HeroSlide slide) {
    final user = _u ?? AppUser.guest();
    switch (slide.destination) {
      case HeroDestination.library:
        _open(context, LibraryHomePage(user: user));
        break;
      case HeroDestination.clubs:
        _open(context, ClubsPage(user: user));
        break;
      case HeroDestination.pastQuestions:
        _openLibraryFolderByName(context, user, 'Past Papers');
        break;
      case HeroDestination.magazine:
        _open(context, MagazineFeedPage(user: user));
        break;
      case HeroDestination.courses:
        _open(context, CoursesHomePage(user: user));
        break;
      case HeroDestination.messages:
        _open(context, MessagesHomePage(user: user));
        break;
      case HeroDestination.section:
        final key = slide.customRoute ?? '';
        if (widget.onSectionSelect != null && key.isNotEmpty) {
          widget.onSectionSelect!(key);
        } else {
          showToast(context, "This banner isn't linked to a section yet.");
        }
        break;
      case HeroDestination.custom:
        break;
    }
  }
}
