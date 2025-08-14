import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:one_minute/controllers/home_controller.dart';
import 'package:one_minute/views/about_view.dart';
import 'package:one_minute/views/components/bottom_mini_player.dart';
import 'package:one_minute/views/components/inspiration_slider.dart';
import 'package:one_minute/views/components/parachute_drop.dart';
import 'package:one_minute/views/components/player_bar.dart';
import 'package:one_minute/views/components/quick_durations.dart';
import 'package:one_minute/views/components/top_bar.dart';
import 'package:one_minute/views/components/verse_panel.dart';
import 'package:one_minute/views/settings_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeController controller;
  OverlayEntry? _parachuteEntry;
  bool _isHeartPulsing = false;
  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    controller = HomeController();
    controller.addListener(_onChange);
    controller.init();
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    controller.disposeController();
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double progress = controller.total.inSeconds == 0
        ? 0
        : 1 - (controller.remaining.inSeconds / controller.total.inSeconds);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(
                onToggleTheme: widget.onToggleTheme,
                onOpenSettings: () => _openSettingsPage(context),
                onOpenAbout: () => _openAboutPage(context),
                onToggleAudio: controller.toggleMute,
                isAudioPlaying: controller.isAudioPlaying,
                isMuted: controller.isMuted,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            Text('Une minute avec Dieu',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      VersePanel(
                        reference: controller.verseRef,
                        verses: controller.verseText.split('\n'),
                      ),
                      const SizedBox(height: 16),
                      PlayerBar(
                        progress: progress,
                        isDark: isDark,
                        primary: scheme.primary,
                        isRunning: controller.isRunning,
                        timeLabel: controller.isRunning
                            ? _format(controller.remaining)
                            : _format(controller.selectedQuickDuration),
                        onToggle: () {
                          if (controller.isRunning) {
                            controller.startSession(Duration.zero);
                          } else {
                            controller
                                .startSession(controller.selectedQuickDuration);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      QuickDurations(
                        onSelect: (d) => controller.startSession(d),
                        controller: controller,
                      ),
                      const SizedBox(height: 46),
                      const InspirationSlider(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              BottomMiniPlayer(
                isPlaying: controller.isAudioPlaying,
                title: controller.currentTrackName ?? 'Audio local',
                subtitle: 'Mini lecteur',
                onPlayPause: controller.toggleAudio,
                onNext: controller.nextTrack,
                onPrev: controller.previousTrack,
                onForward: () => controller.seekBy(const Duration(seconds: 10)),
                onRewind: () => controller.seekBy(const Duration(seconds: -10)),
                onHeart: _triggerParachute,
                onOpenPlaylist: () => _openTrackPicker(context),
                isHeartPulsing: _isHeartPulsing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsView(controller: controller),
      ),
    );
  }

  void _openAboutPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AboutView(),
      ),
    );
  }

  Future<void> _openTrackPicker(BuildContext context) async {
    final files = await controller.getLocalAudioFiles();
    if (!mounted) return;
    if (files.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Aucun audio trouvé'),
          content: const Text(
              "Ajoutez des fichiers audio dans le dossier de l'application (audio)."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Ajouter depuis mon téléphone...'),
                onTap: () async {
                  final res = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    type: FileType.custom,
                    allowedExtensions: const ['mp3', 'm4a', 'aac'],
                  );
                  if (res != null) {
                    final paths = res.files
                        .where((f) => f.path != null)
                        .map((f) => f.path!)
                        .toList();
                    await controller.importFromDevicePaths(paths);
                  }
                  if (mounted) Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = files[i];
                    final String base = f.path.split('/').last;
                    final String display = base.replaceAll(
                        RegExp(r'\.(mp3|m4a|aac)$', caseSensitive: false), '');
                    final bool isCurrent =
                        controller.currentTrackFilePath == f.path;
                    return Dismissible(
                      key: ValueKey(f.path),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.red.withOpacity(0.12),
                        child:
                            const Icon(Icons.delete_forever, color: Colors.red),
                      ),
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Supprimer ce fichier ?'),
                                content: Text(
                                    '“$display” sera retiré de la playlist.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Annuler')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Supprimer')),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (_) async {
                        await controller.deleteLocalAudioFileAtPath(f.path);
                        if (mounted) setState(() {});
                      },
                      child: ListTile(
                        leading: Icon(
                          isCurrent
                              ? Icons.equalizer_rounded
                              : Icons.music_note,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrent)
                              Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final bool confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text(
                                            'Supprimer ce fichier ?'),
                                        content: Text(
                                            '“$display” sera retiré de la playlist.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Annuler')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Supprimer')),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (confirmed) {
                                  await controller
                                      .deleteLocalAudioFileAtPath(f.path);
                                  if (mounted) setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        selected: isCurrent,
                        onTap: () async {
                          Navigator.pop(context);
                          await controller.playFile(f);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _triggerParachute() async {
    if (!mounted) return;
    final overlay = Overlay.of(context);

    // Unified: pick random item among verse/quote/inspiration (local pool)
    final item = controller.getRandomSkyDropItem();
    final String title = item['label'] ?? 'Inspiration';
    final String message = item['content'] ?? "Dieu t'aime et t'accompagne.";

    _parachuteEntry?.remove();
    _parachuteEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Barrier to absorb taps behind
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(color: Colors.black.withOpacity(0.08)),
            ),
          ),
          Positioned.fill(
            child: ParachuteDrop(
              title: title,
              message: message,
              onFinished: () {
                _parachuteEntry?.remove();
                _parachuteEntry = null;
              },
              onRefresh: () async {
                final next = controller.getRandomSkyDropItem();
                return {
                  'title': next['label'] ?? 'Inspiration',
                  'message': next['content'] ?? "Dieu t'aime et t'accompagne.",
                };
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_parachuteEntry!);

    // Pulse the heart for the duration of the parachute sequence (~3800ms fall + 250 + 900 + 220 = ~5170ms)
    setState(() => _isHeartPulsing = true);
    Future.delayed(const Duration(milliseconds: 5200), () {
      if (mounted) {
        setState(() => _isHeartPulsing = false);
      }
    });
  }
}

// Removed legacy _roundIconButton in favor of TopBar component

// Removed legacy _GenesisPanel in favor of component VersePanel

// Removed legacy _BottomBarMini in favor of component BottomMiniPlayer
