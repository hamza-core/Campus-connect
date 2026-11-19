import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/floating_pill_nav.dart';
import '../../../core/widgets/nav_item_data.dart';
import '../../auth/controllers/auth_controller.dart';

final class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.auth,
    required this.basePath,
    required this.route,
    required this.child,
  });
  final AuthController auth;
  final String basePath;
  final String route;
  final Widget child;

  int get _selected => route.startsWith('$basePath/complaints') ? 1 : 0;

  void _navigate(BuildContext context, int selected) =>
      context.go(selected == 0 ? basePath : '$basePath/complaints');

  Future<void> _logout(BuildContext context) async {
    final confirmed = await ConfirmDialog.ask(
      context,
      title: 'Log out?',
      message: 'You can sign in again at any time.',
      confirmLabel: 'Log out',
    );
    if (confirmed) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    return Theme(
      data: AppTheme.admin(),
      child: Scaffold(
        appBar: mobile
            ? AppBar(
                title: const Text('CampusConnect'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Log out',
                    onPressed: () => _logout(context),
                  ),
                ],
              )
            : null,
        body: mobile
            ? SafeArea(bottom: false, child: child)
            : SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationRail(
                      extended: width >= Responsive.adminWideNavigation,
                      selectedIndex: _selected,
                      onDestinationSelected: (index) =>
                          _navigate(context, index),
                      leading: const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircleAvatar(child: Text('CC')),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Log out',
                        onPressed: () => _logout(context),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: Text('Dashboard'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.list_alt_outlined),
                          label: Text('Complaints'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
              ),
        bottomNavigationBar: mobile
            ? FloatingPillNav(
                items: const [
                  NavItemData(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                  ),
                  NavItemData(
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Complaints',
                  ),
                ],
                currentIndex: _selected,
                onTap: (index) => _navigate(context, index),
              )
            : null,
      ),
    );
  }
}
