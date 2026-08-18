// lib/features/magazine/magazine_video_player_page.dart
// Full-screen player for a Magazine "Latest Videos" post. Same
// video_player/chewie pairing academic_content's ContentViewerPage
// already uses for playback — no new dependency, no new pattern.

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../../models/magazine_video_post.dart';
import '../../repositories/magazine_repository.dart';

class MagazineVideoPlayerPage extends StatefulWidget {
  final MagazineVideoPost video;
  const MagazineVideoPlayerPage({super.key, required this.video});

  @override
  State<MagazineVideoPlayerPage> createState() => _MagazineVideoPlayerPageState();
}

class _MagazineVideoPlayerPageState extends State<MagazineVideoPlayerPage> {
  late final VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    MagazineRepository.instance.incrementVideoViews(widget.video.id);
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    _videoCtrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieCtrl = ChewieController(videoPlayerController: _videoCtrl, autoPlay: true, looping: false);
      });
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    });
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : (_chewieCtrl == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Chewie(controller: _chewieCtrl!)),
      ),
    );
  }
}
