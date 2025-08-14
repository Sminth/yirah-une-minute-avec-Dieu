import 'package:flutter/material.dart';
import 'package:one_minute/controllers/home_controller.dart';

class QuickDurations extends StatelessWidget {
  const QuickDurations(
      {super.key, required this.onSelect, required this.controller});

  final void Function(Duration) onSelect;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    ButtonStyle outlinedStyle() => OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
    ButtonStyle filledStyle() => FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );

    Widget rect(String label, Duration d) {
      final bool active = controller.selectedQuickDuration == d;
      final ButtonStyle style = active ? filledStyle() : outlinedStyle();
      final Widget btn = active
          ? FilledButton(
              onPressed: () {
                controller.setSelectedQuickDuration(d);
                onSelect(d);
              },
              style: style,
              child: Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            )
          : OutlinedButton(
              onPressed: () {
                controller.setSelectedQuickDuration(d);
                onSelect(d);
              },
              style: style,
              child: Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            );
      return SizedBox(height: 46, child: btn);
    }

    final Duration? custom = controller.customQuickDuration;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: rect('1min', const Duration(minutes: 1))),
        const SizedBox(width: 10),
        Expanded(child: rect('5min', const Duration(minutes: 5))),
        const SizedBox(width: 10),
        Expanded(child: rect('10min', const Duration(minutes: 10))),
        if (custom != null) ...[
          const SizedBox(width: 10),
          Expanded(child: rect(_labelFor(custom), custom)),
        ],
      ],
    );
  }

  String _labelFor(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    if (s == 0) return '${m}min';
    if (m == 0) return '${s}s';
    return '${m}m${s}s';
  }
}
