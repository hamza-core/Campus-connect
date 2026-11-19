import '../enums/user_role.dart';
import 'department.dart';

final class AppUser {
  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.fromApiValue(json['role'] as String),
    studentId: json['studentId'] as String?,
    department: json['department'] == null
        ? null
        : Department.fromJson(json['department'] as Map<String, Object?>),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.apiValue,
    'studentId': studentId,
    'department': department?.toJson(),
  };

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? Function()? studentId,
    Department? Function()? department,
  }) => AppUser(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
    studentId: studentId == null ? this.studentId : studentId(),
    department: department == null ? this.department : department(),
  );

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentId,
    this.department,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? studentId;
  final Department? department;
}
