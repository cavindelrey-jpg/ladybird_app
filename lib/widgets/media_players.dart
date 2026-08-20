// lib/widgets/media_players.dart
// Players for Magazine's Video/Audio article types.
//
// Video reuses the same chewie/video_player stack ContentViewerPage
// already uses for uploaded video files. Audio deliberately reuses
// VideoPlayerController too — it plays audio-only network files fine —
// instead of pulling in a dedicated audio-player package for one screen.

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class ArticleVideoPlayer extends StatefulWidget {
  final String url;
  const ArticleVideoPlayer({super.key, required this.url});

  @override
  State<ArticleVideoPlayer> createState() => _ArticleVideoPlayerState();
}

class _ArticleVideoPlayerState extends State<ArticleVideoPlayer> {
  late final VideoPlayerController _videoCtrl;
  ChewieController? _chewieCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoCtrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _chewieCtrl = ChewieController(
          videoPlayerController: _videoCtrl,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoCtrl.value.aspectRatio == 0 ? 16 / 9 : _videoCtrl.value.aspectRatio,
        );
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.md),
      child: Container(
        color: Colors.black,
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : (_chewieCtrl == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Chewie(controller: _chewieCtrl!)),
        ),
      ),
    );
  }
}

/// Compact "now playing" style audio player: cover art, scrubber,
/// elapsed/remaining time, and a play/pause button — no external
/// dependency beyond video_player, which already ships in this app.
class ArticleAudioPlayer extends StatefulWidget {
  final String url;
  final String? coverUrl;
  const ArticleAudioPlayer({super.key, required this.url, this.coverUrl});

  @override
  State<ArticleAudioPlayer> createState() => _ArticleAudioPlayerState();
}

class _ArticleAudioPlayerState extends State<ArticleAudioPlayer> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.addListener(_onTick);
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Could not play this audio.');
    });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    if (_ctrl.value.isPlaying) {
      _ctrl.pause();
    } else {
      _ctrl.play();
    }
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '0:00';
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.md)),
        child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
      );
    }

    final position = _ready ? _ctrl.value.position : Duration.zero;
    final duration = _ready ? _ctrl.value.duration : Duration.zero;
    final durationMs = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final isPlaying = _ready && _ctrl.value.isPlaying;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [ac.navy2, ac.navy], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Rad.md),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rad.sm),
          child: (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
              ? Image.network(widget.coverUrl!, width: 56, height: 56, fit: BoxFit.cover)
              : Container(
                  width: 56, height: 56, color: Colors.white12,
                  child: const Icon(Icons.music_note_rounded, color: Colors.white70)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_ready)
              const LinearProgressIndicator(
                  minHeight: 3, backgroundColor: Colors.white24, color: Colors.white70)
            else
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: position.inMilliseconds.clamp(0, durationMs).toDouble(),
                  max: durationMs.toDouble(),
                  activeColor: ac.gold,
                  inactiveColor: Colors.white24,
                  onChanged: duration.inMilliseconds == 0
                      ? null
                      : (v) => _ctrl.seekTo(Duration(milliseconds: v.round())),
                ),
              ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(position), style: AppText.caption.copyWith(color: Colors.white60)),
              Text(_fmt(duration), style: AppText.caption.copyWith(color: Colors.white60)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Material(
          color: ac.gold,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _ready ? _togglePlay : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: ac.navy, size: 22),
            ),
          ),
        ),
      ]),
    );
  }
}
