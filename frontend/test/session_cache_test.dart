import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/controllers/base_controller.dart';
import 'package:project/core/utils/session_cache.dart';
import 'package:project/data/repositories/auth_repository.dart';
import 'package:project/domain/models/app_user.dart';
import 'package:project/features/auth/controllers/auth_controller.dart';
import 'package:project/features/student/controllers/student_dashboard_controller.dart';
import 'package:project/features/shared/controllers/complaint_detail_controller.dart';
import 'package:project/data/repositories/complaint_repository.dart';
import 'package:project/domain/enums/complaint_category.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/domain/enums/priority.dart';
import 'package:project/domain/models/complaint.dart';
import 'package:project/domain/models/complaint_filter.dart';
import 'package:project/domain/models/complaint_summary.dart';
import 'package:project/domain/models/department.dart';
import 'package:project/domain/models/paged_result.dart';
import 'package:project/features/shared/controllers/complaint_list_controller.dart';

ComplaintSummary _c(
  String id, [
  ComplaintStatus status = ComplaintStatus.pending,
]) => ComplaintSummary(
  id: id,
  ticket: 'CC-$id',
  title: 'Complaint $id',
  category: ComplaintCategory.library,
  department: const Department(id: 'd', name: 'Library', slug: 'library'),
  status: status,
  createdAt: DateTime.utc(2026, 11, 19),
);

final class _FakeRepository implements ComplaintRepository {
  List<ComplaintSummary> items = [_c('2'), _c('1')];
  bool fail = false;
  int calls = 0;

  @override
  Future<PagedResult<ComplaintSummary>> list({
    ComplaintFilter filter = const ComplaintFilter(),
    int page = 1,
    int pageSize = 20,
  }) async {
    calls++;
    if (fail) throw Exception('offline');
    return PagedResult(
      items: items,
      page: 1,
      pageSize: 20,
      total: items.length,
    );
  }

  @override
  Future<Complaint> detail(String id) => throw UnimplementedError();
  @override
  Future<void> addRemark(String id, String body) => throw UnimplementedError();
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
  }) => throw UnimplementedError();
  @override
  Future<Complaint> submitFeedback({
    required String id,
    required int rating,
    String? comment,
  }) => throw UnimplementedError();
  @override
  Future<List<ComplaintSummary>> related(String id) async => const [];
  @override
  Future<String> exportCsv({
    ComplaintFilter filter = const ComplaintFilter(),
  }) => throw UnimplementedError();
  @override
  Future<Complaint> updateStatus({
    required String id,
    required String rowVersion,
    required ComplaintStatus status,
    String? remark,
  }) => throw UnimplementedError();
}

final class _DetailRepository extends _FakeRepository {
  @override
  Future<Complaint> detail(String id) async => Complaint(
    summary: _c(id),
    rowVersion: 'v1',
    description: 'Details',
    timeline: const [],
    allowedTransitions: const [],
  );
}

final class _Auth implements AuthRepository {
  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? studentId,
  }) => throw UnimplementedError();
  @override
  Future<AppUser?> restoreSession() async => null;
  @override
  Future<void> logout() async {}
}

/// Records every state a controller passes through.
List<ViewState> _watch(BaseController controller) {
  final seen = <ViewState>[];
  controller.addListener(() => seen.add(controller.state));
  return seen;
}

void main() {
  test('A list opened before paints at once, with no loading state', () async {
    final repository = _FakeRepository();
    final cache = SessionCache();
    final first = ComplaintListController(repository, cache: cache, scope: 'a');
    await first.start();
    expect(first.items.length, 2);

    // The user switches tabs: a brand-new controller for the same list.
    repository.items = [_c('3'), _c('2'), _c('1')];
    final second = ComplaintListController(
      repository,
      cache: cache,
      scope: 'a',
    );
    final seen = _watch(second);
    final done = second.start();
    expect(second.items.length, 2, reason: 'last-known data is there at once');
    await done;
    expect(seen, isNot(contains(ViewState.loading)));
    expect(second.items.map((c) => c.id), [
      '3',
      '2',
      '1',
    ], reason: 'then freshened');
  });

  test('A first-ever visit still shows the loading state', () async {
    final controller = ComplaintListController(
      _FakeRepository(),
      cache: SessionCache(),
      scope: 'a',
    );
    final seen = _watch(controller);
    await controller.start();
    expect(seen, contains(ViewState.loading));
  });

  test('Lists with different scopes do not share data', () async {
    final cache = SessionCache();
    final repository = _FakeRepository();
    await ComplaintListController(
      repository,
      cache: cache,
      scope: 'student',
    ).start();
    repository.items = [_c('9')];
    final other = ComplaintListController(
      repository,
      cache: cache,
      scope: 'admin',
    );
    expect(other.items, isEmpty);
    await other.start();
    expect(other.items.map((c) => c.id), ['9']);
  });

  test('The student home paints the last numbers at once', () async {
    final repository = _FakeRepository();
    final cache = SessionCache();
    await StudentDashboardController(repository, cache).open();

    repository.items = [_c('3'), _c('2'), _c('1')];
    final second = StudentDashboardController(repository, cache);
    final seen = _watch(second);
    final done = second.open();
    expect(second.stats, isNotNull);
    expect(second.state, ViewState.success);
    await done;
    expect(seen, isNot(contains(ViewState.loading)));
    expect(second.recent.length, 3);
  });

  test('Signing in, out or expiring the session clears the cache', () async {
    final cache = SessionCache()..write('k', 1);
    final auth = AuthController(_Auth(), onSessionChange: cache.clear);
    await auth.signOut();
    expect(cache.read<int>('k'), isNull);

    cache.write('k', 1);
    auth.expireSession();
    expect(cache.read<int>('k'), isNull);
  });

  test('A detail opened before appears at once', () async {
    final cache = SessionCache();
    final repository = _DetailRepository();
    await ComplaintDetailController(repository, 'x', cache).open();

    final second = ComplaintDetailController(repository, 'x', cache);
    final seen = _watch(second);
    final done = second.open();
    expect(second.complaint, isNotNull);
    await done;
    expect(seen, isNot(contains(ViewState.loading)));
  });
}
