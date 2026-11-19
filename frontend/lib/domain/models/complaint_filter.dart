import '../enums/complaint_category.dart';
import '../enums/complaint_status.dart';

final class ComplaintFilter {
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
