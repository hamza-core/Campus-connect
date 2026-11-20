import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/enums/priority.dart';
import '../../../domain/models/complaint.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/paged_result.dart';
import '../complaint_repository.dart';

final class RemoteComplaintRepository implements ComplaintRepository {
  const RemoteComplaintRepository(this._api);
  final ApiClient _api;

  @override
  Future<PagedResult<ComplaintSummary>> list({
    ComplaintFilter filter = const ComplaintFilter(),
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.request(
      'GET',
      ApiEndpoints.complaints,
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (filter.search.trim().isNotEmpty) 'q': filter.search.trim(),
        if (filter.category case final category?) 'category': category.apiValue,
        if (filter.status case final status?) 'status': status.apiValue,
        'departmentId': ?filter.departmentId,
        if (filter.priority case final priority?) 'priority': priority.apiValue,
        if (filter.overdueOnly) 'overdue': 'true',
        if (filter.year case final year?) 'year': '$year',
      },
    );
    return PagedResult.fromJson(response, ComplaintSummary.fromJson);
  }

  @override
  Future<Complaint> detail(String id) async {
    final response = await _api.request('GET', ApiEndpoints.complaint(id));
    return Complaint.fromJson(response['data'] as Map<String, Object?>);
  }

  @override
  Future<void> addRemark(String id, String body) async {
    await _api.request(
      'POST',
      ApiEndpoints.complaintComments(id),
      body: {'body': body},
    );
  }

  @override
  Future<Complaint> submit({
    required ComplaintCategory category,
    required String title,
    required String description,
    String? subIssue,
    Priority priority = Priority.medium,
    String? location,
    bool anonymousToStaff = false,
    List<String> imageUrls = const [],
  }) async {
    final response = await _api.request(
      'POST',
      ApiEndpoints.complaints,
      body: {
        'category': category.apiValue,
        'title': title,
        'description': description,
        'priority': priority.apiValue,
        'subIssue': ?subIssue,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (anonymousToStaff) 'anonymousToStaff': true,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      },
    );
    return Complaint.fromJson(response['data'] as Map<String, Object?>);
  }

  @override
  Future<Complaint> updateStatus({
    required String id,
    required String rowVersion,
    required ComplaintStatus status,
    String? remark,
  }) async {
    final response = await _api.request(
      'PATCH',
      ApiEndpoints.complaintStatus(id),
      body: {
        'status': status.apiValue,
        'rowVersion': rowVersion,
        'remark': ?remark,
      },
    );
    return Complaint.fromJson(response['data'] as Map<String, Object?>);
  }

  @override
  Future<Complaint> submitFeedback({
    required String id,
    required int rating,
    String? comment,
  }) async {
    final response = await _api.request(
      'POST',
      ApiEndpoints.complaintFeedback(id),
      body: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return Complaint.fromJson(response['data'] as Map<String, Object?>);
  }

  @override
  Future<String> exportCsv({
    ComplaintFilter filter = const ComplaintFilter(),
  }) => _api.requestText(
    'GET',
    ApiEndpoints.exportCsv,
    query: {
      if (filter.search.trim().isNotEmpty) 'q': filter.search.trim(),
      if (filter.category case final category?) 'category': category.apiValue,
      if (filter.status case final status?) 'status': status.apiValue,
      'departmentId': ?filter.departmentId,
      if (filter.priority case final priority?) 'priority': priority.apiValue,
      if (filter.overdueOnly) 'overdue': 'true',
      if (filter.year case final year?) 'year': '$year',
    },
  );

  @override
  Future<List<ComplaintSummary>> related(String id) async {
    final response = await _api.request(
      'GET',
      '${ApiEndpoints.complaint(id)}/related',
    );
    return List.unmodifiable(
      (response['data'] as List).cast<Map<String, Object?>>().map(
        ComplaintSummary.fromJson,
      ),
    );
  }
}
