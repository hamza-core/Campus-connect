import '../../../core/controllers/base_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/session_cache.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/paged_result.dart';
import 'department_complaint_pages.dart';

typedef _PageCache =
    Map<
      (String, ComplaintCategory?, ComplaintStatus?, String?, bool?),
      (List<ComplaintSummary>, int, bool)
    >;

final class ComplaintListController extends BaseController {
  ComplaintListController(
    this._repository, {
    bool department = false,
    SessionCache? cache,
    String scope = '',
  }) : _history = department ? false : null {
    // Pages seen before (per list and signed-in user) survive leaving the
    // screen, so coming back paints them at once and refreshes quietly.
    final shared = cache?.read<_PageCache>('list-pages:$scope');
    _cache = shared ?? _PageCache();
    if (shared == null) cache?.write('list-pages:$scope', _cache);
  }
  final ComplaintRepository _repository;
  final _debouncer = Debouncer();
  late final _PageCache _cache;
  final _departmentPages =
      <
        (String, ComplaintCategory?, ComplaintStatus?, String?, bool?),
        DepartmentComplaintPages
      >{};
  bool? _history;
  ComplaintFilter filter = const ComplaintFilter();
  List<ComplaintSummary> items = const [];
  bool loadingMore = false;
  bool hasMore = false;
  String? pageError;
  int _page = 1;
  int _generation = 0;

  (String, ComplaintCategory?, ComplaintStatus?, String?, bool?) get _key => (
    filter.search,
    filter.category,
    filter.status,
    filter.departmentId,
    _history,
  );

  Future<void> setDepartmentHistory(bool value) {
    _history = value;
    return setFilter(filter.copyWith(status: () => null));
  }

  Future<PagedResult<ComplaintSummary>> _listPage(int page) {
    final history = _history;
    if (history == null || filter.status != null) {
      return _repository.list(filter: filter, page: page);
    }
    return _departmentPages
        .putIfAbsent(
          _key,
          () => DepartmentComplaintPages(
            _repository,
            filter,
            history
                ? const [ComplaintStatus.resolved, ComplaintStatus.rejected]
                : const [ComplaintStatus.pending, ComplaintStatus.inProgress],
          ),
        )
        .list(page);
  }

  void search(String value) => _debouncer.schedule(
    () => setFilter(filter.copyWith(search: value.trim())),
  );

  /// First load: paints what this list last showed (if anything), then
  /// re-checks it quietly. Only a first-ever visit shows a placeholder.
  Future<void> start() => setFilter(filter);

  /// Applies a filter. A previously seen result is shown instantly, then
  /// re-checked in the background so it is never left stale.
  Future<void> setFilter(ComplaintFilter next) async {
    filter = next;
    final key = _key;
    final hadCache = _cache.containsKey(key);
    await refresh(useCache: true);
    if (hadCache && key == _key) await silentRefresh(force: true);
  }

  Future<void> refresh({bool useCache = false}) async {
    final generation = ++_generation;
    if (!useCache) {
      _cache.clear();
      _departmentPages.clear();
    }
    final key = _key;
    final cached = useCache ? _cache[key] : null;
    loadingMore = false;
    pageError = null;
    if (cached != null) {
      showCached(() {
        items = cached.$1;
        _page = cached.$2;
        hasMore = cached.$3;
      }, isEmpty: cached.$1.isEmpty);
      return;
    }
    await run(
      () async {
        if (cached != null) return cached;
        final result = await _listPage(1);
        return (result.items, result.page, result.hasNextPage);
      },
      isEmpty: (value) => value.$1.isEmpty,
      onSuccess: (value) {
        if (generation != _generation) return;
        items = value.$1;
        _page = value.$2;
        hasMore = value.$3;
        _cache[key] = value;
      },
    );
  }

  /// Quietly re-checks the first page without showing a loading state. The
  /// list only changes when something actually changed (new complaint, new
  /// status), so it never flickers.
  Future<void> silentRefresh({bool force = false}) async {
    if ((state == ViewState.loading && !force) || loadingMore) return;
    final generation = _generation;
    final key = _key;
    try {
      _departmentPages.clear();
      final result = await _listPage(1);
      if (generation != _generation || key != _key || loadingMore) return;
      final next = result.items;
      final unchanged =
          items.length >= next.length &&
          [
            for (var i = 0; i < next.length; i++)
              items[i].id == next[i].id &&
                  items[i].status == next[i].status &&
                  items[i].isOverdue == next[i].isOverdue &&
                  items[i].priority == next[i].priority &&
                  items[i].title == next[i].title,
          ].every((same) => same);
      if (unchanged) return;
      items = next;
      _page = result.page;
      hasMore = result.hasNextPage;
      _cache[key] = (items, _page, hasMore);
      safeNotify();
    } on Object {
      // Silent: the next tick or a manual pull will retry.
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore || state != ViewState.success) return;
    final generation = _generation;
    loadingMore = true;
    pageError = null;
    safeNotify();
    try {
      final result = await _listPage(_page + 1);
      if (generation != _generation) return;
      final seen = items.map((item) => item.id).toSet();
      items = List.unmodifiable([
        ...items,
        ...result.items.where((item) => seen.add(item.id)),
      ]);
      _page = result.page;
      hasMore = result.hasNextPage;
      _cache[_key] = (items, _page, hasMore);
    } on AppException catch (error) {
      if (generation == _generation) pageError = error.message;
    } finally {
      if (generation == _generation) {
        loadingMore = false;
        safeNotify();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _debouncer.dispose();
    super.dispose();
  }
}
