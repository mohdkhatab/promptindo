/// Value coercion helpers shared by models and Supabase repositories.
library;

/// Accepts an ISO-8601 [String], [DateTime], or epoch millis (int/num).
DateTime? asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed)?.toLocal();
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.round());
  }
  return null;
}

/// Converts empty/whitespace strings into `null` (e.g. for nullable UUID columns).
String? emptyToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Escapes SQL LIKE wildcards (`\`, `%`, `_`) so user input is treated literally.
String escapeLikePattern(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

String asString(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

List<String> asStringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

Map<String, dynamic> asMap(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

Map<String, String> asStringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
}
