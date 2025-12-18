import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../core/widget_registry.dart';

/// Parsed widget definition from Hetu script
class ParsedWidget {
  final String widgetName;
  final Map<String, dynamic> properties;
  final List<ParsedWidget> children;

  ParsedWidget({
    required this.widgetName,
    required this.properties,
    this.children = const [],
  });
}

/// Parser for Hetu script UI definitions
/// Uses AST parsing to accurately detect widget types
class UIParser {
  final Hetu interpreter;
  final WidgetRegistry registry;
  final Map<String, String> _widgetTypeMap = {}; // Maps variable names to widget types

  UIParser({
    required this.interpreter,
    required this.registry,
  }) {
    _initializeWidgetConstructors();
  }

  /// Initialize widget constructor functions in Hetu
  /// These functions wrap widget creation and track widget types
  void _initializeWidgetConstructors() {
    final widgetConstructors = '''
      fun Screen(id, title, children) {
        final result = {
          widgetType: 'Screen',
          id: id,
          title: title,
          children: children ?? [],
        }
        return result
      }
      
      fun Form(entity, fields, children) {
        final result = {
          widgetType: 'Form',
          entity: entity,
          fields: fields ?? [],
          children: children ?? [],
        }
        return result
      }
      
      fun TextField(field, label, required, placeholder) {
        final result = {
          widgetType: 'TextField',
          field: field,
          label: label,
          required: required ?? false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun NumberField(field, label, type, required, placeholder) {
        final result = {
          widgetType: 'NumberField',
          field: field,
          label: label,
          type: type,
          required: required ?? false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun ActionButton(label, action, style) {
        final result = {
          widgetType: 'ActionButton',
          label: label,
          action: action,
          style: style,
        }
        return result
      }
    ''';

    try {
      interpreter.eval(widgetConstructors);
    } catch (e) {
      debugPrint('Warning: Could not initialize widget constructors: $e');
    }
  }

  /// Parse a ui.ht file and extract widget tree
  /// 
  /// The Hetu script should define widgets using function calls or struct literals.
  /// Example:
  /// ```hetu
  /// final screen = Screen(
  ///   id: 'form1',
  ///   children: [
  ///     Form(entity: 'Customer', ...),
  ///   ],
  /// );
  /// ```
  ParsedWidget parse(String scriptContent) {
    try {
      // Combine widget constructors with user script
      final fullScript = _getWidgetConstructorsScript() + '\n\n' + scriptContent;
      
      // Load the script into Hetu interpreter
      interpreter.eval(fullScript);

      // Try to get the 'screen' variable (common root widget)
      HTValue? screenValue;
      try {
        screenValue = interpreter.getType('screen');
      } catch (e) {
        // Try alternative names
        try {
          screenValue = interpreter.getType('Screen');
        } catch (_) {
          // Try to find any variable that's a widget
          screenValue = _findRootWidget();
        }
      }

      if (screenValue != null) {
        return parseFromHTValue(screenValue);
      }

      // Fallback: try to extract from script string
      final widget = _extractWidgetTree(scriptContent);
      
      if (widget == null) {
        throw FormatException('No valid widget definition found in script. Expected a variable named "screen" or widget definitions.');
      }

      return widget;
    } catch (e) {
      throw FormatException('Failed to parse UI script: $e');
    }
  }

  /// Get widget constructor functions script
  String _getWidgetConstructorsScript() {
    return '''
      fun Screen(id, title, children) {
        final result = {
          widgetType: 'Screen',
          id: id,
          title: title,
          children: children ?? [],
        }
        return result
      }
      
      fun Form(entity, fields, children) {
        final result = {
          widgetType: 'Form',
          entity: entity,
          fields: fields ?? [],
          children: children ?? [],
        }
        return result
      }
      
      fun TextField(field, label, required, placeholder) {
        final result = {
          widgetType: 'TextField',
          field: field,
          label: label,
          required: required ?? false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun NumberField(field, label, type, required, placeholder) {
        final result = {
          widgetType: 'NumberField',
          field: field,
          label: label,
          type: type,
          required: required ?? false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun ActionButton(label, action, style) {
        final result = {
          widgetType: 'ActionButton',
          label: label,
          action: action,
          style: style,
        }
        return result
      }
    ''';
  }

  /// Find root widget by checking all variables
  HTValue? _findRootWidget() {
    // Try common variable names
    final commonNames = ['screen', 'root', 'app', 'main'];
    for (final name in commonNames) {
      try {
        final value = interpreter.getType(name);
        if (value is HTStruct && _isWidget(value)) {
          return value;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Check if a value is a widget struct
  bool _isWidget(HTStruct struct) {
    return struct.containsKey('widgetType') ||
        struct.containsKey('id') ||
        struct.containsKey('entity') ||
        struct.containsKey('field');
  }

  /// Extract widget tree from Hetu script
  /// This is a simplified parser - in production, you'd use Hetu's AST
  ParsedWidget? _extractWidgetTree(String script) {
    // For now, we'll use a simple approach: evaluate the script
    // and look for widget-like structures
    // In a full implementation, you'd parse the Hetu AST
    
    // Try to find a Screen widget first (common root)
    final screenMatch = RegExp(r'Screen\s*\(([^)]*)\)').firstMatch(script);
    if (screenMatch != null) {
      return _parseWidgetFromString('Screen', screenMatch.group(1) ?? '');
    }

    // Try Form
    final formMatch = RegExp(r'Form\s*\(([^)]*)\)').firstMatch(script);
    if (formMatch != null) {
      return _parseWidgetFromString('Form', formMatch.group(1) ?? '');
    }

    return null;
  }

  /// Parse widget properties from string representation
  ParsedWidget _parseWidgetFromString(String widgetName, String propertiesStr) {
    final properties = <String, dynamic>{};
    final children = <ParsedWidget>[];

    // Simple property parser - parse key: value pairs
    final propPattern = RegExp(r'(\w+)\s*:\s*([^,)]+)');
    final matches = propPattern.allMatches(propertiesStr);

    for (final match in matches) {
      final key = match.group(1)!;
      var value = match.group(2)!.trim();

      // Remove quotes if present
      if (value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      } else if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }

      // Try to parse as number
      if (RegExp(r'^\d+$').hasMatch(value)) {
        properties[key] = int.parse(value);
      } else if (RegExp(r'^\d+\.\d+$').hasMatch(value)) {
        properties[key] = double.parse(value);
      } else if (value == 'true' || value == 'false') {
        properties[key] = value == 'true';
      } else {
        properties[key] = value;
      }
    }

    return ParsedWidget(
      widgetName: widgetName,
      properties: properties,
      children: children,
    );
  }

  /// Build Flutter widget tree from parsed widget definition
  Widget buildWidgetTree(BuildContext context, ParsedWidget parsedWidget) {
    final children = parsedWidget.children
        .map((child) => buildWidgetTree(context, child))
        .toList();

    return registry.buildWidget(
      parsedWidget.widgetName,
      context,
      parsedWidget.properties,
      children.isEmpty ? null : children,
    );
  }

  /// Parse widget from Hetu HTValue (more robust approach)
  /// Recursively parses widget tree with accurate type detection
  ParsedWidget parseFromHTValue(HTValue value) {
    if (value is! HTStruct) {
      throw ArgumentError('Expected HTStruct for widget definition, got ${value.runtimeType}');
    }

    // Extract widget name using improved detection
    final widgetName = _extractWidgetName(value);
    
    final properties = <String, dynamic>{};
    final children = <ParsedWidget>[];

    value.forEach((key, val) {
      final keyStr = key.toString();
      
      // Handle children arrays (can be 'children' or 'fields')
      if ((keyStr == 'children' || keyStr == 'fields') && val is HTList) {
        // Parse children recursively
        for (final child in val) {
          if (child is HTStruct) {
            children.add(parseFromHTValue(child));
          } else {
            // Handle primitive values in arrays
            debugPrint('Warning: Non-struct child in $keyStr: ${child.runtimeType}');
          }
        }
      } else if (keyStr != 'widgetType') {
        // Store property, but skip widgetType (it's metadata)
        properties[keyStr] = WidgetRegistry.htValueToDart(val);
      }
    });

    return ParsedWidget(
      widgetName: widgetName,
      properties: properties,
      children: children,
    );
  }

  /// Extract widget name from HTStruct
  /// Uses widgetType field set by constructor functions for accurate detection
  String _extractWidgetName(HTStruct struct) {
    // First check for explicit widgetType (set by constructor functions)
    if (struct.containsKey('widgetType')) {
      final widgetType = struct['widgetType'];
      if (widgetType is HTString) {
        return widgetType.value;
      }
      return widgetType.toString();
    }
    
    // Fallback: infer from structure (for backward compatibility)
    if (struct.containsKey('id') || struct.containsKey('title')) {
      return 'Screen';
    }
    if (struct.containsKey('entity')) {
      return 'Form';
    }
    if (struct.containsKey('field') && struct.containsKey('label')) {
      final typeField = struct['type'];
      if (typeField != null && typeField.toString() == 'integer') {
        return 'NumberField';
      }
      return 'TextField';
    }
    if (struct.containsKey('label') && struct.containsKey('action')) {
      return 'ActionButton';
    }
    
    return 'Unknown';
  }
}

