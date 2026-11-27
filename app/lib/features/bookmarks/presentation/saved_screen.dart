import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/stagger.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/widgets/widgets.dart';
import '../../../core/routing/glass_route.dart';

/// Saved tab: the user's bookmarked prompts in save order.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final saved = ref.watch(savedFeedProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                AppSpace.md,
              ),
              child: Text('Saved', style: t.onBackgroundStyle(AppType.title())),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () => ref.read(savedFeedProvider.notifier).refresh(),
          ),
          if (saved.isLoading && !saved.hasValue)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              sliver: SliverList.list(
                children: [
                  GlassShimmer(child: SkeletonCard()),
                  SizedBox(height: AppSpace.cardGap),
                  GlassShimmer(child: SkeletonCard()),
                ],
              ),
            )
          else if (saved.hasError)
            SliverToBoxAdapter(
              child: ErrorView(
                message: 'Could not load saved prompts.',
                onRetry: () => ref.read(savedFeedProvider.notifier).refresh(),
              ),
            )
          else if ((saved.value ?? const []).isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'Nothing saved yet',
                message: 'Tap the bookmark on any prompt to keep it here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              sliver: SliverList.list(
                children: [
                  StaggeredEntrance(
                    animate: false,
                    children: [
                      for (var i = 0; i < saved.value!.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == saved.value!.length - 1
                                ? 0
                                : AppSpace.cardGap,
                          ),
                          child: PromptCard(
                            prompt: saved.value![i],
                            onTap: () => Navigator.of(context).push(
                              GlassPageRoute<void>(
                                builder: (_) => PromptDetailsScreen(
                                  promptId: saved.value![i].id,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
