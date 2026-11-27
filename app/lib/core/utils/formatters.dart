import 'package:intl/intl.dart';

/// Count formatting for stats rows: 999 → "999", 12_400 → "12.4k".
String formatCount(int value) {
  if (value < 0) return '0';
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final k = value / 1000;
    return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k'.replaceFirst('.0k', 'k');
  }
  final m = value / 1000000;
  return '${m.toStringAsFixed(m < 10 ? 1 : 0)}m'.replaceFirst('.0m', 'm');
}

/// Compact relative time: "just now", "5m", "3h", "2d", then a date.
String timeAgo(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);

  if (diff.isNegative || diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 365) return DateFormat('d MMM').format(time);
  return DateFormat('d MMM yyyy').format(time);
}

/// Longer form used on detail screens: "12 Mar 2026".
String formatDate(DateTime time) => DateFormat('d MMM yyyy').format(time);

/// 08:30
String formatTime(DateTime time) => DateFormat('HH:mm').format(time);

/// Splits a display name into initials for the avatar placeholder.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final buffer = StringBuffer();
  for (final part in parts.take(2)) {
    buffer.write(part.substring(0, 1).toUpperCase());
  }
  final result = buffer.toString();
  return result.isEmpty ? '?' : result;
}

/// Basic validation helpers shared by auth + create/edit forms.
final RegExp _usernameRe = RegExp(r'^[A-Za-z0-9_]{3,24}$');

bool isValidUsername(String value) => _usernameRe.hasMatch(value.trim());

bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

String? passwordProblem(String value) {
  if (value.length < 8) return 'At least 8 characters';
  if (!value.contains(RegExp(r'[A-Za-z]'))) return 'Needs a letter';
  if (!value.contains(RegExp(r'[0-9]'))) return 'Needs a number';
  return null;
}
