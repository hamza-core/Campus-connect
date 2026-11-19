import '../../../core/errors/app_exception.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/enums/user_role.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/complaint.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/paged_result.dart';
import '../../../domain/models/timeline_entry.dart';
import '../../mock_data/mock_complaint_record.dart';
import '../../mock_data/mock_seed.dart';
import '../complaint_repository.dart';
import 'mock_auth_repository.dart';

final class MockComplaintRepository implements ComplaintRepository {
  MockComplaintRepository(this._auth, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _records = MockSeed.complaints(_clock().toUtc());
  }

  final MockAuthRepository _auth;
  final DateTime Function() _clock;
  late final List<MockComplaintRecord> _records;
  int _revision = 1;

  bool _inScope(MockComplaintRecord record, AppUser user) =>
      switch (user.role) {
        UserRole.student => record.ownerId == user.id,
        UserRole.departmentAdmin =>
          record.complaint.summary.department.id == user.department?.id,
        UserRole.superAdmin => true,
      };

  Iterable<Complaint> visibleTo(AppUser user, {String? departmentId}) =>
      _records
          .where((record) => _inScope(record, user))
          .map((record) => record.complaint)
          .where(
            (item) =>
                user.role != UserRole.superAdmin ||
                departmentId == null ||
                item.summary.department.id == departmentId,
          );

  @override
  Future<PagedResult<ComplaintSummary>> list({
    ComplaintFilter filter = const ComplaintFilter(),
    int page = 1,
    int pageSize = 20,
  }) async {
    final user = _auth.requiredUser;
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw const ValidationException('Invalid page or page size.');
    }
    final query = filter.search.trim().toLowerCase();
    final matches =
        visibleTo(user, departmentId: filter.departmentId)
            .where((item) {
              final summary = item.summary;
              return (filter.category == null ||
                      summary.category == filter.category) &&
                  (filter.status == null || summary.status == filter.status) &&
                  [
                    summary.title,
                    summary.ticket,
                    item.description,
                  ].any((text) => text.toLowerCase().contains(query));
            })
            .map((item) => item.summary)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PagedResult(
      items: matches.skip((page - 1) * pageSize).take(pageSize),
      page: page,
      pageSize: pageSize,
      total: matches.length,
    );
  }

  MockComplaintRecord _load(String id, AppUser user) {
    for (final record in _records) {
      if (record.complaint.summary.id == id) {
        if (!_inScope(record, user)) throw const ForbiddenException();
        return record;
      }
    }
    throw const NotFoundException();
  }

  List<ComplaintStatus> _transitions(ComplaintStatus status, AppUser user) {
    if (user.role != UserRole.departmentAdmin) return const [];
    return switch (status) {
      ComplaintStatus.pending => const [
        ComplaintStatus.inProgress,
        ComplaintStatus.rejected,
      ],
      ComplaintStatus.inProgress => const [
        ComplaintStatus.resolved,
        ComplaintStatus.rejected,
      ],
      _ => const [],
    };
  }

  @override
  Future<Complaint> detail(String id) async {
    final user = _auth.requiredUser;
    final complaint = _load(id, user).complaint;
    return complaint.copyWith(
      allowedTransitions: _transitions(complaint.summary.status, user),
    );
  }

  @override
  Future<void> addRemark(String id, String body) async {
    final user = _auth.requiredUser;
    if (user.role != UserRole.departmentAdmin) throw const ForbiddenException();
    final record = _load(id, user);
    final previous = record.complaint;
    final message = body.trim();
    if (message.isEmpty || message.length > 2000) {
      throw const ValidationException(
        'Enter a remark of up to 2000 characters.',
      );
    }
    final version = _newVersion();
    record.complaint = previous.copyWith(
      rowVersion: version,
      allowedTransitions: _transitions(previous.summary.status, user),
      timeline: [
        ...previous.timeline,
        TimelineEntry(
          id: version,
          type: 'REMARK',
          createdAt: _clock().toUtc(),
          actorName: user.name,
          actorRole: user.role,
          body: message,
        ),
      ],
    );
  }

  @override
  Future<Complaint> submit({
    required ComplaintCategory category,
    required String title,
    required String description,
  }) async {
    final user = _auth.requiredUser;
    if (user.role != UserRole.student) throw const ForbiddenException();
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    if (cleanTitle.length < 5 ||
        cleanTitle.length > 120 ||
        cleanDescription.length < 10 ||
        cleanDescription.length > 3000) {
      throw const ValidationException(
        'Check the complaint title and description.',
      );
    }
    final sequence = _records.length + 1;
    final id = 'demo-$sequence';
    final now = _clock().toUtc();
    final complaint = Complaint(
      summary: ComplaintSummary(
        id: id,
        ticket: MockSeed.ticket(sequence),
        title: cleanTitle,
        category: category,
        department: MockSeed.departments[category]!,
        status: ComplaintStatus.pending,
        createdAt: now,
      ),
      rowVersion: _newVersion(),
      description: cleanDescription,
      authorName: user.name,
      timeline: [
        TimelineEntry(
          id: '$id-created',
          type: 'CREATED',
          createdAt: now,
          actorName: user.name,
          actorRole: user.role,
          toStatus: ComplaintStatus.pending,
        ),
      ],
      allowedTransitions: const [],
    );
    _records.add(MockComplaintRecord(user.id, complaint));
    return complaint;
  }

  @override
  Future<Complaint> updateStatus({
    required String id,
    required String rowVersion,
    required ComplaintStatus status,
    String? remark,
  }) async {
    final user = _auth.requiredUser;
    if (user.role != UserRole.departmentAdmin) throw const ForbiddenException();
    final record = _load(id, user);
    final previous = record.complaint;
    if (rowVersion.isEmpty) {
      throw const ValidationException('A row version is required.');
    }
    if (previous.rowVersion != rowVersion) {
      throw const ConflictException(
        'The complaint changed. Reload and try again.',
      );
    }
    if (!_transitions(previous.summary.status, user).contains(status)) {
      throw const ConflictException('This status change is not allowed.');
    }
    final body = remark?.trim();
    final terminal =
        status == ComplaintStatus.resolved ||
        status == ComplaintStatus.rejected;
    if ((terminal && (body == null || body.isEmpty)) ||
        (body?.length ?? 0) > 2000) {
      throw const ValidationException(
        'Enter a valid remark for this status change.',
      );
    }
    final version = _newVersion();
    record.complaint = previous.copyWith(
      summary: previous.summary.copyWith(status: status),
      rowVersion: version,
      isOverdue: !terminal && previous.isOverdue,
      allowedTransitions: _transitions(status, user),
      timeline: [
        ...previous.timeline,
        TimelineEntry(
          id: version,
          type: 'STATUS_CHANGE',
          createdAt: _clock().toUtc(),
          actorName: user.name,
          actorRole: user.role,
          fromStatus: previous.summary.status,
          toStatus: status,
          body: body,
        ),
      ],
    );
    return record.complaint;
  }

  String _newVersion() => 'demo-revision-${_revision++}';
}
