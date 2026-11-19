import '../enums/complaint_status.dart';
import 'complaint_feedback.dart';
import 'complaint_summary.dart';
import 'timeline_entry.dart';

final class Complaint {
  factory Complaint.fromJson(Map<String, Object?> json) => Complaint(
    summary: ComplaintSummary.fromJson(json),
    rowVersion: json['rowVersion'] as String,
    description: json['description'] as String,
    isOverdue: json['isOverdue'] as bool? ?? false,
    location: json['location'] as String?,
    subIssue: json['subIssue'] as String?,
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.parse(json['dueAt'] as String),
    feedback: json['feedback'] is Map<String, Object?>
        ? ComplaintFeedback.fromJson(json['feedback'] as Map<String, Object?>)
        : null,
    authorName: (json['author'] as Map<String, Object?>?)?['name'] as String?,
    timeline: (json['timeline'] as List? ?? const [])
        .cast<Map<String, Object?>>()
        .map(TimelineEntry.fromJson),
    allowedTransitions: (json['allowedTransitions'] as List? ?? const [])
        .cast<String>()
        .map(ComplaintStatus.fromApiValue),
  );

  Map<String, Object?> toJson() => {
    ...summary.toJson(),
    'rowVersion': rowVersion,
    'description': description,
    'isOverdue': isOverdue,
    'location': location,
    'subIssue': subIssue,
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'feedback': feedback?.toJson(),
    if (authorName != null) 'author': {'name': authorName},
    'timeline': timeline.map((entry) => entry.toJson()).toList(),
    'allowedTransitions': allowedTransitions
        .map((status) => status.apiValue)
        .toList(),
  };

  Complaint copyWith({
    ComplaintSummary? summary,
    String? rowVersion,
    String? description,
    bool? isOverdue,
    String? Function()? location,
    String? Function()? subIssue,
    DateTime? Function()? dueAt,
    ComplaintFeedback? Function()? feedback,
    String? Function()? authorName,
    Iterable<TimelineEntry>? timeline,
    Iterable<ComplaintStatus>? allowedTransitions,
  }) => Complaint(
    summary: summary ?? this.summary,
    rowVersion: rowVersion ?? this.rowVersion,
    description: description ?? this.description,
    isOverdue: isOverdue ?? this.isOverdue,
    location: location == null ? this.location : location(),
    subIssue: subIssue == null ? this.subIssue : subIssue(),
    dueAt: dueAt == null ? this.dueAt : dueAt(),
    feedback: feedback == null ? this.feedback : feedback(),
    authorName: authorName == null ? this.authorName : authorName(),
    timeline: timeline ?? this.timeline,
    allowedTransitions: allowedTransitions ?? this.allowedTransitions,
  );

  Complaint({
    required this.summary,
    required this.rowVersion,
    required this.description,
    this.isOverdue = false,
    this.location,
    this.subIssue,
    this.dueAt,
    this.feedback,
    this.authorName,
    required Iterable<TimelineEntry> timeline,
    required Iterable<ComplaintStatus> allowedTransitions,
  }) : timeline = List.unmodifiable(timeline),
       allowedTransitions = List.unmodifiable(allowedTransitions);

  final ComplaintSummary summary;
  final String rowVersion;
  final String description;
  final bool isOverdue;
  final String? location;
  final String? subIssue;
  final DateTime? dueAt;
  final ComplaintFeedback? feedback;
  final String? authorName;
  final List<TimelineEntry> timeline;
  final List<ComplaintStatus> allowedTransitions;
}
