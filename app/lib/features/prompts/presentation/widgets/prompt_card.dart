import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/app_curves.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/spring_press.dart';
import '../../../comments/presentation/comments_sheet.dart';
import '../../domain/prompt.dart';

/// Feed card (§6): glass panel, thumbnail with Hero, title with Hero, author
/// row, AI-model badge and the like/bookmark/copy stat row. Every card in
/// home/explore/category/profile/saved is this one widget.
class PromptCard extends ConsumerWidget {
  const PromptCard({super.key, required this.prompt, this.onTap});

  final Prompt prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final interactions = ref.watch(interactionsProvider);
    final liked = interactions.liked.contains(prompt.id);

    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GlassContainer(
        padding: prompt.thumbnailUrl.isEmpty
            ? const EdgeInsets.all(AppSpace.cardPadding)
            : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt.thumbnailUrl.isNotEmpty) _Thumb(prompt: prompt),
            Padding(
              padding: prompt.thumbnailUrl.isEmpty
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(AppSpace.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          prompt.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.onGlass(AppType.subtitle()),
                        ),
                      ),
                      if (prompt.isFeatured) ...[
                        const SizedBox(width: AppSpace.sm),
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 18,
                          color: t.textSecondary,
                        ),
                      ],
                    ],
                  ),
                  if (prompt.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      prompt.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.onGlassMuted(AppType.body()),
                    ),
                  ],
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: t.textPrimary.withValues(alpha: 0.08),
                        backgroundImage: prompt.creatorAvatar.isEmpty
                            ? null
                            : NetworkImage(prompt.creatorAvatar),
                        child: prompt.creatorAvatar.isEmpty
                            ? Text(
                                initialsOf(prompt.creatorUsername),
                                style: t.onGlass(AppType.micro()),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Flexible(
                        child: Text(
                          '@${prompt.creatorUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.onGlassMuted(AppType.caption()),
                        ),
                      ),
                      const Spacer(),
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
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      _Stat(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        color: liked
                            ? const Color(0xFFFF3B30)
                            : t.textSecondary,
                        value: prompt.likeCount,
                      ),
                      const SizedBox(width: AppSpace.lg),
                      _Stat(
                        icon: Icons.content_copy_rounded,
                        color: t.textSecondary,
                        value: prompt.copyCount,
                      ),
                      const SizedBox(width: AppSpace.lg),
                      _Stat(
                        icon: Icons.visibility_outlined,
                        color: t.textSecondary,
                        value: prompt.viewCount,
                      ),
                      const Spacer(),
                      LikeButton(promptId: prompt.id, count: prompt.likeCount),
                      const SizedBox(width: AppSpace.sm),
                      BookmarkButton(promptId: prompt.id),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.prompt});

  final Prompt prompt;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SizedBox(
        width: double.infinity,
        height: 168,
        child: CachedNetworkImage(
          imageUrl: prompt.thumbnailUrl,
          fit: BoxFit.cover,
          memCacheWidth: 720,
          fadeInDuration: const Duration(milliseconds: 150),
          errorWidget: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(formatCount(value), style: AppType.caption(color: color)),
      ],
    );
  }
}

/// Like control — optimistic toggle with the spec's easeOutBack pop
/// (scale 1 → 1.3 → 1 over 350ms).
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.promptId, required this.count});

  final String promptId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final liked = ref.watch(
      interactionsProvider.select((s) => s.liked.contains(promptId)),
    );

    return _PopButton(
      active: liked,
      activeColor: const Color(0xFFFF3B30),
      iconOn: Icons.favorite,
      iconOff: Icons.favorite_border,
      semanticLabel: liked ? 'Unlike prompt' : 'Like prompt',
      onTap: uid == null
          ? null
          : () async {
              try {
                await ref
                    .read(interactionsProvider.notifier)
                    .toggleLike(uid, promptId);
              } catch (_) {
                // Reverted by the notifier — the card snaps back.
              }
            },
    );
  }
}

/// Bookmark control — easeOutCubic fill over 250ms.
class BookmarkButton extends ConsumerWidget {
  const BookmarkButton({
    super.key,
    required this.promptId,
    this.showLabel = false,
  });

  final String promptId;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final saved = ref.watch(
      interactionsProvider.select((s) => s.bookmarked.contains(promptId)),
    );

    return _PopButton(
      active: saved,
      activeColor: null,
      iconOn: Icons.bookmark,
      iconOff: Icons.bookmark_border,
      semanticLabel: saved ? 'Remove from saved' : 'Save prompt',
      curve: AppMotion.bookmarkCurve,
      duration: AppMotion.bookmarkFill,
      onTap: uid == null
          ? null
          : () async {
              try {
                await ref
                    .read(interactionsProvider.notifier)
                    .toggleBookmark(uid, promptId);
              } catch (_) {
                // Reverted by the notifier.
              }
            },
    );
  }
}

class _PopButton extends StatefulWidget {
  const _PopButton({
    required this.active,
    required this.activeColor,
    required this.iconOn,
    required this.iconOff,
    required this.semanticLabel,
    this.onTap,
    this.curve = AppMotion.likeCurve,
    this.duration = AppMotion.likeButton,
  });

  final bool active;
  final Color? activeColor;
  final IconData iconOn;
  final IconData iconOff;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Curve curve;
  final Duration duration;

  @override
  State<_PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<_PopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: SpringPress(
        onTap: widget.onTap == null ? null : _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // 1 → 1.3 → 1 keyframes, driven by the shared curve.
            final progress = widget.curve.transform(_controller.value);
            final scale =
                1 + 0.3 * (progress < 0.5 ? progress * 2 : (1 - progress) * 2);
            return Transform.scale(scale: scale, child: child);
          },
          child: Icon(
            widget.active ? widget.iconOn : widget.iconOff,
            size: 20,
            color: widget.active
                ? (widget.activeColor ?? t.textPrimary)
                : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Opens the comments sheet for a prompt (used from details + cards).
Future<void> openComments(BuildContext context, String promptId) {
  return showCommentsSheet(context, promptId);
}
