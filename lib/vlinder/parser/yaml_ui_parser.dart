import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../core/widget_registry.dart';
import 'ui_parser.dart';

/// Parser for YAML UI definitions
/// Converts YAML structure to ParsedWidget tree
class YAMLUIParser {
  final WidgetRegistry registry;

  YAMLUIParser({
    required this.registry,
  });

  /// Parse a YAML UI definition file
  /// Returns a ParsedWidget tree representing the UI structure
  ParsedWidget parse(String yamlContent) {
    try {
      final yamlDoc = loadYaml(yamlContent);
      
      if (yamlDoc is! Map) {
        throw FormatException('[YAMLUIParser] Expected YAML document to be a Map, got ${yamlDoc.runtimeType}');
      }

      // Look for 'screen' key (root widget)
      dynamic screenValue;
      if (yamlDoc.containsKey('screen')) {
        screenValue = yamlDoc['screen'];
      } else {
        // Try to find any widget-like structure
        screenValue = _findRootWidget(yamlDoc);
      }

      if (screenValue == null) {
        throw FormatException('[YAMLUIParser] No valid widget definition found in YAML. Expected a "screen" key or widget definitions.');
      }

      return _parseWidgetFromYaml(screenValue);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to parse YAML UI definition: $e';
      debugPrint('[YAMLUIParser] ERROR: $errorMsg');
      debugPrint('[YAMLUIParser] Stack trace: $stackTrace');
      throw FormatException('[YAMLUIParser] $errorMsg');
    }
  }

  /// Parse a specific screen from YAML by screen ID
  /// Searches all top-level screen definitions for matching id field
  ParsedWidget parseScreenById(String yamlContent, String screenId) {
    try {
      final yamlDoc = loadYaml(yamlContent);
      
      if (yamlDoc is! Map) {
        throw FormatException('[YAMLUIParser] Expected YAML document to be a Map, got ${yamlDoc.runtimeType}');
      }

      // Search through all top-level keys for a screen with matching id
      for (final key in yamlDoc.keys) {
        final value = yamlDoc[key];
        if (value is Map && _isWidget(value)) {
          // Check if this widget has an 'id' field that matches
          final id = value['id'];
          if (id != null && id.toString() == screenId) {
            debugPrint('[YAMLUIParser] Found screen with id "$screenId" at key "$key"');
            return _parseWidgetFromYaml(value);
          }
        }
      }

      // Screen not found
      throw FormatException('[YAMLUIParser] Screen with id "$screenId" not found in YAML');
    } catch (e, stackTrace) {
      if (e is FormatException && e.message.contains('not found')) {
        rethrow;
      }
      final errorMsg = 'Failed to parse screen "$screenId" from YAML: $e';
      debugPrint('[YAMLUIParser] ERROR: $errorMsg');
      debugPrint('[YAMLUIParser] Stack trace: $stackTrace');
      throw FormatException('[YAMLUIParser] $errorMsg');
    }
  }

  /// Find root widget in YAML document
  dynamic _findRootWidget(Map yamlDoc) {
    // Look for common widget keys
    for (final key in yamlDoc.keys) {
      final value = yamlDoc[key];
      if (value is Map && _isWidget(value)) {
        return value;
      }
    }
    return null;
  }

  /// Check if a YAML map represents a widget
  bool _isWidget(Map map) {
    return map.containsKey('widgetType') ||
        map.containsKey('id') ||
        map.containsKey('entity') ||
        map.containsKey('field');
  }

  /// Parse a widget from YAML structure
  ParsedWidget _parseWidgetFromYaml(dynamic yamlValue) {
    if (yamlValue is! Map) {
      throw FormatException('[YAMLUIParser] Expected widget to be a Map, got ${yamlValue.runtimeType}');
    }

    final map = Map<String, dynamic>.from(yamlValue);
    
    // Extract widget name
    final widgetName = _extractWidgetName(map);
    
    final properties = <String, dynamic>{};
    final children = <ParsedWidget>[];

    for (final entry in map.entries) {
      final key = entry.key.toString();
      final val = entry.value;

      if (key == 'widgetType') {
        continue; // Skip metadata
      } else if (key == 'children' || key == 'fields') {
        // Handle children/fields arrays
        if (val == null) {
          continue;
        }

        // Skip empty 'children' array if we already have 'fields' (Form widgets)
        if (key == 'children' && map.containsKey('fields')) {
          if (val is List && val.isEmpty) {
            continue;
          }
        }

        if (val is List) {
          for (final child in val) {
            if (child is Map) {
              try {
                children.add(_parseWidgetFromYaml(child));
              } catch (e) {
                debugPrint('[YAMLUIParser] Failed to parse child widget: $e');
              }
            }
          }
        }
      } else {
        // Regular property
        properties[key] = _convertYamlValue(val);
      }
    }

    return ParsedWidget(
      widgetName: widgetName,
      properties: properties,
      children: children,
    );
  }

  /// Extract widget name from YAML map
  String _extractWidgetName(Map<String, dynamic> map) {
    // First try widgetType field (most reliable)
    if (map.containsKey('widgetType')) {
      return map['widgetType'].toString();
    }

    // Infer from structure
    if (map.containsKey('id') || map.containsKey('title')) {
      return 'Screen';
    }
    if (map.containsKey('entity')) {
      return 'Form';
    }
    if (map.containsKey('field') && map.containsKey('label')) {
      final typeField = map['type'];
      if (typeField != null && typeField.toString() == 'integer') {
        return 'NumberField';
      }
      return 'TextField';
    }
    if (map.containsKey('label') && map.containsKey('action')) {
      return 'ActionButton';
    }
    if (map.containsKey('text')) {
      return 'Text';
    }

    return 'Unknown';
  }

  /// Convert YAML value to Dart type
  dynamic _convertYamlValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map((e) => _convertYamlValue(e)).toList();
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = _convertYamlValue(entry.value);
      }
      return result;
    }
    return value.toString();
  }

  /// Build Flutter widget tree from parsed widget definition
  /// This method delegates to the existing UIParser's buildWidgetTree logic
  Widget buildWidgetTree(BuildContext context, ParsedWidget parsedWidget) {
    try {
      final children = parsedWidget.children
          .map((child) => buildWidgetTree(context, child))
          .toList();

      final widget = registry.buildWidget(
        parsedWidget.widgetName,
        context,
        parsedWidget.properties,
        children.isEmpty ? null : children,
      );
      
      return widget;
    } catch (e, stackTrace) {
      debugPrint('[YAMLUIParser] Error building widget tree for ${parsedWidget.widgetName}: $e');
      debugPrint('[YAMLUIParser] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
