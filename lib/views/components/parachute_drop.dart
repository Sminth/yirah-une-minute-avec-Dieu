import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ParachuteDrop extends StatefulWidget {
  const ParachuteDrop(
      {super.key,
      required this.title,
      required this.message,
      this.onFinished,
      this.onRefresh});

  final String title;
  final String message;
  final VoidCallback? onFinished;
  final Future<Map<String, String>> Function()? onRefresh;

  @override
  State<ParachuteDrop> createState() => _ParachuteDropState();
}

class _ParachuteDropState extends State<ParachuteDrop>
    with TickerProviderStateMixin {
  late final AnimationController _fallCtrl;
  late final AnimationController _packageCtrl;
  bool _showCard = false;
  late final double _spawnXNorm; // 0..1 normalized horizontal spawn
  late final double _landingYNorm; // 0..1 normalized landing Y position
  late final double _swayAmpPx; // sway amplitude in pixels
  late final int _swayWaves; // number of waves during fall

  late String _title;
  late String _message;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _message = widget.message;
    // Randomized parameters for variety
    final rnd = math.Random();
    _spawnXNorm = 0.18 + rnd.nextDouble() * 0.64; // 18%..82% of width
    _landingYNorm = 0.56 + rnd.nextDouble() * 0.16; // 56%..72% of height
    _swayAmpPx = 18 + rnd.nextDouble() * 26; // 18..44 px
    _swayWaves = 2 + rnd.nextInt(3); // 2..4 waves

    _fallCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800));
    _packageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _startSequence();
  }

  Future<void> _startSequence() async {
    try {
      await _fallCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 250));
      await _packageCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 220));
      if (mounted) setState(() => _showCard = true);
    } finally {
      // Do not auto-close; user closes via the X button
    }
  }

  @override
  void dispose() {
    _fallCtrl.dispose();
    _packageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double topStart = -140;
    final double topEnd = size.height * _landingYNorm;

    return Stack(
      children: [
        // Parachutist descent with sway and slight tilt
        AnimatedBuilder(
          animation: _fallCtrl,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_fallCtrl.value);
            final top = topStart + (topEnd - topStart) * t;
            final baseX = size.width * _spawnXNorm;
            final sway = math.sin(t * _swayWaves * math.pi * 2) *
                _swayAmpPx *
                (1 - t * 0.3);
            final left = baseX - 18 + sway;
            return Positioned(
              top: top,
              left: left,
              child: Opacity(
                opacity: 0.95,
                child: Transform.rotate(
                  angle: math.sin(t * _swayWaves * math.pi * 2) *
                      0.08, // subtle tilt
                  child: Icon(Icons.paragliding,
                      size: 36, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            );
          },
        ),

        // Package drop with bounce
        AnimatedBuilder(
          animation: _packageCtrl,
          builder: (context, child) {
            final t = Curves.easeOutBack.transform(_packageCtrl.value);
            final double y = topEnd + (1 - t) * 40;
            final double scale = 0.85 + 0.15 * t;
            final baseX = size.width * _spawnXNorm;
            return Positioned(
              top: y,
              left: baseX - 14,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: _packageCtrl.value,
                  child: Icon(Icons.inventory_2_rounded,
                      size: 28,
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            );
          },
        ),

        // Message card
        if (_showCard)
          Align(
            alignment: const Alignment(0, 0.6),
            child: _MessageCard(
              title: _title,
              message: _message,
              onClose: widget.onFinished,
              onRefresh: widget.onRefresh,
              onApplyRefresh: (next) {
                setState(() {
                  _title = next['title'] ?? _title;
                  _message = next['message'] ?? _message;
                });
              },
            ),
          ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.message,
    this.onClose,
    this.onRefresh,
    this.onApplyRefresh,
  });
  final String title;
  final String message;
  final VoidCallback? onClose;
  final Future<Map<String, String>> Function()? onRefresh;
  final void Function(Map<String, String> next)? onApplyRefresh;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.86,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    final String content = '$title\n\n$message';
                    await Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copié dans le presse-papiers')),
                    );
                  },
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: 'Autre message',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: () async {
                      final next = await onRefresh!.call();
                      onApplyRefresh?.call(next);
                    },
                  ),
                Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      tooltip: 'Partager',
                      icon: const Icon(Icons.share_rounded, size: 18),
                      onPressed: () async {
                        final String content = '$title\n\n$message';
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        if (box != null) {
                          await Share.share(
                            content,
                            sharePositionOrigin:
                                box.localToGlobal(Offset.zero) & box.size,
                          );
                        } else {
                          await Share.share(content);
                        }
                      },
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
