import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.favorite_rounded, color: scheme.primary, size: 56),
              const SizedBox(height: 12),
              Text(
                'Yirah – Une minute avec Dieu',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Yirah t'aide à te rappeler de penser à Dieu, ne serait-ce qu'une minute, au milieu de tes occupations. À chaque heure jumelle, ou quand tu veux, prends un instant pour parler à Papa et te recentrer.",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 14),
              _FeatureRow(
                icon: Icons.timer_outlined,
                text: '1, 5 ou 10 minutes: rien qu’un instant.',
              ),
              const SizedBox(height: 8),
              _FeatureRow(
                icon: Icons.menu_book_outlined,
                text: 'Verset: fixe (Jean 15:4-5) ou aléatoire.',
              ),
              const SizedBox(height: 8),
              _FeatureRow(
                icon: Icons.library_music_outlined,
                text: 'Musique chrétienne en fond, mini‑lecteur indépendant.',
              ),
              const SizedBox(height: 8),
              _FeatureRow(
                icon: Icons.folder_open_outlined,
                text: 'Ajoute tes morceaux locaux depuis le téléphone.',
              ),
              const SizedBox(height: 24),
              Text(
                  'Yirah est un projet personnel, développé par un chrétien lambda.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _openFeedbackSheet(context),
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('Laisser un feedback'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          child: Text(
            'Dieu t’aime',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  void _openFeedbackSheet(BuildContext context) {
    final TextEditingController controller = TextEditingController();
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
              Text('Vos idées et pistes d’amélioration',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Partagez ici vos feedbacks...',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x121FFFFFF)
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
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
                    onPressed: () async {
                      final String body = controller.text.trim().isEmpty
                          ? 'Vos idées / suggestions / pistes d’amélioration :'
                          : controller.text.trim();
                      final Uri mailto = Uri(
                        scheme: 'mailto',
                        path: 'virtus225one@gmail.com',
                        query: Uri.encodeQueryComponent(
                          'subject=Feedback Yirah&body=$body',
                        ),
                      );
                      if (await canLaunchUrl(mailto)) {
                        await launchUrl(mailto);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
