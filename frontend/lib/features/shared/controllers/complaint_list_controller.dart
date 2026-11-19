import '../../../core/controllers/base_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';

final class ComplaintListController extends BaseController {
  ComplaintListController(this._repository);
  final ComplaintRepository _repository;
  final _debouncer = Debouncer();
  final _cache =
      <
        (String, ComplaintCategory?, ComplaintStatus?, String?),
        (List<ComplaintSummary>, int, bool)
      >{};
  ComplaintFilter filter = const ComplaintFilter();
  List<ComplaintSummary> items = const [];
  bool loadingMore = false;
  bool hasMore = false;
  String? pageError;
  int _page = 1;
  int _generation = 0;

  (String, ComplaintCategory?, ComplaintStatus?, String?) get _key =>
      (filter.search, filter.category, filter.status, filter.departmentId);

  void search(String value) => _debouncer.schedule(
    () => setFilter(filter.copyWith(search: value.trim())),
  );

  Future<void> setFilter(ComplaintFilter next) {
    filter = next;
    return refresh(useCache: true);
  }

  Future<void> refresh({bool useCache = false}) async {
    final generation = ++_generation;
    if (!useCache) _cache.clear();
    final key = _key;
    final requested = filter;
    final cached = useCache ? _cache[key] : null;
    loadingMore = false;
    pageError = null;
    await run(
      () async {
        if (cached != null) return cached;
        final result = await _repository.list(filter: requested);
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

  Future<void> loadMore() async {
    if (loadingMore || !hasMore || state != ViewState.success) return;
    final generation = _generation;
    loadingMore = true;
    pageError = null;
    safeNotify();
    try {
      final result = await _repository.list(filter: filter, page: _page + 1);
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
