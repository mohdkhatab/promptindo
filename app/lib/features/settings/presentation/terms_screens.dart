import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_container.dart';

/// In-app summaries of the public legal pages at
/// https://www.promptindo.app/privacy and /terms.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.screen),
          children: [
            GlassHeader(title: 'Privacy Policy'),
            const SizedBox(height: AppSpace.md),
            const Text(
              'Last updated: 27 November 2026. The full policy is published at '
              'www.promptindo.app/privacy.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: AppSpace.md),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'What we collect',
                    body:
                        'Your email address, display name, username, bio, '
                        'avatar, prompts, comments, likes, saves, follows, '
                        'reports, and the cover images you upload. We also store '
                        'push tokens (if you enable notifications), a random '
                        '24-hour view identifier for trending, and moderation '
                        'records for reports.',
                  ),
                  _Section(
                    title: 'How we use it',
                    body:
                        'To sign you in, show your public profile and prompts, '
                        'power search/trending/saved lists, deliver the '
                        'notifications you enable, review reports, and keep the '
                        'service reliable. We do not sell your data and we do '
                        'not show advertising.',
                  ),
                  _Section(
                    title: 'What is public',
                    body:
                        'Your email is never public. Your name, username, bio, '
                        'avatar and published prompts are public. Private and '
                        'unlisted prompts are restricted to you (and moderators '
                        'for safety).',
                  ),
                  _Section(
                    title: 'Where it is stored',
                    body:
                        'Supabase handles authentication and the database. '
                        'Appwrite stores new post cover images. Vercel hosts the '
                        'website/API. Firebase Cloud Messaging delivers push '
                        'notifications. Google Sign-In is optional.',
                  ),
                  _Section(
                    title: 'Deletion and retention',
                    body:
                        'Settings → Delete account calls the backend, removes '
                        'your media folders, deletes your auth user, and cascades '
                        'to your profile, prompts, comments, likes, saves, '
                        'follows, notifications and tokens. Deleted prompts also '
                        'remove their Appwrite images. Security logs and '
                        'encrypted backups may persist for up to 30 days.',
                  ),
                  _Section(
                    title: 'Children',
                    body:
                        'PromptIndo is not directed at children under 13 and we '
                        'do not knowingly collect their data.',
                  ),
                  _Section(
                    title: 'Contact',
                    body:
                        'Privacy: privacy@promptindo.app\n'
                        'Support: support@promptindo.app',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.screen),
          children: [
            GlassHeader(title: 'Terms of Service'),
            const SizedBox(height: AppSpace.md),
            const Text(
              'Last updated: 27 November 2026. The full terms are published at '
              'www.promptindo.app/terms.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: AppSpace.md),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'Your account',
                    body:
                        'You must be at least 13 and provide accurate '
                        'information. Keep your password secure; you are '
                        'responsible for activity under your account. Do not '
                        'create multiple accounts to evade moderation.',
                  ),
                  _Section(
                    title: 'Your content',
                    body:
                        'You keep ownership of the prompts, comments and images '
                        'you publish. You grant PromptIndo a non-exclusive, '
                        'worldwide licence to host, display, distribute and '
                        'promote that content inside the app and on share pages. '
                        'Only post content you have the right to share.',
                  ),
                  _Section(
                    title: 'Acceptable use',
                    body:
                        'No spam, scams, malware, harassment, hate speech, '
                        'sexual content involving minors, or content that '
                        'infringes someone else’s rights. No scraping, bulk '
                        'harvesting, or attempts to bypass access controls.',
                  ),
                  _Section(
                    title: 'AI outputs',
                    body:
                        'Prompts and model outputs can be inaccurate or '
                        'unsuitable. Review outputs before relying on them, '
                        'especially for legal, medical, financial or '
                        'safety-critical decisions.',
                  ),
                  _Section(
                    title: 'Moderation',
                    body:
                        'Anyone can report content. We may hide, remove or '
                        'restrict content and accounts that break these terms. '
                        'Serious or repeated violations can lead to a ban. '
                        'Appeals: support@promptindo.app.',
                  ),
                  _Section(
                    title: 'Third-party services',
                    body:
                        'Supabase, Appwrite, Vercel, Firebase Cloud Messaging '
                        'and Google Sign-In help run the app and have their own '
                        'terms. Links to third-party sites or models are not '
                        'controlled by PromptIndo.',
                  ),
                  _Section(
                    title: 'Deletion and termination',
                    body:
                        'You can delete your account at any time from Settings. '
                        'We may suspend or terminate accounts that breach these '
                        'terms or create risk for the community. The service is '
                        'provided “as is”; liability is limited to the extent '
                        'permitted by law.',
                  ),
                  _Section(
                    title: 'Changes and contact',
                    body:
                        'We may update these terms as the product evolves. '
                        'Material changes will be announced in the app. '
                        'Questions: support@promptindo.app.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: t.onGlass(AppType.micro())),
          const SizedBox(height: AppSpace.xs),
          Text(body, style: t.onGlass(AppType.body())),
        ],
      ),
    );
  }
}
