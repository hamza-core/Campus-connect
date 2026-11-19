enum UserRole {
  student('STUDENT'),
  departmentAdmin('DEPT_ADMIN'),
  superAdmin('SUPER_ADMIN');

  const UserRole(this.apiValue);
  final String apiValue;
}
