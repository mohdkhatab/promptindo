import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_sheets.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../core/widgets/spring_press.dart';
import '../domain/comment.dart';
import 'comment_likes_provider.dart';

/// Live comment list for one prompt (oldest first) — shared by the details
/// screen and the comments sheet so both render identically.
class CommentList extends ConsumerStatefulWidget {
  const CommentList({super.key, required this.promptId});

  final String promptId;

  @override
  ConsumerState<CommentList> createState() => _CommentListState();
}

class _CommentListState extends ConsumerState<CommentList> {
  late Stream<List<Comment>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = ref
        .read(commentRepositoryProvider)
        .watchComments(widget.promptId);
  }

  @override
  void didUpdateWidget(covariant CommentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.promptId != widget.promptId) {
      _stream = ref
          .read(commentRepositoryProvider)
          .watchComments(widget.promptId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Comment>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Comments are unavailable right now.');
        }
        if (!snapshot.hasData) {
          return const Column(
            children: [
              GlassShimmer(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 76,
                  radius: 22,
                ),
              ),
              SizedBox(height: AppSpace.md),
              GlassShimmer(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 76,
                  radius: 22,
                ),
              ),
            ],
          );
        }
        final comments = snapshot.data!;
        if (comments.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No comments yet',
            message: 'Be the first to say something useful.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < comments.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == comments.length - 1 ? 0 : AppSpace.md,
                ),
                child: CommentTile(comment: comments[i]),
              ),
          ],
        );
      },
    );
  }
}

/// Single comment row: author, content, like toggle, delete when it's yours.
class CommentTile extends ConsumerWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);
    final uid = ref.watch(currentUidProvider);
    final liked = ref.watch(
      commentLikesProvider.select((ids) => ids.contains(comment.id)),
    );

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: t.textPrimary.withValues(alpha: 0.08),
            backgroundImage: comment.authorAvatar.isEmpty
                ? null
                : NetworkImage(comment.authorAvatar),
            child: comment.authorAvatar.isEmpty
                ? Text(
                    initialsOf(comment.authorUsername),
                    style: t.onGlass(AppType.micro()),
                  )
                : null,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${comment.authorUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t
                            .onGlass(AppType.caption())
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      comment.createdAt == null
                          ? ''
                          : timeAgo(comment.createdAt!),
                      style: t.onGlassMuted(AppType.micro()),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: t.onGlass(AppType.body())),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    SpringPress(
                      onTap: uid == null
                          ? null
                          : () => ref
                                .read(commentLikesProvider.notifier)
                                .toggle(uid, comment.id),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: liked
                                ? const Color(0xFFFF3B30)
                                : t.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatCount(comment.likeCount + (liked ? 1 : 0)),
                            style: t.onGlassMuted(AppType.micro()),
                          ),
                        ],
                      ),
                    ),
                    if (uid != null && uid == comment.authorId) ...[
                      const SizedBox(width: AppSpace.lg),
                      SpringPress(
                        onTap: () async {
                          final ok = await showGlassConfirmDialog(
                            context,
                            title: 'Delete comment?',
                            message: 'This cannot be undone.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          );
                          if (!ok || !context.mounted) return;
                          await ref
                              .read(commentRepositoryProvider)
                              .deleteComment(comment.id);
                        },
                        child: Text(
                          'Delete',
                          style: AppType.micro(color: const Color(0xFFFF3B30)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Comment input row (details screen + sheet).
class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({
    super.key,
    required this.promptId,
    this.autofocus = false,
  });

  final String promptId;
  final bool autofocus;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      final profile = await ref.read(userRepositoryProvider).getUser(uid);
      await ref
          .read(commentRepositoryProvider)
          .addComment(
            promptId: widget.promptId,
            authorId: uid,
            authorUsername: profile?.username ?? 'user',
            authorAvatar: profile?.avatarUrl ?? '',
            content: text,
          );
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        GlassToast.show(
          context,
          'Could not post comment',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassInput(
            controller: _controller,
            hint: 'Add a comment…',
            autofocus: widget.autofocus,
            maxLines: 3,
            minLines: 1,
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        GlassIconButton(
          icon: Icons.arrow_upward_rounded,
          size: 44,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
