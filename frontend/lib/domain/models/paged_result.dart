final class PagedResult<T> {
  PagedResult({
    required Iterable<T> items,
    required this.page,
    required this.pageSize,
    required this.total,
  }) : items = List.unmodifiable(items);

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasNextPage => page * pageSize < total;
}
