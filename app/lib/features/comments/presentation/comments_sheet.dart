import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_sheets.dart';
import 'comment_list.dart';

/// Comments bottom sheet: live comment list + composer on the flatter sheet
/// surface (never glass-on-glass).
Future<void> showCommentsSheet(BuildContext context, String promptId) {
  return showGlassBottomSheet(
    context,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.72,
      child: _CommentsSheet(promptId: promptId),
    ),
  );
}

class _CommentsSheet extends ConsumerWidget {
  const _CommentsSheet({required this.promptId});

  final String promptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = GlassTokens.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Text('Comments', style: t.onGlass(AppType.subtitle())),
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
          child: SingleChildScrollView(child: CommentList(promptId: promptId)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: CommentComposer(promptId: promptId),
        ),
      ],
    );
  }
}
