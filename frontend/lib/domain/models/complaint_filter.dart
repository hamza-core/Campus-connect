import '../enums/complaint_category.dart';
import '../enums/complaint_status.dart';
import '../enums/priority.dart';

final class ComplaintFilter {
  factory ComplaintFilter.fromJson(Map<String, Object?> json) =>
      ComplaintFilter(
        search: json['search'] as String? ?? '',
        category: json['category'] == null
            ? null
            : ComplaintCategory.fromApiValue(json['category'] as String),
        status: json['status'] == null
            ? null
            : ComplaintStatus.fromApiValue(json['status'] as String),
        departmentId: json['departmentId'] as String?,
        priority: json['priority'] == null
            ? null
            : Priority.fromApiValue(json['priority'] as String),
        overdueOnly: json['overdueOnly'] as bool? ?? false,
        year: json['year'] as int?,
      );

  Map<String, Object?> toJson() => {
    'search': search,
    'category': category?.apiValue,
    'status': status?.apiValue,
    'departmentId': departmentId,
    'priority': priority?.apiValue,
    'overdueOnly': overdueOnly,
    'year': year,
  };

  ComplaintFilter copyWith({
    String? search,
    ComplaintCategory? Function()? category,
    ComplaintStatus? Function()? status,
    String? Function()? departmentId,
    Priority? Function()? priority,
    bool? overdueOnly,
    int? Function()? year,
  }) => ComplaintFilter(
    search: search ?? this.search,
    category: category == null ? this.category : category(),
    status: status == null ? this.status : status(),
    departmentId: departmentId == null ? this.departmentId : departmentId(),
    priority: priority == null ? this.priority : priority(),
    overdueOnly: overdueOnly ?? this.overdueOnly,
    year: year == null ? this.year : year(),
  );

  const ComplaintFilter({
    this.search = '',
    this.category,
    this.status,
    this.departmentId,
    this.priority,
    this.overdueOnly = false,
    this.year,
  });

  final String search;
  final ComplaintCategory? category;
  final ComplaintStatus? status;
  final String? departmentId;
  final Priority? priority;
  final bool overdueOnly;

  /// Only complaints created in this year.
  final int? year;
}
