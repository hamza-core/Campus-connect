import '../enums/user_role.dart';
import 'department.dart';

final class AppUser {
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
