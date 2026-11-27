import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../../../core/widgets/stagger.dart';
import '../../categories/presentation/category_providers.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/widgets/widgets.dart';
import '../../categories/domain/category.dart';

/// Explore: search (tag + title prefix) above a category grid, with the
/// selected category's feed underneath.
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
    final categories = ref.watch(categoriesProvider);
    final selected = ref.watch(exploreCategoryProvider);
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
          child: SectionLabel(
            'Browse by category',
            trailing: selected == null
                ? null
                : GlassTextButton(
                    label: 'Clear',
                    color: GlassTokens.of(context).onBackground,
                    onPressed: () => _select(null),
                  ),
          ),
        ),
      ),
      if (categories.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.screen),
            child: GlassShimmer(
              child: SkeletonBox(
                width: double.infinity,
                height: 96,
                radius: 22,
              ),
            ),
          ),
        )
      else if (categories.hasError)
        SliverToBoxAdapter(
          child: ErrorView(
            message: 'Categories unavailable.',
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpace.cardGap,
            crossAxisSpacing: AppSpace.cardGap,
            childAspectRatio: 1.6,
            children: [
              for (final category in categories.value ?? const <Category>[])
                _CategoryTile(
                  category: category,
                  active: selected == category.id,
                  onTap: () =>
                      _select(selected == category.id ? null : category.id),
                ),
            ],
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
      if (selected != null) ..._selectedFeed(feed),
    ];
  }

  void _select(String? categoryId) {
    ref.read(exploreCategoryProvider.notifier).state = categoryId;
  }

  List<Widget> _selectedFeed(AsyncValue<FeedState> feed) {
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
            message: 'Could not load this category.',
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
            icon: Icons.category_outlined,
            title: 'No prompts in this category yet',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
        sliver: SliverList.list(
          children: [
            SectionLabel('Prompts in this category'),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.active,
    required this.onTap,
  });

  final Category category;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpace.md),
        fillColor: active ? const Color(0xE6FFFFFF) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: AppSpace.xs),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.onGlass(AppType.subtitle()),
            ),
            Text(
              category.promptCount > 0
                  ? '${category.promptCount} prompts'
                  : 'Browse',
              style: t.onGlassMuted(AppType.micro()),
            ),
          ],
        ),
      ),
    );
  }
}
