import '../enums/complaint_status.dart';
import 'complaint_summary.dart';
import 'timeline_entry.dart';

final class Complaint {
  factory Complaint.fromJson(Map<String, Object?> json) => Complaint(
    summary: ComplaintSummary.fromJson(json),
    rowVersion: json['rowVersion'] as String,
    description: json['description'] as String,
    isOverdue: json['isOverdue'] as bool? ?? false,
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
    String? Function()? authorName,
    Iterable<TimelineEntry>? timeline,
    Iterable<ComplaintStatus>? allowedTransitions,
  }) => Complaint(
    summary: summary ?? this.summary,
    rowVersion: rowVersion ?? this.rowVersion,
    description: description ?? this.description,
    isOverdue: isOverdue ?? this.isOverdue,
    authorName: authorName == null ? this.authorName : authorName(),
    timeline: timeline ?? this.timeline,
    allowedTransitions: allowedTransitions ?? this.allowedTransitions,
  );

  Complaint({
    required this.summary,
    required this.rowVersion,
    required this.description,
    this.isOverdue = false,
    this.authorName,
    required Iterable<TimelineEntry> timeline,
    required Iterable<ComplaintStatus> allowedTransitions,
  }) : timeline = List.unmodifiable(timeline),
       allowedTransitions = List.unmodifiable(allowedTransitions);

  final ComplaintSummary summary;
  final String rowVersion;
  final String description;
  final bool isOverdue;
  final String? authorName;
  final List<TimelineEntry> timeline;
  final List<ComplaintStatus> allowedTransitions;
}
