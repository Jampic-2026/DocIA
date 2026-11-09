import '../theme/app_dimensions.dart';

enum WindowSizeClass {
  compact,
  medium,
  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < AppDimensions.compactBreakpoint) {
      return WindowSizeClass.compact;
    }
    if (width < AppDimensions.expandedBreakpoint) {
      return WindowSizeClass.medium;
    }
    return WindowSizeClass.expanded;
  }
}
