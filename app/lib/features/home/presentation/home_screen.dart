import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/app_curves.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../../../core/widgets/stagger.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../prompts/domain/prompt.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/prompt_providers.dart';
import '../../prompts/presentation/widgets/widgets.dart';

/// Home: featured card + Trending / Latest / For you tabs over one staggered
/// card list. Pull-to-refresh uses `CupertinoSliverRefreshControl` only
/// (§5 — no Material refresh indicator anywhere in the app).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  bool _firstPaint = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 500) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
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
    final feed = ref.watch(homeFeedProvider);
    final sort = ref.watch(feedSortProvider);
    final featured = ref.watch(featuredPromptProvider);

    // Stagger only the very first paint of the session (§5).
    final staggered = _firstPaint;
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstPaint = false);

    return SafeArea(
      bottom: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => false,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // §5: iOS-style refresh control, never a Material indicator.
            CupertinoSliverRefreshControl(
              onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.sm,
                  AppSpace.screen,
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PromptIndo',
                        style: t.onBackgroundStyle(AppType.title()),
                      ),
                    ),
                    GlassIconButton(
                      icon: Icons.notifications_none_rounded,
                      semanticLabel: 'Notifications',
                      color: t.onBackground,
                      onPressed: () => Navigator.of(context).push(
                        GlassPageRoute<void>(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screen,
                ),
                child: _SortTabs(
                  selected: sort,
                  onChanged: (value) =>
                      ref.read(feedSortProvider.notifier).state = value,
                ),
              ),
            ),
            if (sort == FeedSort.trending && featured.value != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.screen,
                  ),
                  child: FeaturedCard(
                    prompt: featured.value!,
                    onTap: () => _openPrompt(featured.value!.id),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),
            ..._feedSlivers(feed, staggered),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(AsyncValue<FeedState> feed, bool staggered) {
    if (feed.isLoading && !feed.hasValue) {
      return [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.screen),
          sliver: SliverList.list(
            children: [
              GlassShimmer(child: SkeletonCard()),
              SizedBox(height: AppSpace.cardGap),
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
            message: 'Could not load the feed.',
            onRetry: () => ref.read(homeFeedProvider.notifier).refresh(),
          ),
        ),
      ];
    }

    final state = feed.value ?? FeedState.empty;
    if (state.items.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'Nothing here yet',
            message: 'When people publish prompts, they show up here.',
          ),
        ),
      ];
    }

    final cards = <Widget>[];
    for (var i = 0; i < state.items.length; i++) {
      if (i > 0) cards.add(const SizedBox(height: AppSpace.cardGap));
      final prompt = state.items[i];
      cards.add(
        PromptCard(prompt: prompt, onTap: () => _openPrompt(prompt.id)),
      );
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        sliver: SliverList.list(
          children: [
            if (staggered && cards.length <= 8)
              StaggeredEntrance(children: cards)
            else
              ...cards,
            if (state.loadingMore) const LoadMoreSpinner(),
          ],
        ),
      ),
    ];
  }
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({required this.selected, required this.onChanged});

  final FeedSort selected;
  final ValueChanged<FeedSort> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = <(FeedSort, String)>[
      (FeedSort.trending, 'Trending'),
      (FeedSort.latest, 'Latest'),
      (FeedSort.recommended, 'For you'),
    ];

    return GlassContainer(
      borderRadius: 1000,
      padding: const EdgeInsets.all(4),
      showShadow: false,
      child: Row(
        children: [
          for (final (value, label) in tabs)
            Expanded(
              child: _SortTab(
                label: label,
                active: selected == value,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return SpringPress(
      onTap: onTap,
      scaleDown: 0.97,
      child: AnimatedContainer(
        duration: AppMotion.tabPill,
        curve: AppMotion.tabPillCurve,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppType.button(
            color: active ? t.textPrimary : t.textSecondary,
          ),
        ),
      ),
    );
  }
}
