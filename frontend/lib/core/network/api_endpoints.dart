abstract final class ApiEndpoints {
  static const health = 'health';
  static const categories = 'meta/categories';
  static const login = 'auth/login';
  static const register = 'auth/register';
  static const me = 'auth/me';
  static const complaints = 'complaints';
  static const analyticsSummary = 'analytics/summary';
  static const analyticsByDepartment = 'analytics/by-department';

  static String complaint(String id) =>
      '$complaints/${Uri.encodeComponent(id)}';
  static String complaintStatus(String id) => '${complaint(id)}/status';
}
