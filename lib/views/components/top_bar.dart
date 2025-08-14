import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.onToggleTheme,
    this.onOpenSettings,
    this.onOpenAbout,
    this.onToggleAudio,
    this.isAudioPlaying,
    this.isMuted,
  });

  final VoidCallback? onToggleTheme;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAbout;
  final VoidCallback? onToggleAudio;
  final bool? isAudioPlaying;
  final bool? isMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundIconButton(icon: Icons.wb_sunny_outlined, onTap: onToggleTheme),
        Row(
          children: [
            if (onToggleAudio != null)
              _roundIconButton(
                icon: (isAudioPlaying ?? false)
                    ? ((isMuted ?? false) ? Icons.volume_off : Icons.volume_up)
                    : Icons.volume_off,
                onTap: onToggleAudio,
              ),
            const SizedBox(width: 8),
            _roundIconButton(
                icon: Icons.settings_outlined, onTap: onOpenSettings),
            const SizedBox(width: 8),
            _roundIconButton(icon: Icons.info_outline, onTap: onOpenAbout),
          ],
        ),
      ],
    );
  }

  Widget _roundIconButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
