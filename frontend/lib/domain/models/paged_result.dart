final class PagedResult<T> {
  factory PagedResult.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?>) decodeItem,
  ) => PagedResult(
    items: (json['data'] as List).cast<Map<String, Object?>>().map(decodeItem),
    page: json['page'] as int,
    pageSize: json['pageSize'] as int,
    total: json['total'] as int,
  );

  Map<String, Object?> toJson(Map<String, Object?> Function(T) encodeItem) => {
    'data': items.map(encodeItem).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': total,
  };

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
