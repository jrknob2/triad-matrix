import 'package:flutter/widgets.dart';

abstract final class AppViewport {
  static const double tabletShortestSide = 700;
  static const double wideRailWidth = 1100;
  static const double splitPaneGap = 16;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;
  }

  static bool useExtendedRail(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wideRailWidth;
  }
}
