import 'package:flutter/material.dart';

/// Screen widget - A navigable unit of UI and logic
/// 
/// Properties:
/// - id: String - Unique identifier for the screen
/// - title: String? - Optional title for the screen
/// - children: List<Widget> - Child widgets to display
class VlinderScreen extends StatelessWidget {
  final String id;
  final String? title;
  final List<Widget> children;

  const VlinderScreen({
    super.key,
    required this.id,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      debugPrint('[VlinderScreen] WARNING: Screen has no children, will show empty ListView');
    }
    
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
            )
          : null,
      body: children.length == 1
          ? children.first
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: children,
            ),
    );
  }

  /// Create from properties map (used by widget registry)
  static Widget fromProperties(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final id = properties['id'] as String? ?? 'screen';
    final title = properties['title'] as String?;
    final childrenList = children ?? [];
    
    if (childrenList.isEmpty) {
      debugPrint('[VlinderScreen] WARNING: Screen has no children!');
    }

    return VlinderScreen(
      id: id,
      title: title,
      children: childrenList,
    );
  }
}

