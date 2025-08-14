import 'package:flutter/material.dart';

class BottomMiniPlayer extends StatefulWidget {
  const BottomMiniPlayer({
    super.key,
    required this.isPlaying,
    required this.title,
    required this.subtitle,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onForward,
    required this.onRewind,
    this.onHeart,
    this.onOpenPlaylist,
    this.isHeartPulsing = false,
  });

  final bool isPlaying;
  final String title;
  final String subtitle;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onForward;
  final VoidCallback onRewind;
  final VoidCallback? onHeart;
  final VoidCallback? onOpenPlaylist;
  final bool isHeartPulsing;

  @override
  State<BottomMiniPlayer> createState() => _BottomMiniPlayerState();
}

class _BottomMiniPlayerState extends State<BottomMiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isHeartPulsing) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BottomMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHeartPulsing && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isHeartPulsing && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12161C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lecteur audio',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title.isEmpty ? 'Aucune piste' : widget.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Playlist',
            onPressed: widget.onOpenPlaylist,
            icon: const Icon(Icons.queue_music_rounded),
          ),
          IconButton(
            tooltip: 'Précédent',
            onPressed: widget.onPrev,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            tooltip: 'Reculer 10s',
            onPressed: widget.onRewind,
            icon: const Icon(Icons.replay_10_rounded),
          ),
          IconButton(
            onPressed: widget.onPlayPause,
            icon: Icon(
              widget.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: scheme.primary,
              size: 28,
            ),
          ),
          IconButton(
            tooltip: 'Avancer 10s',
            onPressed: widget.onForward,
            icon: const Icon(Icons.forward_10_rounded),
          ),
          IconButton(
            tooltip: 'Suivant',
            onPressed: widget.onNext,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          if (widget.onHeart != null)
            ScaleTransition(
              scale: widget.isHeartPulsing
                  ? _pulseScale
                  : const AlwaysStoppedAnimation(1.0),
              child: IconButton(
                tooltip: 'Inspiration',
                onPressed: widget.onHeart,
                icon: const Icon(Icons.favorite_rounded),
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}
