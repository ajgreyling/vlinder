import 'package:flutter/material.dart';
import 'package:hetu_script/values.dart';

/// Type definition for a widget builder function
/// Takes a BuildContext and a map of properties from Hetu script
typedef WidgetBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> properties,
  List<Widget>? children,
);

/// Registry for Vlinder SDK widgets
/// Ensures only approved widgets can be instantiated (App Store safety)
class WidgetRegistry {
  static final WidgetRegistry _instance = WidgetRegistry._internal();
  factory WidgetRegistry() => _instance;
  WidgetRegistry._internal();

  final Map<String, WidgetBuilder> _builders = {};

  /// Register a widget builder
  void register(String widgetName, WidgetBuilder builder) {
    _builders[widgetName] = builder;
    debugPrint('[WidgetRegistry] Registered widget: "$widgetName"');
  }

  /// Check if a widget is registered
  bool isRegistered(String widgetName) {
    return _builders.containsKey(widgetName);
  }

  /// Get a widget builder by name
  WidgetBuilder? getBuilder(String widgetName) {
    return _builders[widgetName];
  }

  /// Get all registered widget names
  List<String> getRegisteredWidgets() {
    return _builders.keys.toList();
  }

  /// Build a widget from Hetu script data
  /// 
  /// [widgetName] - The name of the widget (e.g., 'Screen', 'TextField')
  /// [context] - BuildContext for widget creation
  /// [properties] - Properties from Hetu script (e.g., {'id': 'form1', 'entity': 'Customer'})
  /// [children] - Child widgets if any
  Widget buildWidget(
    String widgetName,
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final builder = _builders[widgetName];
    if (builder == null) {
      debugPrint('[WidgetRegistry] ERROR: Widget "$widgetName" is not registered!');
      debugPrint('[WidgetRegistry] Available widgets: ${_builders.keys.join(", ")}');
      throw ArgumentError(
        'Widget "$widgetName" is not registered. '
        'Available widgets: ${_builders.keys.join(", ")}',
      );
    }
    
    try {
      final widget = builder(context, properties, children);
      return widget;
    } catch (e, stackTrace) {
      debugPrint('[WidgetRegistry] ERROR: Failed to build widget "$widgetName": $e');
      debugPrint('[WidgetRegistry] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Convert Hetu HTValue to Dart Map
  static Map<String, dynamic> htValueToMap(dynamic value) {
    if (value is HTStruct) {
      final map = <String, dynamic>{};
      for (final key in value.keys) {
        map[key] = htValueToDart(value[key]);
      }
      return map;
    }
    throw ArgumentError('Expected HTStruct, got ${value.runtimeType}');
  }

  /// Convert Hetu HTValue to Dart value
  static dynamic htValueToDart(dynamic value) {
    if (value is HTStruct) {
      return htValueToMap(value);
    } else if (value is List) {
      return value.map((e) => htValueToDart(e)).toList();
    } else if (value is String) {
      return value;
    } else if (value is int) {
      return value;
    } else if (value is double) {
      return value;
    } else if (value is bool) {
      return value;
    } else if (value == null) {
      return null;
    }
    return value.toString();
  }
}

