import 'package:flutter_test/flutter_test.dart';
import 'package:promptindo/core/utils/value_utils.dart';

void main() {
  group('asDateTime', () {
    test('parses UTC ISO-8601 string to local DateTime', () {
      final parsed = asDateTime('2026-11-27T03:30:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 11, 27, 3, 30));
    });

    test('parses offset ISO-8601 string', () {
      final parsed = asDateTime('2026-11-27T09:00:00+05:30');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 11, 27, 3, 30));
    });

    test('accepts DateTime and epoch millis', () {
      final utc = DateTime.utc(2026, 1, 2, 3, 4);
      expect(asDateTime(utc)?.toUtc(), utc);
      expect(
        asDateTime(utc.millisecondsSinceEpoch)?.toUtc(),
        utc,
      );
      expect(
        asDateTime(utc.millisecondsSinceEpoch.toDouble())?.toUtc(),
        utc,
      );
    });

    test('returns null for null, empty, or invalid strings', () {
      expect(asDateTime(null), isNull);
      expect(asDateTime(''), isNull);
      expect(asDateTime('   '), isNull);
      expect(asDateTime('not-a-date'), isNull);
    });
  });

  group('emptyToNull', () {
    test('converts null, empty, and whitespace strings to null', () {
      expect(emptyToNull(null), isNull);
      expect(emptyToNull(''), isNull);
      expect(emptyToNull('   \t\n '), isNull);
    });

    test('trims and preserves non-empty strings', () {
      expect(emptyToNull('abc-123'), 'abc-123');
      expect(emptyToNull('  abc-123  '), 'abc-123');
    });
  });

  group('escapeLikePattern', () {
    test('escapes backslash, percent, and underscore', () {
      expect(
        escapeLikePattern(r'a%b_c\d'),
        r'a\%b\_c\\d',
      );
    });
  });
}
