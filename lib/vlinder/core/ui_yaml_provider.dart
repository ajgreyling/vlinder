import 'package:flutter/material.dart';

/// Provider for sharing UI YAML content across the widget tree
/// This ensures action handlers can access UI YAML to load screens for navigation
class UIYAMLProvider extends InheritedWidget {
  final String uiYamlContent;

  const UIYAMLProvider({
    super.key,
    required this.uiYamlContent,
    required super.child,
  });

  /// Get the UI YAML content from the nearest provider in the widget tree
  static String? of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<UIYAMLProvider>();
    return provider?.uiYamlContent;
  }

  /// Get the UI YAML content, throwing an error if not found
  static String require(BuildContext context) {
    final content = of(context);
    if (content == null) {
      throw StateError(
        'UIYAMLProvider not found in widget tree. '
        'Wrap your app with UIYAMLProvider.',
      );
    }
    return content;
  }

  @override
  bool updateShouldNotify(UIYAMLProvider oldWidget) {
    return uiYamlContent != oldWidget.uiYamlContent;
  }
}
