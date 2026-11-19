import '../enums/complaint_category.dart';
import '../enums/complaint_status.dart';

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
      );

  Map<String, Object?> toJson() => {
    'search': search,
    'category': category?.apiValue,
    'status': status?.apiValue,
    'departmentId': departmentId,
  };

  ComplaintFilter copyWith({
    String? search,
    ComplaintCategory? Function()? category,
    ComplaintStatus? Function()? status,
    String? Function()? departmentId,
  }) => ComplaintFilter(
    search: search ?? this.search,
    category: category == null ? this.category : category(),
    status: status == null ? this.status : status(),
    departmentId: departmentId == null ? this.departmentId : departmentId(),
  );

  const ComplaintFilter({
    this.search = '',
    this.category,
    this.status,
    this.departmentId,
  });

  final String search;
  final ComplaintCategory? category;
  final ComplaintStatus? status;
  final String? departmentId;
}
