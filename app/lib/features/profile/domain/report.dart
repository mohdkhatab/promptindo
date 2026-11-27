import '../../../core/utils/value_utils.dart';

/// `reports/{reportId}` entity (auto-id). Clients may create reports against
/// prompts or comments; status flips to `resolved` only via the
/// `adminResolveReport` callable.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String targetType; // 'prompt' | 'comment' | 'user'
  final String targetId;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;

  bool get isResolved => status == 'resolved';

  factory Report.fromMap(Map<String, dynamic> map, {String? id}) {
    return Report(
      id: asString(map['id'], id ?? ''),
      reporterId: asString(map['reporter_id']),
      targetType: asString(map['target_type']),
      targetId: asString(map['target_id']),
      reason: asString(map['reason']),
      details: asString(map['details']),
      status: asString(map['status'], 'pending'),
      createdAt: asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'reporter_id': reporterId,
    'target_type': targetType,
    'target_id': targetId,
    'reason': reason,
    'details': details,
    'status': status,
    'created_at': createdAt,
  };
}
