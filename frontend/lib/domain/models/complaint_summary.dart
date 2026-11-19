import '../enums/complaint_category.dart';
import '../enums/complaint_status.dart';
import 'department.dart';

final class ComplaintSummary {
  const ComplaintSummary({
    required this.id,
    required this.ticket,
    required this.title,
    required this.category,
    required this.department,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String ticket;
  final String title;
  final ComplaintCategory category;
  final Department department;
  final ComplaintStatus status;
  final DateTime createdAt;
}
