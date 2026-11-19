import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/floating_pill_nav.dart';
import '../../../core/widgets/nav_action_button.dart';
import '../../../core/widgets/nav_item_data.dart';

final class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.route, required this.child});
  final String route;
  final Widget child;

  static const tabs = ['/student', '/student/complaints', '/student/profile'];
  static const newComplaint = '/student/new';

  @override
  State<StudentShell> createState() => _StudentShellState();
}

final class _StudentShellState extends State<StudentShell> {
  static const _items = [
    NavItemData(icon: Icons.home_outlined, label: 'Home'),
    NavItemData(icon: Icons.format_list_bulleted_rounded, label: 'Complaints'),
    NavItemData(icon: Icons.person_outline_rounded, label: 'Profile'),
  ];

  /// Remembers the last tab so it stays highlighted on the New Complaint screen.
  int _lastTab = 0;

  bool get _closing => widget.route == StudentShell.newComplaint;

  void _open() {
    context.push<bool>(StudentShell.newComplaint).then((changed) {
      if (changed == true && mounted) {
        context.go('/student/complaints?submitted=1');
      }
    });
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(StudentShell.tabs[_lastTab]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = StudentShell.tabs.indexOf(widget.route);
    if (tab >= 0) _lastTab = tab;
    final heroRoute =
        widget.route == '/student' || widget.route == '/student/profile';
    return Scaffold(
      body: SafeArea(top: !heroRoute, bottom: false, child: widget.child),
      bottomNavigationBar: FloatingPillNav(
        items: _items,
        currentIndex: _lastTab,
        onTap: (index) => context.go(StudentShell.tabs[index]),
        trailingAction: NavActionButton(
          key: const ValueKey('report-issue'),
          isClosing: _closing,
          onPressed: _closing ? _close : _open,
        ),
      ),
    );
  }
}
