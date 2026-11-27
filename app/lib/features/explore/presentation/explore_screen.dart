import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/stagger.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/widgets/widgets.dart';

/// Explore: search over title/tags plus the latest public prompts.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _debounceKey = '';

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Tiny debounce so we don't fire a query per keystroke.
    final key = value.trim();
    if (key == _debounceKey) return;
    _debounceKey = key;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _debounceKey != key) return;
      ref.read(searchQueryProvider.notifier).state = key;
    });
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
    final query = ref.watch(searchQueryProvider);
    final searching = query.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.sm,
                AppSpace.screen,
                AppSpace.md,
              ),
              child: Text(
                'Explore',
                style: t.onBackgroundStyle(AppType.title()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: GlassInput(
                controller: _search,
                hint: 'Search prompts, tags or models',
                prefixIcon: Icons.search_rounded,
                onChanged: _onQueryChanged,
                suffix: query.isEmpty
                    ? null
                    : GlassIconButton(
                        icon: Icons.close_rounded,
                        size: 24,
                        iconSize: 14,
                        onPressed: () {
                          _search.clear();
                          _onQueryChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (searching) ..._searchSlivers() else ..._exploreSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<Widget> _searchSlivers() {
    final results = ref.watch(searchFeedProvider);

    if (results.isLoading && !results.hasValue) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpace.screen),
          sliver: SliverList.list(
            children: [
              GlassShimmer(child: SkeletonCard(withThumbnail: false)),
              SizedBox(height: AppSpace.cardGap),
              GlassShimmer(child: SkeletonCard(withThumbnail: false)),
            ],
          ),
        ),
      ];
    }
    if (results.hasError) {
      return [
        SliverToBoxAdapter(
          child: ErrorView(
            message: 'Search failed. Try again.',
            onRetry: () => ref.read(searchFeedProvider.notifier).refresh(),
          ),
        ),
      ];
    }
    final items = results.value ?? const [];
    if (items.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matches',
            message: 'Try a different keyword or tag.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        sliver: SliverList.list(
          children: [
            SectionLabel('Results'),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.cardGap),
              PromptCard(
                prompt: items[i],
                onTap: () => _openPrompt(items[i].id),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _exploreSlivers() {
    final feed = ref.watch(categoryFeedProvider);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.lg,
            AppSpace.screen,
            AppSpace.sm,
          ),
          child: SectionLabel('Latest prompts'),
        ),
      ),
      ..._latestFeed(feed),
    ];
  }

  List<Widget> _latestFeed(AsyncValue<FeedState> feed) {
    if (feed.isLoading && !feed.hasValue) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
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
            title: 'No prompts yet',
            message: 'Be the first to publish one.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        sliver: SliverList.list(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.cardGap),
              PromptCard(
                prompt: items[i],
                onTap: () => _openPrompt(items[i].id),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
