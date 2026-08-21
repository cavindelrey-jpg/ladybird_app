// lib/features/magazine/gallery_viewer_page.dart
// Full-screen swipeable viewer for a Student Gallery post.

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/magazine_gallery_post.dart';
import '../../repositories/magazine_repository.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_colors.dart';

class GalleryViewerPage extends StatefulWidget {
  final MagazineGalleryPost post;
  final AppUser? currentUser;
  const GalleryViewerPage({super.key, required this.post, this.currentUser});

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final u = widget.currentUser;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_index + 1} / ${widget.post.imageUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            itemCount: widget.post.imageUrls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.5, maxScale: 4,
              child: Center(child: Image.network(widget.post.imageUrls[i], fit: BoxFit.contain)),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              UserAvatar(initials: widget.post.authorName.isEmpty ? '?' : widget.post.authorName[0].toUpperCase(),
                  radius: 14, photoUrl: widget.post.authorPhotoUrl),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.post.authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
              if (u != null && !u.isGuest)
                StreamBuilder<bool>(
                  stream: MagazineRepository.instance.watchIsGalleryLiked(widget.post.id, u.id),
                  builder: (context, snap) {
                    final liked = snap.data ?? false;
                    return IconButton(
                      icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: liked ? ac.red : Colors.white, size: 20),
                      onPressed: () => MagazineRepository.instance.toggleGalleryLike(widget.post.id, u.id),
                    );
                  },
                ),
            ]),
            if (widget.post.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.post.caption, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ]),
        ),
      ]),
    );
  }
}
