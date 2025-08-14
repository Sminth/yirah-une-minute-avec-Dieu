import 'package:flutter/material.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.progress,
    required this.isDark,
    required this.primary,
    required this.isRunning,
    required this.timeLabel,
    required this.onToggle,
  });

  final double progress; // 0..1
  final bool isDark;
  final Color primary;
  final bool isRunning;
  final String timeLabel; // "01:00"
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Material(
            shape: const CircleBorder(),
            elevation: 6,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggle,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 6),
                ),
                child: Center(
                  child: Text(
                    timeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
