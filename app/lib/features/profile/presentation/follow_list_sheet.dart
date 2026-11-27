import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/glass_route.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_sheets.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../../auth/domain/app_user.dart';
import '../presentation/profile_screen.dart';
import '../presentation/profile_providers.dart';

enum FollowListType { followers, following }

/// Bottom sheet listing a profile's followers / following, each row opening
/// that person's profile (pushed as a new route).
Future<void> showFollowListSheet(
  BuildContext context, {
  required String uid,
  required String title,
  required FollowListType type,
}) {
  return showGlassBottomSheet(
    context,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.62,
      child: _FollowListSheet(uid: uid, title: title, type: type),
    ),
  );
}

class _FollowListSheet extends ConsumerWidget {
  const _FollowListSheet({
    required this.uid,
    required this.title,
    required this.type,
  });

  final String uid;
  final String title;
  final FollowListType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final repo = ref.watch(followRepositoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: t.onGlass(AppType.subtitle())),
              ),
              GlassIconButton(
                icon: Icons.close_rounded,
                size: 32,
                iconSize: 17,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: type == FollowListType.followers
                ? repo.followerIds(uid)
                : repo.followingIds(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(message: 'Could not load this list.');
              }
              if (!snapshot.hasData) {
                return const Column(
                  children: [
                    GlassShimmer(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 60,
                        radius: 22,
                      ),
                    ),
                    SizedBox(height: AppSpace.md),
                    GlassShimmer(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 60,
                        radius: 22,
                      ),
                    ),
                  ],
                );
              }
              final ids = snapshot.data!;
              if (ids.isEmpty) {
                return EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: type == FollowListType.followers
                      ? 'No followers yet'
                      : 'Not following anyone',
                );
              }
              return ListView.separated(
                itemCount: ids.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (context, index) {
                  final person = ref
                      .watch(otherProfileProvider(ids[index]))
                      .value;
                  return _PersonRow(
                    uid: ids[index],
                    user: person,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        GlassPageRoute<void>(
                          builder: (_) => ProfileScreen(uid: ids[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.uid,
    required this.user,
    required this.onTap,
  });

  final String uid;
  final AppUser? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final name = user?.name.isNotEmpty == true ? user!.name : '@$uid';
    final username = user?.username ?? '';

    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: t.textPrimary.withValues(alpha: 0.08),
              backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                  ? NetworkImage(user!.avatarUrl)
                  : null,
              child: (user?.avatarUrl.isNotEmpty ?? false)
                  ? null
                  : Text(initialsOf(name), style: t.onGlass(AppType.micro())),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.onGlass(AppType.body())),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: t.onGlassMuted(AppType.caption()),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}
