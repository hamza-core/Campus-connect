import 'dart:math' as math;

import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/paged_result.dart';

final class DepartmentComplaintPages {
  DepartmentComplaintPages(
    this._repository,
    this._filter,
    List<ComplaintStatus> statuses,
  ) : _sources = {for (final status in statuses) status: _StatusPage()};

  final ComplaintRepository _repository;
  final ComplaintFilter _filter;
  final Map<ComplaintStatus, _StatusPage> _sources;
  static const _pageSize = 20;
  Future<void> _pending = Future.value();

  Future<PagedResult<ComplaintSummary>> list(int page) {
    final result = _pending.then((_) => _load(page));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<PagedResult<ComplaintSummary>> _load(int page) async {
    final needed = page * _pageSize;
    // Each source is sorted newest first. Once it has enough rows to cover the
    // requested merged page, later source rows cannot enter that page.
    await Future.wait(
      _sources.keys.map((status) async {
        final source = _sources[status]!;
        while (source.items.length < needed && source.hasNext) {
          final result = await _repository.list(
            filter: _filter.copyWith(status: () => status),
            page: source.nextPage,
            pageSize: _pageSize,
          );
          source.items.addAll(result.items);
          source.nextPage = result.page + 1;
          source.total = result.total;
          source.hasNext = result.hasNextPage;
        }
      }),
    );
    final merged = _sources.values.expand((source) => source.items).toList()
      ..sort((a, b) {
        final comparison = b.createdAt.compareTo(a.createdAt);
        return comparison == 0 ? a.id.compareTo(b.id) : comparison;
      });
    final start = math.min((page - 1) * _pageSize, merged.length);
    final end = math.min(needed, merged.length);
    return PagedResult(
      items: merged.getRange(start, end),
      page: page,
      pageSize: _pageSize,
      total: _sources.values.fold(0, (total, source) => total + source.total),
    );
  }
}

final class _StatusPage {
  final items = <ComplaintSummary>[];
  int nextPage = 1;
  int total = 0;
  bool hasNext = true;
}
