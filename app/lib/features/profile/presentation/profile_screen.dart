import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../../../core/widgets/stagger.dart';
import '../../auth/domain/app_user.dart';
import '../../prompts/presentation/feed_controller.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../../prompts/presentation/widgets/widgets.dart';
import '../../settings/presentation/settings_screen.dart';
import 'follow_list_sheet.dart';
import 'profile_providers.dart';

/// Profile: header (avatar, handle, bio, stats), follow/edit actions and the
/// user's prompt list. Works for both "me" and "someone else" — the uid comes
/// from `profileTargetUidProvider`, which the caller sets before pushing.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.uid});

  /// When null the current signed-in user is shown (the Saved/Profile tab).
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(currentUidProvider);
    final targetUid = uid ?? currentUid;

    // Keep the shared feed target pointed at whoever we're showing.
    if (targetUid != null && targetUid.isNotEmpty) {
      final selected = ref.watch(profileTargetUidProvider);
      if (selected != targetUid) {
        Future.microtask(
          () => ref.read(profileTargetUidProvider.notifier).state = targetUid,
        );
      }
    }

    final isOwn = targetUid != null && targetUid == currentUid;
    final profile = ref.watch(currentUserProvider);
    final other = uid == null || uid == currentUid
        ? null
        : ref.watch(otherProfileProvider(uid!));

    final user = isOwn ? profile.value : other?.value;
    final loading = isOwn ? profile.isLoading : (other?.isLoading ?? true);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          if (loading && user == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.screen),
                child: GlassShimmer(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 180,
                    radius: 22,
                  ),
                ),
              ),
            )
          else if (user == null)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.person_outline_rounded,
                title: 'Profile not found',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: _ProfileHeader(
                user: user,
                isOwn: isOwn,
                onSettings: isOwn
                    ? () => Navigator.of(context).push(
                        GlassPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      )
                    : null,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.lg,
                  AppSpace.screen,
                  AppSpace.sm,
                ),
                child: SectionLabel(isOwn ? 'Your prompts' : 'Prompts'),
              ),
            ),
            ..._promptSlivers(ref, context),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  List<Widget> _promptSlivers(WidgetRef ref, BuildContext context) {
    final feed = ref.watch(profileFeedProvider);

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
            onRetry: () => ref.read(profileFeedProvider.notifier).refresh(),
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
            message: 'Publish one from the Create tab.',
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
              animate: false,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : AppSpace.cardGap,
                    ),
                    child: PromptCard(
                      prompt: items[i],
                      onTap: () => Navigator.of(context).push(
                        GlassPageRoute<void>(
                          builder: (_) =>
                              PromptDetailsScreen(promptId: items[i].id),
                        ),
                      ),
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

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.user,
    required this.isOwn,
    required this.onSettings,
  });

  final AppUser user;
  final bool isOwn;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final currentUid = ref.watch(currentUidProvider);
    final following = ref.watch(
      interactionsProvider.select((s) => s.following.contains(user.uid)),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpace.screen),
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: t.textPrimary.withValues(alpha: 0.08),
                  backgroundImage: user.avatarUrl.isEmpty
                      ? null
                      : NetworkImage(user.avatarUrl),
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          initialsOf(
                            user.name.isEmpty ? user.username : user.name,
                          ),
                          style: t.onGlass(AppType.title()),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? '—' : user.name,
                        style: t.onGlass(AppType.title()),
                      ),
                      Text(
                        '@${user.username}',
                        style: t.onGlassMuted(AppType.body()),
                      ),
                    ],
                  ),
                ),
                if (isOwn)
                  GlassIconButton(
                    icon: Icons.settings_outlined,
                    semanticLabel: 'Settings',
                    onPressed: onSettings,
                  )
                else if (currentUid != null)
                  GlassButton(
                    label: following ? 'Following' : 'Follow',
                    variant: following
                        ? GlassButtonVariant.secondary
                        : GlassButtonVariant.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    onPressed: () => ref
                        .read(interactionsProvider.notifier)
                        .toggleFollow(currentUid, user.uid),
                  ),
              ],
            ),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              Text(user.bio, style: t.onGlass(AppType.body())),
            ],
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                _Metric(label: 'PROMPTS', value: user.promptCount, onTap: null),
                _Metric(
                  label: 'FOLLOWERS',
                  value: user.followerCount,
                  onTap: () => showFollowListSheet(
                    context,
                    uid: user.uid,
                    title: 'Followers',
                    type: FollowListType.followers,
                  ),
                ),
                _Metric(
                  label: 'FOLLOWING',
                  value: user.followingCount,
                  onTap: () => showFollowListSheet(
                    context,
                    uid: user.uid,
                    title: 'Following',
                    type: FollowListType.following,
                  ),
                ),
                _Metric(
                  label: 'LIKES',
                  value: user.totalLikesReceived,
                  onTap: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Expanded(
      child: SpringPress(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatCount(value), style: t.onGlass(AppType.subtitle())),
              Text(label, style: t.onGlassMuted(AppType.micro())),
            ],
          ),
        ),
      ),
    );
  }
}
