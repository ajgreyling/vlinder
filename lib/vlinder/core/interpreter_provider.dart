import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';

/// Provider for sharing Hetu interpreter instance across the widget tree
/// This ensures all components (UI parser, action handlers, etc.) use the same interpreter
/// and can access shared state (schemas, workflows, rules, etc.)
class HetuInterpreterProvider extends InheritedWidget {
  final Hetu interpreter;

  const HetuInterpreterProvider({
    super.key,
    required this.interpreter,
    required super.child,
  });

  /// Get the interpreter from the nearest provider in the widget tree
  static Hetu? of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<HetuInterpreterProvider>();
    return provider?.interpreter;
  }

  /// Get the interpreter, throwing an error if not found
  static Hetu require(BuildContext context) {
    final interpreter = of(context);
    if (interpreter == null) {
      throw StateError(
        'HetuInterpreterProvider not found in widget tree. '
        'Wrap your app with HetuInterpreterProvider.',
      );
    }
    return interpreter;
  }

  @override
  bool updateShouldNotify(HetuInterpreterProvider oldWidget) {
    return interpreter != oldWidget.interpreter;
  }
}





