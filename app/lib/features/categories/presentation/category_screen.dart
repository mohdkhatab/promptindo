import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/stagger.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/widgets/widgets.dart';
import '../domain/category.dart';

/// One category's feed, pushed from the Home chips or Explore grid.
///
/// Uses the shared `exploreCategoryProvider` target (the Explore tab simply
/// reflects whatever category is active) so no `family` notifier is needed.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.category});

  final Category category;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    // Select this category for the shared feed target.
    Future.microtask(
      () =>
          ref.read(exploreCategoryProvider.notifier).state = widget.category.id,
    );
  }

  void _openPrompt(String promptId) {
    Navigator.of(context).push(
      GlassPageRoute<void>(
        builder: (_) => PromptDetailsScreen(promptId: promptId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final feed = ref.watch(categoryFeedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GlassHeader(
                title: widget.category.name,
                trailing: [
                  GlassIconButton(
                    icon: Icons.auto_awesome_outlined,
                    semanticLabel: 'Category',
                    color: t.onBackground,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            if (widget.category.description.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screen,
                    0,
                    AppSpace.screen,
                    AppSpace.lg,
                  ),
                  child: Text(
                    '${widget.category.icon}  ${widget.category.description}',
                    style: t.onBackgroundMuted(AppType.body()),
                  ),
                ),
              ),
            ..._feedSlivers(feed),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(AsyncValue<FeedState> feed) {
    if (feed.isLoading && !feed.hasValue) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.screen),
          sliver: SliverList.list(
            children: [
              GlassShimmer(child: SkeletonCard()),
              SizedBox(height: AppSpace.cardGap),
              GlassShimmer(child: SkeletonCard()),
            ],
          ),
        ),
      ];
    }
    if (feed.hasError) {
      return [
        SliverToBoxAdapter(
          child: ErrorView(
            message: 'Could not load prompts.',
            onRetry: () => ref.read(categoryFeedProvider.notifier).refresh(),
          ),
        ),
      ];
    }
    final items = (feed.value ?? FeedState.empty).items;
    if (items.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'No prompts here yet',
            message: 'Be the first to publish one in this category.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        sliver: SliverList.list(
          children: [
            StaggeredEntrance(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : AppSpace.cardGap,
                    ),
                    child: PromptCard(
                      prompt: items[i],
                      onTap: () => _openPrompt(items[i].id),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}
