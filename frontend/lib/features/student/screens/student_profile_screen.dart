import 'package:flutter/material.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/controllers/auth_controller.dart';

final class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final user = auth.user!;
    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
          ),
          if (user.studentId case final id?)
            Card(
              child: ListTile(
                title: const Text('Student ID'),
                subtitle: Text(id),
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
    );
  }
}
