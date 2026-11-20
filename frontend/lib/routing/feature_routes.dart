import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/enums/complaint_status.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/department_admin/screens/admin_dashboard_screen.dart';
import '../features/department_admin/widgets/admin_shell.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/shared/screens/complaint_detail_screen.dart';
import '../features/shared/screens/complaint_list_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/student_profile_screen.dart';
import '../features/student/screens/submit_complaint_screen.dart';
import '../features/student/widgets/student_shell.dart';
import 'feature_page.dart';

List<RouteBase> featureRoutes(AuthController auth) => [
  ShellRoute(
    builder: (context, state, child) =>
        StudentShell(route: state.uri.path, child: child),
    routes: [
      _feature(
        '/student',
        (state) => StudentDashboardScreen(user: auth.user!),
        tab: true,
      ),
      _feature(
        '/student/complaints',
        (state) => ComplaintListScreen(
          key: ValueKey(state.uri.toString()),
          basePath: '/student/complaints',
          title: 'My complaints',
          student: true,
        ),
        tab: true,
      ),
      _feature(
        '/student/profile',
        (state) => StudentProfileScreen(auth: auth),
        tab: true,
      ),
      _feature(
        '/student/notifications',
        (state) => const NotificationsScreen(),
      ),
      _feature(
        '/student/new',
        (state) => SubmitComplaintScreen(ownerId: auth.user!.id),
      ),
    ],
  ),
  _feature(
    '/student/complaints/:id',
    (state) => ComplaintDetailScreen(
      key: ValueKey(state.pathParameters['id']),
      id: state.pathParameters['id']!,
      backPath: '/student/complaints',
      photoOwnerId: auth.user!.id,
    ),
  ),
  _adminRoutes(auth, '/department', superAdmin: false),
  _adminRoutes(auth, '/admin', superAdmin: true),
];

/// [tab] routes are the bottom-navigation destinations and swap instantly;
/// everything else is pushed on top with the platform transition.
GoRoute _feature(
  String path,
  Widget Function(GoRouterState) build, {
  bool tab = false,
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      tab ? tabPage(state, build(state)) : pushedPage(state, build(state)),
);

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
      _feature(
        base,
        (state) => AdminDashboardScreen(
          title: superAdmin
              ? 'Campus dashboard'
              : auth.user!.department?.name ?? 'Department dashboard',
          complaintsPath: complaintsPath,
          showChart: superAdmin,
        ),
        tab: true,
      ),
      _feature(
        complaintsPath,
        (state) => ComplaintListScreen(
          key: ValueKey(state.uri.toString()),
          basePath: complaintsPath,
          title: superAdmin ? 'All complaints' : 'Department complaints',
          department: !superAdmin,
          superAdmin: superAdmin,
          initialStatus: ComplaintStatus.values
              .where(
                (value) =>
                    value.apiValue == state.uri.queryParameters['status'],
              )
              .firstOrNull,
          initialOverdue: state.uri.queryParameters['overdue'] == 'true',
        ),
        tab: true,
      ),
      _feature(
        '$complaintsPath/:id',
        (state) => ComplaintDetailScreen(
          key: ValueKey(state.pathParameters['id']),
          id: state.pathParameters['id']!,
          backPath: complaintsPath,
          canUpdate: !superAdmin,
        ),
      ),
    ],
  );
}
