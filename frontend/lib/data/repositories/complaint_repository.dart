import '../../domain/enums/complaint_category.dart';
import '../../domain/enums/complaint_status.dart';
import '../../domain/enums/priority.dart';
import '../../domain/models/complaint.dart';
import '../../domain/models/complaint_filter.dart';
import '../../domain/models/complaint_summary.dart';
import '../../domain/models/paged_result.dart';

abstract interface class ComplaintRepository {
  Future<PagedResult<ComplaintSummary>> list({
    ComplaintFilter filter = const ComplaintFilter(),
    int page = 1,
    int pageSize = 20,
  });

  Future<Complaint> detail(String id);

  Future<void> addRemark(String id, String body);

  Future<Complaint> submit({
    required ComplaintCategory category,
    required String title,
    required String description,
    String? subIssue,
    Priority priority = Priority.medium,
    String? location,
    bool anonymousToStaff = false,
  });

  Future<Complaint> submitFeedback({
    required String id,
    required int rating,
    String? comment,
  });

  /// CSV of the complaints the caller may see, honouring [filter].
  Future<String> exportCsv({ComplaintFilter filter = const ComplaintFilter()});

  Future<Complaint> updateStatus({
    required String id,
    required String rowVersion,
    required ComplaintStatus status,
    String? remark,
  });
}
