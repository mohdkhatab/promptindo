import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_container.dart';

/// Static legal screens. The same copy is hosted on Firebase Hosting under
/// `/privacy` and `/terms` (see README "Deep links & hosting") so the store
/// listing and the in-app screens always link to identical text.
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
            GlassContainer(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'What we store',
                    body:
                        'PromptIndo stores your display name, username, bio, '
                        'avatar, the prompts you publish, your likes, saves, '
                        'follows and comments. Your email address is stored in '
                        'a separate, non-public record that the app itself '
                        'never reads.',
                  ),
                  _Section(
                    title: 'What we collect automatically',
                    body:
                        'Anonymous view events (deduplicated per device for 24 '
                        'hours) power trending scores. Push tokens are stored '
                        'so we can send notifications you have opted into.',
                  ),
                  _Section(
                    title: 'App Check',
                    body:
                        'The app registers with Google Play Integrity so only '
                        'genuine builds can talk to the backend.',
                  ),
                  _Section(
                    title: 'Your choices',
                    body:
                        'You can delete your account at any time from Settings. '
                        'Deletion removes your profile, prompts, comments and '
                        'uploaded images from storage.',
                  ),
                  _Section(
                    title: 'Contact',
                    body:
                        'Questions? Open a report from any prompt, or email '
                        'the address listed on the Play Store listing.',
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
            GlassContainer(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    title: 'Your account',
                    body:
                        'You are responsible for the activity under your '
                        'account. You must be old enough to consent to these '
                        'terms in your country.',
                  ),
                  _Section(
                    title: 'Your content',
                    body:
                        'You keep ownership of the prompts you publish. You '
                        'grant PromptIndo a licence to display, distribute and '
                        'promote them inside the app.',
                  ),
                  _Section(
                    title: 'Acceptable use',
                    body:
                        'No spam, no illegal content, no harassment, no '
                        'content you do not have the right to share. Reports '
                        'are reviewed by moderators and may lead to removal or '
                        'suspension.',
                  ),
                  _Section(
                    title: 'Moderation',
                    body:
                        'Prompts can be featured, removed or hidden by '
                        'moderators. Repeated violations suspend the account.',
                  ),
                  _Section(
                    title: 'Changes',
                    body:
                        'We will post updates here; continued use after an '
                        'update means you accept the revised terms.',
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
