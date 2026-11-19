import 'package:flutter/material.dart';

final class DemoAccounts extends StatelessWidget {
  const DemoAccounts({super.key});

  @override
  Widget build(BuildContext context) => const ExpansionTile(
    title: Text('Demo accounts'),
    children: [
      ListTile(
        title: Text('Student'),
        subtitle: Text('ali@student.com / Ali@1234'),
      ),
      ListTile(
        title: Text('Department admin'),
        subtitle: Text('library.admin@campus.com / Admin@1234'),
      ),
      ListTile(
        title: Text('Super admin'),
        subtitle: Text('super.admin@campus.com / Admin@1234'),
      ),
    ],
  );
}
