final class TrendPoint {
  factory TrendPoint.fromJson(Map<String, Object?> json) => TrendPoint(
    date: DateTime.parse(json['date'] as String),
    count: json['count'] as int,
  );

  const TrendPoint({required this.date, required this.count});

  final DateTime date;
  final int count;
}
