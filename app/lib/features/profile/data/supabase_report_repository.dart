import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

class SupabaseReportRepository implements ReportRepository {
  SupabaseReportRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<void> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    try {
      // `status` defaults to `'pending'` in Postgres and is not client-grantable.
      await _supabase.from('reports').insert({
        'reporter_id': reporterId,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'details': details,
      });
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<List<Report>> fetchMyReports(
    String reporterId, {
    int limit = 20,
  }) async {
    try {
      final rows = await _supabase
          .from('reports')
          .select()
          .eq('reporter_id', reporterId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => Report.fromMap(row, id: asString(row['id'])))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }
}
