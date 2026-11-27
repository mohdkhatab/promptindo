import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/spring_press.dart';
import '../../domain/prompt.dart';

/// Large "featured prompt" card at the top of the trending feed.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.prompt, this.onTap});

  final Prompt prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);

    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpace.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 16,
                  color: t.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'FEATURED THIS WEEK',
                  style: t.onGlassMuted(AppType.micro()),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              prompt.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.onGlass(AppType.title()),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              prompt.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.onGlassMuted(AppType.body()),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '@${prompt.creatorUsername}',
                    overflow: TextOverflow.ellipsis,
                    style: t.onGlassMuted(AppType.caption()),
                  ),
                ),
                GlassButton(
                  label: 'Open',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  onPressed: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
