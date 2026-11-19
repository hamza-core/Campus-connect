import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.route, required this.child});
  final String route;
  final Widget child;

  static const _tabs = ['/student', '/student/complaints', '/student/profile'];

  @override
  Widget build(BuildContext context) {
    final selected = _tabs.indexOf(route);
    return Scaffold(
      body: SafeArea(
        top: route != '/student' && route != '/student/profile',
        bottom: false,
        child: child,
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('report-issue'),
        tooltip: 'Report an issue',
        onPressed: () => context.push<bool>('/student/new').then((changed) {
          if (changed == true && context.mounted) {
            context.go('/student/complaints?submitted=1');
          }
        }),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: NavigationBar(
                  height: 68,
                  selectedIndex: selected < 0 ? 0 : selected,
                  onDestinationSelected: (index) => context.go(_tabs[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      label: 'Complaints',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
