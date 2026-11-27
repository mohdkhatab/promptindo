import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/backend_providers.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../../prompts/presentation/prompt_details_screen.dart';
import '../domain/app_notification.dart';
import 'notification_providers.dart';

/// Notifications inbox: everything the Cloud Functions wrote for this user.
/// Marking read is a plain `is_read` update (recipient-only, per rules).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) => switch (type) {
    'like' => Icons.favorite_rounded,
    'comment' => Icons.chat_bubble_outline_rounded,
    'follow' => Icons.person_add_alt_rounded,
    'copy' => Icons.content_copy_rounded,
    'feature' => Icons.workspace_premium_rounded,
    _ => Icons.notifications_none_rounded,
  };

  String _messageFor(AppNotification n) => switch (n.type) {
    'like' => '@${n.actorUsername} liked ${_title(n)}',
    'comment' => '@${n.actorUsername} commented on ${_title(n)}',
    'follow' => '@${n.actorUsername} started following you',
    'copy' => '@${n.actorUsername} copied ${_title(n)}',
    'feature' => '${_title(n)} was featured',
    _ => 'You have a new notification',
  };

  String _title(AppNotification n) =>
      (n.data['title'] ?? '').isEmpty ? 'your prompt' : '"${n.data['title']}"';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GlassHeader(
                title: 'Notifications',
                trailing: [
                  GlassTextButton(
                    label: 'Mark all read',
                    color: t.onBackground,
                    onPressed: () =>
                        ref.read(notificationRepositoryProvider).markAllRead(),
                  ),
                ],
              ),
            ),
            if (notifications.isLoading && !notifications.hasValue)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screen,
                ),
                sliver: SliverList.list(
                  children: [
                    GlassShimmer(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 64,
                        radius: 22,
                      ),
                    ),
                    SizedBox(height: AppSpace.cardGap),
                    GlassShimmer(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 64,
                        radius: 22,
                      ),
                    ),
                  ],
                ),
              )
            else if (notifications.hasError)
              SliverToBoxAdapter(
                child: ErrorView(
                  message: 'Could not load notifications.',
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
              )
            else if ((notifications.value ?? const []).isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'All caught up',
                  message: 'Likes, comments and follows will show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screen,
                ),
                sliver: SliverList.separated(
                  itemCount: notifications.value!.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.cardGap),
                  itemBuilder: (context, index) {
                    final item = notifications.value![index];
                    return _NotificationTile(
                      item: item,
                      icon: _iconFor(item.type),
                      message: _messageFor(item),
                      onTap: () async {
                        if (!item.isRead) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(item.id);
                        }
                        final promptId = item.promptId;
                        if (promptId == null || promptId.isEmpty) return;
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          GlassPageRoute<void>(
                            builder: (_) =>
                                PromptDetailsScreen(promptId: promptId),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final AppNotification item;
  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final unread = item.isUnread;

    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.textPrimary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: t.textPrimary),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: t.onGlass(AppType.body())),
                  const SizedBox(height: 4),
                  Text(
                    item.createdAt == null ? '' : timeAgo(item.createdAt!),
                    style: t.onGlassMuted(AppType.micro()),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: AppSpace.sm, top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A84FF),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
