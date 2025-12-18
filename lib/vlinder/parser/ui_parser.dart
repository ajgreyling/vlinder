import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
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
    // Check if functions are already defined to avoid redefinition errors
    try {
      interpreter.fetch('Screen');
      // Functions already exist, skip definition
      debugPrint('[UIParser] Widget constructors already defined, skipping initialization');
      return;
    } catch (_) {
      // Functions don't exist, proceed with definition
      debugPrint('[UIParser] Initializing widget constructors');
    }

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
      
      fun Text(text, style, align, padding) {
        final result = {
          widgetType: 'Text',
          text: text,
          style: style,
          align: align,
          padding: padding,
        }
        return result
      }
    ''';

    try {
      interpreter.eval(widgetConstructors);
      debugPrint('[UIParser] Widget constructors initialized successfully');
    } catch (e) {
      debugPrint('[UIParser] Warning: Could not initialize widget constructors: $e');
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
      debugPrint('[UIParser] Parsing UI script (${scriptContent.length} characters)');
      // Widget constructors are already defined in constructor, just evaluate user script
      debugPrint('[UIParser] Evaluating Hetu script...');
      interpreter.eval(scriptContent);
      debugPrint('[UIParser] UI script evaluated successfully');

      // Try to get the 'screen' variable (common root widget)
      dynamic screenValue;
      try {
        debugPrint('[UIParser] Attempting to fetch "screen" variable...');
        screenValue = interpreter.fetch('screen');
        debugPrint('[UIParser] Successfully fetched "screen" variable: ${screenValue.runtimeType}');
      } catch (e) {
        debugPrint('[UIParser] Failed to fetch "screen": $e');
        // Try alternative names
        try {
          debugPrint('[UIParser] Attempting to fetch "Screen" variable...');
          screenValue = interpreter.fetch('Screen');
          debugPrint('[UIParser] Successfully fetched "Screen" variable: ${screenValue.runtimeType}');
        } catch (_) {
          debugPrint('[UIParser] Failed to fetch "Screen", trying to find root widget...');
          // Try to find any variable that's a widget
          screenValue = _findRootWidget();
          if (screenValue != null) {
            debugPrint('[UIParser] Found root widget: ${screenValue.runtimeType}');
          } else {
            debugPrint('[UIParser] No root widget found');
          }
        }
      }

      if (screenValue != null) {
        debugPrint('[UIParser] Parsing HTValue to ParsedWidget...');
        final parsed = parseFromHTValue(screenValue);
        debugPrint('[UIParser] Parsed widget: ${parsed.widgetName} with ${parsed.children.length} children');
        return parsed;
      }

      // Fallback: try to extract from script string
      debugPrint('[UIParser] Falling back to string-based extraction...');
      final widget = _extractWidgetTree(scriptContent);
      
      if (widget == null) {
        throw FormatException('No valid widget definition found in script. Expected a variable named "screen" or widget definitions.');
      }

      debugPrint('[UIParser] Extracted widget from string: ${widget.widgetName}');
      return widget;
    } catch (e, stackTrace) {
      debugPrint('[UIParser] Error parsing UI script: $e');
      debugPrint('[UIParser] Stack trace: $stackTrace');
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
      
      fun Text(text, style, align, padding) {
        final result = {
          widgetType: 'Text',
          text: text,
          style: style,
          align: align,
          padding: padding,
        }
        return result
      }
    ''';
  }

  /// Find root widget by checking all variables
  dynamic _findRootWidget() {
    // Try common variable names
    final commonNames = ['screen', 'root', 'app', 'main'];
    for (final name in commonNames) {
      try {
        final value = interpreter.fetch(name);
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
    debugPrint('[UIParser] buildWidgetTree: building ${parsedWidget.widgetName} with ${parsedWidget.children.length} children');
    debugPrint('[UIParser] Properties: ${parsedWidget.properties.keys.join(", ")}');
    
    try {
      final children = parsedWidget.children
          .map((child) {
            debugPrint('[UIParser] Building child widget: ${child.widgetName}');
            return buildWidgetTree(context, child);
          })
          .toList();

      debugPrint('[UIParser] Built ${children.length} child widgets for ${parsedWidget.widgetName}');
      debugPrint('[UIParser] Calling registry.buildWidget for ${parsedWidget.widgetName}...');
      
      final widget = registry.buildWidget(
        parsedWidget.widgetName,
        context,
        parsedWidget.properties,
        children.isEmpty ? null : children,
      );
      
      debugPrint('[UIParser] Successfully built widget: ${widget.runtimeType}');
      return widget;
    } catch (e, stackTrace) {
      debugPrint('[UIParser] Error building widget tree for ${parsedWidget.widgetName}: $e');
      debugPrint('[UIParser] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Parse widget from Hetu HTValue (more robust approach)
  /// Recursively parses widget tree with accurate type detection
  ParsedWidget parseFromHTValue(dynamic value) {
    if (value is! HTStruct) {
      debugPrint('[UIParser] parseFromHTValue: Expected HTStruct, got ${value.runtimeType}');
      throw ArgumentError('Expected HTStruct for widget definition, got ${value.runtimeType}');
    }

    // Extract widget name using improved detection
    final widgetName = _extractWidgetName(value);
    debugPrint('[UIParser] parseFromHTValue: Parsing widget "$widgetName"');
    debugPrint('[UIParser] parseFromHTValue: HTStruct keys: ${value.keys.join(", ")}');
    
    final properties = <String, dynamic>{};
    final children = <ParsedWidget>[];

    for (final key in value.keys) {
      final keyStr = key;
      final val = value[key];
      
      // Handle children arrays (can be 'children' or 'fields')
      if ((keyStr == 'children' || keyStr == 'fields') && val is List) {
        debugPrint('[UIParser] parseFromHTValue: Found $keyStr array with ${val.length} items');
        // Parse children recursively
        for (var i = 0; i < val.length; i++) {
          final child = val[i];
          if (child is HTStruct) {
            debugPrint('[UIParser] parseFromHTValue: Parsing child $i of $keyStr');
            children.add(parseFromHTValue(child));
          } else {
            // Handle primitive values in arrays
            debugPrint('[UIParser] Warning: Non-struct child in $keyStr[$i]: ${child.runtimeType}');
          }
        }
        debugPrint('[UIParser] parseFromHTValue: Parsed ${children.length} children from $keyStr');
      } else if (keyStr != 'widgetType') {
        // Store property, but skip widgetType (it's metadata)
        properties[keyStr] = WidgetRegistry.htValueToDart(val);
        debugPrint('[UIParser] parseFromHTValue: Stored property "$keyStr"');
      }
    }

    debugPrint('[UIParser] parseFromHTValue: Completed parsing "$widgetName" with ${properties.length} properties and ${children.length} children');
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
      if (widgetType is String) {
        return widgetType;
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

