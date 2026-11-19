import 'department.dart';

final class DepartmentStat {
  factory DepartmentStat.fromJson(Map<String, Object?> json) => DepartmentStat(
    department: Department.fromJson(json['department'] as Map<String, Object?>),
    count: json['count'] as int,
  );

  Map<String, Object?> toJson() => {
    'department': department.toJson(),
    'count': count,
  };

  DepartmentStat copyWith({Department? department, int? count}) =>
      DepartmentStat(
        department: department ?? this.department,
        count: count ?? this.count,
      );

  const DepartmentStat({required this.department, required this.count});

  final Department department;
  final int count;
}
