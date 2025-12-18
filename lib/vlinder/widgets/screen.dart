import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';
import 'form.dart';

/// Screen widget - A navigable unit of UI and logic
/// 
/// Properties:
/// - id: String - Unique identifier for the screen
/// - title: String? - Optional title for the screen
/// - children: List<Widget> - Child widgets to display
class VlinderScreen extends StatefulWidget {
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
  State<VlinderScreen> createState() => _VlinderScreenState();

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

class _VlinderScreenState extends State<VlinderScreen> {
  FormStateManager? _screenFormState;

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      debugPrint('[VlinderScreen] WARNING: Screen has no children, will show empty ListView');
    }
    
    Widget body = widget.children.length == 1
        ? _wrapChildWithFormStateProvider(widget.children.first)
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: widget.children.map(_wrapChildWithFormStateProvider).toList(),
          );
    
    // If we have a form state from a Form child, wrap the entire body with it
    // so siblings (like ActionButton) can access it
    if (_screenFormState != null) {
      debugPrint('[VlinderScreen] Wrapping body with FormStateProvider from Form');
      body = FormStateProvider(
        formState: _screenFormState!,
        child: body,
      );
    }
    
    return Scaffold(
      appBar: widget.title != null
          ? AppBar(
              title: Text(widget.title!),
            )
          : null,
      body: body,
    );
  }

  /// Wrap a child widget and detect if it's a Form, capturing its FormStateProvider
  Widget _wrapChildWithFormStateProvider(Widget child) {
    if (child is VlinderForm) {
      // Create a new Form widget with callback to capture FormStateManager
      return VlinderForm(
        key: child.key,
        entity: child.entity,
        children: child.children,
        formState: child.formState,
        onFormStateReady: (formState) {
          // Defer setState to avoid calling it during build
          if (mounted && _screenFormState != formState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _screenFormState = formState;
                });
              }
            });
          }
        },
      );
    }
    return child;
  }
}

