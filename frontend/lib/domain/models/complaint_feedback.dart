final class ComplaintFeedback {
  factory ComplaintFeedback.fromJson(Map<String, Object?> json) =>
      ComplaintFeedback(
        rating: (json['rating'] ?? json['Rating']) as int,
        comment: (json['comment'] ?? json['Comment']) as String?,
      );

  const ComplaintFeedback({required this.rating, this.comment});

  final int rating;
  final String? comment;

  Map<String, Object?> toJson() => {'rating': rating, 'comment': comment};
}
