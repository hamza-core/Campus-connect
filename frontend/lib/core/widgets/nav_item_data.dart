import 'package:flutter/widgets.dart';

/// One destination in a [FloatingPillNav].
@immutable
final class NavItemData {
  const NavItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
