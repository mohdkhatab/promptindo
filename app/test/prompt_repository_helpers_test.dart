import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:promptindo/core/services/deep_links.dart';
import 'package:promptindo/features/profile/domain/report.dart';
import 'package:promptindo/features/prompts/data/supabase_prompt_repository.dart';
import 'package:promptindo/features/prompts/domain/prompt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  Prompt makePrompt({
    String id = '11111111-1111-1111-1111-111111111111',
    String categoryId = '',
    String remixedFromId = '',
    int trendScore = 42,
    DateTime? createdAt,
  }) => Prompt(
    id: id,
    title: 'Test prompt',
    description: 'Desc',
    promptContent: 'Body',
    categoryId: categoryId,
    tags: const ['writing'],
    aiModel: 'GPT-4o',
    visibility: PromptVisibility.public,
    status: 'active',
    creatorId: '22222222-2222-2222-2222-222222222222',
    creatorUsername: 'ada',
    creatorAvatar: '',
    thumbnailUrl: '',
    thumbnailPath: '',
    likeCount: 5,
    copyCount: 2,
    viewCount: 10,
    commentCount: 1,
    bookmarkCount: 1,
    isFeatured: true,
    trendScore: trendScore,
    remixedFromId: remixedFromId,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 27, 3, 30),
    updatedAt: DateTime.utc(2026, 11, 27, 3, 30),
  );

  group('PromptCursor & PostgREST cursor filters', () {
    test('serializes timestamp in UTC with trailing Z', () {
      // Simulate a local DateTime created from a non-UTC offset.
      final local = DateTime.parse('2026-11-27T09:00:00+05:30').toLocal();
      final cursor = PromptCursor.fromPrompt(makePrompt(createdAt: local));

      expect(cursor.utcIso, '2026-11-27T03:30:00.000Z');
      expect(cursor.utcIso.endsWith('Z'), isTrue);
      expect(cursor.utcIso.contains('+'), isFalse);
    });

    test('latestCursorFilter builds exact keyset predicate', () {
      final cursor = PromptCursor(
        id: 'abc-123',
        createdAt: DateTime.utc(2026, 11, 27, 3, 30),
        trendScore: 42,
      );

      expect(
        SupabasePromptRepository.latestCursorFilter(cursor),
        'created_at.lt.2026-11-27T03:30:00.000Z,'
        'and(created_at.eq.2026-11-27T03:30:00.000Z,id.lt.abc-123)',
      );
    });

    test('trendingCursorFilter builds exact keyset predicate', () {
      final cursor = PromptCursor(
        id: 'abc-123',
        createdAt: DateTime.utc(2026, 11, 27, 3, 30),
        trendScore: 42,
      );

      expect(
        SupabasePromptRepository.trendingCursorFilter(cursor),
        'trend_score.lt.42,'
        'and(trend_score.eq.42,created_at.lt.2026-11-27T03:30:00.000Z),'
        'and(trend_score.eq.42,created_at.eq.2026-11-27T03:30:00.000Z,id.lt.abc-123)',
      );
    });
  });

  group('SupabasePromptRepository insert/update maps', () {
    test('converts empty UUID strings to null and omits restricted columns', () {
      final map = SupabasePromptRepository.toInsertMap(
        makePrompt(categoryId: '', remixedFromId: '   '),
      );

      expect(map['category_id'], isNull);
      expect(map['remixed_from_id'], isNull);
      expect(map.containsKey('like_count'), isFalse);
      expect(map.containsKey('status'), isFalse);
      expect(map.containsKey('is_featured'), isFalse);
      expect(map.containsKey('trend_score'), isFalse);
      expect(map.containsKey('creator_username'), isFalse);
      expect(map.containsKey('created_at'), isFalse);
    });

    test('preserves non-empty UUID strings on insert and update', () {
      const catId = '33333333-3333-3333-3333-333333333333';
      const remixId = '44444444-4444-4444-4444-444444444444';
      final prompt = makePrompt(categoryId: catId, remixedFromId: remixId);

      final insertMap = SupabasePromptRepository.toInsertMap(prompt);
      final updateMap = SupabasePromptRepository.toUpdateMap(prompt);

      expect(insertMap['category_id'], catId);
      expect(insertMap['remixed_from_id'], remixId);
      expect(updateMap['category_id'], catId);
      expect(updateMap.containsKey('creator_id'), isFalse);
      expect(updateMap.containsKey('remixed_from_id'), isFalse);
    });

    test('searchPrompts short-circuits empty queries without touching client', () async {
      final client = MockSupabaseClient();
      final repo = SupabasePromptRepository(client);

      final result = await repo.searchPrompts('   ');
      expect(result, isEmpty);
      verifyZeroInteractions(client);
    });
  });

  group('Report & DeepLink regressions', () {
    test('Report.fromMap defaults status to pending', () {
      final report = Report.fromMap({
        'reporter_id': 'u1',
        'target_type': 'prompt',
        'target_id': 'p1',
        'reason': 'Spam',
      }, id: 'r1');
      expect(report.status, 'pending');
    });

    test('promptIdFromUri parses /p/{uuid} with and without trailing slash', () {
      const uuid = '11111111-1111-1111-1111-111111111111';
      expect(
        promptIdFromUri(Uri.parse('https://promptindo.vercel.app/p/$uuid')),
        uuid,
      );
      expect(
        promptIdFromUri(Uri.parse('https://promptindo.vercel.app/p/$uuid/')),
        uuid,
      );
      expect(
        promptIdFromUri(Uri.parse('https://promptindo.vercel.app/?id=$uuid')),
        uuid,
      );
    });
  });
}
