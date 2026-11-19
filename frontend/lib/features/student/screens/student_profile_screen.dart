import 'package:flutter/material.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/controllers/auth_controller.dart';

final class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    final theme = Theme.of(context);
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          HeroHeader(
            bottomRadius: 36,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFD3E3DE),
                  foregroundColor: theme.colorScheme.primary,
                  child: Text(
                    user.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                ),
                if (user.studentId case final id?)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Student ID'),
                      subtitle: Text(id),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Your photos'),
                    subtitle: const Text(
                      'Photos attached to complaints are kept on this device only.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  onPressed: () async {
                    if (await ConfirmDialog.ask(
                      context,
                      title: 'Log out?',
                      message: 'You can sign in again at any time.',
                      confirmLabel: 'Log out',
                    )) {
                      await auth.signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
