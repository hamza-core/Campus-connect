import '../enums/complaint_category.dart';

final class RecurringIssue {
  factory RecurringIssue.fromJson(Map<String, Object?> json) => RecurringIssue(
    category: ComplaintCategory.fromApiValue(json['category'] as String),
    subIssue: json['subIssue'] as String? ?? 'General',
    count: json['count'] as int,
    supportTotal: json['supportTotal'] as int? ?? 0,
  );

  const RecurringIssue({
    required this.category,
    required this.subIssue,
    required this.count,
    required this.supportTotal,
  });

  final ComplaintCategory category;
  final String subIssue;
  final int count;
  final int supportTotal;
}
