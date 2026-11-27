import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/services/deep_links.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/spring_press.dart';
import '../../comments/presentation/comment_list.dart';
import '../../comments/presentation/comments_sheet.dart';
import '../../profile/presentation/report_sheet.dart';
import 'prompt_providers.dart';

/// Prompt details: full prompt content with copy, stats, tags, actions and
/// the comment thread. Opening the screen fires `recordView` exactly once
/// (the callable dedupes per viewer for 24h on top of this local guard).
class PromptDetailsScreen extends ConsumerStatefulWidget {
  const PromptDetailsScreen({super.key, required this.promptId});

  final String promptId;

  @override
  ConsumerState<PromptDetailsScreen> createState() =>
      _PromptDetailsScreenState();
}

class _PromptDetailsScreenState extends ConsumerState<PromptDetailsScreen> {
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_recordView);
  }

  Future<void> _recordView() async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    final viewed = ref.read(viewedPromptIdsProvider);
    if (viewed.contains(widget.promptId)) return;
    ref.read(viewedPromptIdsProvider.notifier).state = {
      ...viewed,
      widget.promptId,
    };
    try {
      await ref.read(interactionRepositoryProvider).recordView(widget.promptId);
    } catch (_) {
      // Counting a view is best-effort — never block the screen on it.
    }
  }

  Future<void> _copyPrompt(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    GlassToast.show(context, 'Prompt copied');
    try {
      await ref.read(interactionRepositoryProvider).recordCopy(widget.promptId);
    } catch (_) {
      // Copy counting is best-effort; the clipboard already succeeded.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final async = ref.watch(promptProvider(widget.promptId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: async.when(
        loading: () => const SafeArea(
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => SafeArea(
          child: ErrorView(
            message: 'This prompt could not be loaded.',
            onRetry: () => ref.invalidate(promptProvider(widget.promptId)),
          ),
        ),
        data: (prompt) {
          if (prompt == null) {
            return const SafeArea(
              child: ErrorView(message: 'This prompt no longer exists.'),
            );
          }
          final liked = ref.watch(
            interactionsProvider.select((s) => s.liked.contains(prompt.id)),
          );
          final saved = ref.watch(
            interactionsProvider.select(
              (s) => s.bookmarked.contains(prompt.id),
            ),
          );
          final following = ref.watch(
            interactionsProvider.select(
              (s) => s.following.contains(prompt.creatorId),
            ),
          );
          final uid = ref.watch(currentUidProvider);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GlassBackButton(),
                      const Spacer(),
                      GlassIconButton(
                        icon: Icons.ios_share_rounded,
                        semanticLabel: 'Share',
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${prompt.title} — via PromptIndo\n${promptShareUrl(prompt.id)}\n\n${prompt.promptContent}',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      GlassIconButton(
                        icon: Icons.flag_outlined,
                        semanticLabel: 'Report prompt',
                        onPressed: () => showReportSheet(
                          context,
                          ref: ref,
                          targetType: 'prompt',
                          targetId: prompt.id,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (prompt.thumbnailUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: AppSpace.cardRadius,
                        child: CachedNetworkImage(
                          imageUrl: prompt.thumbnailUrl,
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.cover,
                          memCacheWidth: 1000,
                          fadeInDuration: const Duration(milliseconds: 150),
                          errorWidget: (_, _, _) => const SizedBox(height: 0),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    prompt.title,
                    style: t.onBackgroundStyle(AppType.title()),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // Author row with follow.
                  SpringPress(
                    behavior: HitTestBehavior.opaque,
                    onTap: prompt.creatorId == uid || uid == null
                        ? null
                        : () => ref
                              .read(interactionsProvider.notifier)
                              .toggleFollow(uid, prompt.creatorId),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: t.onBackground.withValues(
                            alpha: 0.08,
                          ),
                          backgroundImage: prompt.creatorAvatar.isEmpty
                              ? null
                              : NetworkImage(prompt.creatorAvatar),
                          child: prompt.creatorAvatar.isEmpty
                              ? Text(
                                  initialsOf(prompt.creatorUsername),
                                  style: t.onBackgroundMuted(AppType.micro()),
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@${prompt.creatorUsername}',
                                style: t.onBackgroundStyle(AppType.subtitle()),
                              ),
                              Text(
                                prompt.createdAt == null
                                    ? ''
                                    : timeAgo(prompt.createdAt!),
                                style: t.onBackgroundMuted(AppType.micro()),
                              ),
                            ],
                          ),
                        ),
                        if (uid != null && prompt.creatorId != uid)
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
                                .toggleFollow(uid, prompt.creatorId),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (prompt.description.isNotEmpty) ...[
                    Text(
                      prompt.description,
                      style: t.onBackgroundStyle(AppType.body()),
                    ),
                    const SizedBox(height: AppSpace.lg),
                  ],
                  // Stats row.
                  Row(
                    children: [
                      _StatPill(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        label: formatCount(prompt.likeCount + (liked ? 1 : 0)),
                        color: liked ? const Color(0xFFFF3B30) : t.onBackground,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      _StatPill(
                        icon: Icons.content_copy_rounded,
                        label: formatCount(prompt.copyCount),
                        color: t.onBackground,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      _StatPill(
                        icon: Icons.visibility_outlined,
                        label: formatCount(prompt.viewCount),
                        color: t.onBackground,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      _StatPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: formatCount(prompt.commentCount),
                        color: t.onBackground,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  // The prompt itself, in mono.
                  GlassContainer(
                    padding: const EdgeInsets.all(AppSpace.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PROMPT',
                                style: t.onGlassMuted(AppType.micro()),
                              ),
                            ),
                            if (prompt.aiModel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: t.textPrimary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  prompt.aiModel,
                                  style: t.onGlassMuted(AppType.badge()),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          prompt.promptContent,
                          style: AppType.badge(
                            color: t.textPrimary,
                            fontSize: 14,
                          ).copyWith(height: 1.5),
                        ),
                        const SizedBox(height: AppSpace.md),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                label: 'Copy prompt',
                                icon: Icons.content_copy_rounded,
                                expand: true,
                                onPressed: () =>
                                    _copyPrompt(prompt.promptContent),
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            GlassIconButton(
                              icon: saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 48,
                              iconSize: 20,
                              onPressed: uid == null
                                  ? null
                                  : () => ref
                                        .read(interactionsProvider.notifier)
                                        .toggleBookmark(uid, prompt.id),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            GlassIconButton(
                              icon: liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 48,
                              iconSize: 20,
                              color: liked ? const Color(0xFFFF3B30) : null,
                              onPressed: uid == null
                                  ? null
                                  : () => ref
                                        .read(interactionsProvider.notifier)
                                        .toggleLike(uid, prompt.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (prompt.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final tag in prompt.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: t.onBackground.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(1000),
                            ),
                            child: Text(
                              '#$tag',
                              style: t.onBackgroundMuted(AppType.caption()),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comments',
                          style: t.onBackgroundStyle(AppType.subtitle()),
                        ),
                      ),
                      GlassTextButton(
                        label: 'Open sheet',
                        color: t.onBackground,
                        onPressed: () => showCommentsSheet(context, prompt.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  CommentComposer(promptId: prompt.id),
                  const SizedBox(height: AppSpace.md),
                  CommentList(promptId: prompt.id),
                  const SizedBox(height: AppSpace.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.onBackground.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppType.caption(color: color)),
        ],
      ),
    );
  }
}
