import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/department_admin/screens/admin_dashboard_screen.dart';
import '../features/department_admin/widgets/admin_shell.dart';
import '../features/shared/screens/complaint_detail_screen.dart';
import '../features/shared/screens/complaint_list_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/student_profile_screen.dart';
import '../features/student/screens/submit_complaint_screen.dart';
import '../features/student/widgets/student_shell.dart';

List<RouteBase> featureRoutes(AuthController auth) => [
  ShellRoute(
    builder: (context, state, child) =>
        StudentShell(route: state.uri.path, child: child),
    routes: [
      GoRoute(
        path: '/student',
        builder: (context, state) => StudentDashboardScreen(user: auth.user!),
      ),
      GoRoute(
        path: '/student/complaints',
        builder: (context, state) => ComplaintListScreen(
          key: ValueKey(state.uri.toString()),
          basePath: '/student/complaints',
          title: 'My complaints',
          student: true,
        ),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) => StudentProfileScreen(auth: auth),
      ),
    ],
  ),
  GoRoute(
    path: '/student/new',
    builder: (context, state) => SubmitComplaintScreen(ownerId: auth.user!.id),
  ),
  GoRoute(
    path: '/student/complaints/:id',
    builder: (context, state) => ComplaintDetailScreen(
      key: ValueKey(state.pathParameters['id']),
      id: state.pathParameters['id']!,
      backPath: '/student/complaints',
      photoOwnerId: auth.user!.id,
    ),
  ),
  _adminRoutes(auth, '/department', superAdmin: false),
  _adminRoutes(auth, '/admin', superAdmin: true),
];

ShellRoute _adminRoutes(
  AuthController auth,
  String base, {
  required bool superAdmin,
}) {
  final complaintsPath = '$base/complaints';
  return ShellRoute(
    builder: (context, state, child) => AdminShell(
      auth: auth,
      basePath: base,
      route: state.uri.path,
      child: child,
    ),
    routes: [
      GoRoute(
        path: base,
        builder: (context, state) => AdminDashboardScreen(
          title: superAdmin
              ? 'Campus dashboard'
              : auth.user!.department?.name ?? 'Department dashboard',
          complaintsPath: complaintsPath,
          showChart: superAdmin,
        ),
      ),
      GoRoute(
        path: complaintsPath,
        builder: (context, state) => ComplaintListScreen(
          basePath: complaintsPath,
          title: superAdmin ? 'All complaints' : 'Department complaints',
          department: !superAdmin,
          superAdmin: superAdmin,
        ),
      ),
      GoRoute(
        path: '$complaintsPath/:id',
        builder: (context, state) => ComplaintDetailScreen(
          key: ValueKey(state.pathParameters['id']),
          id: state.pathParameters['id']!,
          backPath: complaintsPath,
          canUpdate: !superAdmin,
        ),
      ),
    ],
  );
}
