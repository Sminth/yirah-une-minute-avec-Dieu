import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:one_minute/controllers/home_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});
  final HomeController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  HomeController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Versets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: [
                RadioListTile<VerseMode>(
                  value: VerseMode.fixed,
                  groupValue: controller.verseMode,
                  onChanged: (m) =>
                      controller.setVerseMode(m ?? controller.verseMode),
                  title: const Text('Fixe (Jean 15:4-5)'),
                ),
                RadioListTile<VerseMode>(
                  value: VerseMode.random,
                  groupValue: controller.verseMode,
                  onChanged: (m) =>
                      controller.setVerseMode(m ?? controller.verseMode),
                  title: const Text('Aléatoire (FR)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Son', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  value: controller.audioRandom,
                  onChanged: (v) => controller.setAudioMode(random: v),
                  title: const Text('Aléatoire'),
                  subtitle: Text(controller.audioRandom
                      ? 'Une piste aléatoire parmi vos fichiers locaux'
                      : 'Utiliser une piste fixe'),
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: !controller.audioRandom,
                  leading: const Icon(Icons.music_note),
                  title: Text(
                    controller.fixedAudioPath == null
                        ? 'Choisir une piste fixe'
                        : controller.fixedAudioPath!.split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: !controller.audioRandom &&
                          controller.fixedAudioPath != null
                      ? const Text('Piste fixe sélectionnée')
                      : null,
                  trailing: Icon(Icons.chevron_right, color: scheme.primary),
                  onTap: !controller.audioRandom
                      ? () => _openFixedPicker(context)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Tester la notification (1 min)'),
              onTap: () => controller.sendTestNotification(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Raccourci minuteur personnalisé',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(controller.customQuickDuration == null
                      ? 'Définir un bouton personnalisé'
                      : 'Bouton personnalisé: ${_labelFor(controller.customQuickDuration!)}'),
                  subtitle: const Text(
                      'Ce bouton apparaîtra comme 4ᵉ bouton sur la page d’accueil.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCustomDurationPicker(context),
                ),
                if (controller.customQuickDuration != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => controller.setCustomQuickDuration(null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer le bouton'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFixedPicker(BuildContext context) async {
    final files = await controller.getLocalAudioFiles();
    if (!mounted) return;
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
                leading: const Icon(Icons.folder_open),
                title: const Text('Parcourir mes fichiers...'),
                onTap: () async {
                  final res = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: const ['mp3', 'm4a', 'aac'],
                  );
                  if (res != null && res.files.single.path != null) {
                    await controller.pickFixedAudioPath(res.files.single.path!);
                  }
                  if (mounted) Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aucun fichier audio local disponible.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final f = files[i];
                      final name = f.uri.pathSegments.isNotEmpty
                          ? f.uri.pathSegments.last
                          : f.path.split('/').last;
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(name,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          await controller.pickFixedAudioPath(f.path);
                          if (mounted) Navigator.pop(context);
                        },
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

  Future<void> _openCustomDurationPicker(BuildContext context) async {
    final TextEditingController minCtrl = TextEditingController(
        text:
            (widget.controller.customQuickDuration?.inMinutes ?? 1).toString());
    final TextEditingController secCtrl = TextEditingController(
        text: ((widget.controller.customQuickDuration?.inSeconds ?? 60) % 60)
            .toString());
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Définir la durée',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: secCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Secondes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final int m = int.tryParse(minCtrl.text) ?? 0;
                      final int s = int.tryParse(secCtrl.text) ?? 0;
                      final Duration d = Duration(minutes: m, seconds: s);
                      widget.controller.setCustomQuickDuration(
                          d.inSeconds > 0 ? d : const Duration(minutes: 1));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Valider'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x121FFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }
}
