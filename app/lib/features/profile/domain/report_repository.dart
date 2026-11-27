import 'report.dart';

/// Report contract. Creation is authenticated-only and duplicate-guarded
/// server-side (Cloud Function collapses repeats within 1 hour).
abstract interface class ReportRepository {
  Future<void> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  });

  Future<List<Report>> fetchMyReports(String reporterId, {int limit = 20});
}
