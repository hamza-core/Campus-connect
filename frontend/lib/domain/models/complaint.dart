import '../enums/complaint_status.dart';
import 'complaint_summary.dart';
import 'timeline_entry.dart';

final class Complaint {
  Complaint({
    required this.summary,
    required this.rowVersion,
    required this.description,
    required Iterable<TimelineEntry> timeline,
    required Iterable<ComplaintStatus> allowedTransitions,
  }) : timeline = List.unmodifiable(timeline),
       allowedTransitions = List.unmodifiable(allowedTransitions);

  final ComplaintSummary summary;
  final String rowVersion;
  final String description;
  final List<TimelineEntry> timeline;
  final List<ComplaintStatus> allowedTransitions;
}
