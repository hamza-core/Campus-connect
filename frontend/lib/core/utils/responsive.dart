import 'package:flutter/widgets.dart';

enum ScreenSize { phone, tablet, desktop }

abstract final class Responsive {
  static const studentMaxWidth = 480.0;
  static const adminWideNavigation = 900.0;

  static ScreenSize classify(double width) {
    if (width < 600) return ScreenSize.phone;
    if (width <= 1024) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static ScreenSize of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context).width);
}
