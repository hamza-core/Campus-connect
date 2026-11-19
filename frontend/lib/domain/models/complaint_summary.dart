import '../enums/complaint_category.dart';
import '../enums/complaint_status.dart';
import '../enums/priority.dart';
import 'department.dart';

final class ComplaintSummary {
  factory ComplaintSummary.fromJson(Map<String, Object?> json) =>
      ComplaintSummary(
        id: json['id'] as String,
        ticket: json['ticket'] as String,
        title: json['title'] as String,
        category: ComplaintCategory.fromApiValue(json['category'] as String),
        department: Department.fromJson(
          json['department'] as Map<String, Object?>,
        ),
        status: ComplaintStatus.fromApiValue(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        priority: Priority.fromApiValue(json['priority'] as String?),
        isOverdue: json['isOverdue'] as bool? ?? false,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'ticket': ticket,
    'title': title,
    'category': category.apiValue,
    'department': department.toJson(),
    'status': status.apiValue,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'priority': priority.apiValue,
    'isOverdue': isOverdue,
  };

  ComplaintSummary copyWith({
    String? id,
    String? ticket,
    String? title,
    ComplaintCategory? category,
    Department? department,
    ComplaintStatus? status,
    DateTime? createdAt,
    Priority? priority,
    bool? isOverdue,
  }) => ComplaintSummary(
    id: id ?? this.id,
    ticket: ticket ?? this.ticket,
    title: title ?? this.title,
    category: category ?? this.category,
    department: department ?? this.department,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    priority: priority ?? this.priority,
    isOverdue: isOverdue ?? this.isOverdue,
  );

  const ComplaintSummary({
    required this.id,
    required this.ticket,
    required this.title,
    required this.category,
    required this.department,
    required this.status,
    required this.createdAt,
    this.priority = Priority.medium,
    this.isOverdue = false,
  });

  final String id;
  final String ticket;
  final String title;
  final ComplaintCategory category;
  final Department department;
  final ComplaintStatus status;
  final DateTime createdAt;
  final Priority priority;
  final bool isOverdue;
}
