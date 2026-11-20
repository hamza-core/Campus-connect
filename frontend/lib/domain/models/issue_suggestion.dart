final class IssueSuggestion {
  const IssueSuggestion({
    required this.category,
    required this.issue,
    required this.priority,
    required this.summary,
    required this.isNewIssue,
  });
  factory IssueSuggestion.fromJson(Map<String, Object?> json) =>
      IssueSuggestion(
        category: json['category'] as String? ?? '',
        issue: json['issue'] as String? ?? '',
        priority: json['priority'] as String? ?? 'MEDIUM',
        summary: json['summary'] as String? ?? '',
        isNewIssue: json['isNewIssue'] as bool? ?? false,
      );
  final String category;
  final String issue;
  final String priority;
  final String summary;
  final bool isNewIssue;
}

final class UploadedPhoto {
  const UploadedPhoto({required this.id, required this.url});
  final String id;
  final String url;
}
