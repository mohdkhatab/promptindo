import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/widgets/glass_sheets.dart';
import '../../../core/widgets/glass_toast.dart';

/// Report reasons shown in the report action sheet (mirrors the values the
/// moderation Cloud Functions expect).
const kReportReasons = <String>[
  'Spam or misleading',
  'Harassment or hate',
  'Sexual content',
  'Violence',
  'Not a prompt / off-topic',
  'Something else',
];

/// Opens the report sheet and submits a `reports/{id}` doc (create allowed for
/// any signed-in user; dedup handled by the `onReportCreate` function).
Future<void> showReportSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String targetType,
  required String targetId,
}) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) {
    GlassToast.show(
      context,
      'Sign in to report content',
      icon: Icons.info_outline_rounded,
    );
    return;
  }

  final reason = await showGlassActionSheet<String>(
    context,
    title: 'Report',
    message: 'Why are you reporting this $targetType?',
    actions: [
      for (final value in kReportReasons)
        GlassSheetAction(label: value, value: value),
    ],
  );
  if (reason == null) return;

  try {
    await ref
        .read(reportRepositoryProvider)
        .submitReport(
          reporterId: uid,
          targetType: targetType,
          targetId: targetId,
          reason: reason,
        );
    if (context.mounted) {
      GlassToast.show(context, 'Report submitted — thanks');
    }
  } catch (_) {
    if (context.mounted) {
      GlassToast.show(
        context,
        'Could not submit report',
        icon: Icons.error_outline_rounded,
      );
    }
  }
}
