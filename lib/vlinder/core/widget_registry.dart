import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';

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
      throw ArgumentError(
        'Widget "$widgetName" is not registered. '
        'Available widgets: ${_builders.keys.join(", ")}',
      );
    }
    return builder(context, properties, children);
  }

  /// Convert Hetu HTValue to Dart Map
  static Map<String, dynamic> htValueToMap(HTValue value) {
    if (value is HTStruct) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        map[key.toString()] = htValueToDart(val);
      });
      return map;
    }
    throw ArgumentError('Expected HTStruct, got ${value.runtimeType}');
  }

  /// Convert Hetu HTValue to Dart value
  static dynamic htValueToDart(HTValue value) {
    if (value is HTStruct) {
      return htValueToMap(value);
    } else if (value is HTList) {
      return value.map((e) => htValueToDart(e)).toList();
    } else if (value is HTString) {
      return value.value;
    } else if (value is HTInt) {
      return value.value;
    } else if (value is HTFloat) {
      return value.value;
    } else if (value is HTBool) {
      return value.value;
    } else if (value is HTNull) {
      return null;
    }
    return value.toString();
  }
}

