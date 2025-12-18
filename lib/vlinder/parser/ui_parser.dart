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
      fun Screen({id, title, children}) {
        // Explicitly handle children parameter
        // Hetu may pass children as null, undefined, or an empty list
        var childrenList = []
        if (children != null) {
          // If children is provided, use it directly
          // Hetu should have already evaluated the array elements
          if (children is List) {
            childrenList = children
          } else {
            // If it's not a list, wrap it in a list
            childrenList = [children]
          }
        }
        final result = {
          widgetType: 'Screen',
          id: id,
          title: title,
          children: childrenList,
        }
        return result
      }
      
      fun Form({entity, fields, children}) {
        // Explicitly handle fields and children parameters
        var fieldsList = []
        if (fields != null) {
          if (fields is List) {
            fieldsList = fields
          } else {
            fieldsList = [fields]
          }
        }
        var childrenList = []
        if (children != null) {
          if (children is List) {
            childrenList = children
          } else {
            childrenList = [children]
          }
        }
        final result = {
          widgetType: 'Form',
          entity: entity,
          fields: fieldsList,
          children: childrenList,
        }
        return result
      }
      
      fun TextField({field, label, required, placeholder}) {
        final result = {
          widgetType: 'TextField',
          field: field,
          label: label,
          required: (required != null) ? required : false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun NumberField({field, label, type, required, placeholder}) {
        final result = {
          widgetType: 'NumberField',
          field: field,
          label: label,
          type: type,
          required: (required != null) ? required : false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun ActionButton({label, action, style}) {
        final result = {
          widgetType: 'ActionButton',
          label: label,
          action: action,
          style: style,
        }
        return result
      }
      
      fun Text({text, style, align, padding}) {
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
    final scriptPreview = scriptContent.length > 300 
        ? scriptContent.substring(0, 300) 
        : scriptContent;
    
    try {
      // Widget constructors are already defined in constructor, just evaluate user script
      try {
        interpreter.eval(scriptContent);
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to evaluate UI script: $e';
        debugPrint('[UIParser] ERROR: $errorMsg');
        debugPrint('[UIParser] Script preview: $scriptPreview...');
        debugPrint('[UIParser] Stack trace: $stackTrace');
        
        // Try to extract line number from Hetu error if available
        String enhancedError = errorMsg;
        if (e.toString().contains('line') || e.toString().contains('Line')) {
          enhancedError = '$errorMsg (check line numbers in error message)';
        }
        
        throw FormatException('[UIParser] $enhancedError');
      }

      // Try to get the 'screen' variable (common root widget)
      dynamic screenValue;
      try {
        screenValue = interpreter.fetch('screen');
      } catch (e) {
        // Try alternative names
        try {
          screenValue = interpreter.fetch('Screen');
        } catch (_) {
          // Try to find any variable that's a widget
          screenValue = _findRootWidget();
        }
      }

      if (screenValue != null) {
        final parsed = parseFromHTValue(screenValue);
        return parsed;
      }

      // Fallback: try to extract from script string
      final widget = _extractWidgetTree(scriptContent);
      
      if (widget == null) {
        throw FormatException('No valid widget definition found in script. Expected a variable named "screen" or widget definitions.');
      }

      return widget;
    } catch (e, stackTrace) {
      if (e is FormatException && e.message.contains('[UIParser]')) {
        rethrow;
      }
      final errorMsg = 'Failed to parse UI script: $e';
      debugPrint('[UIParser] ERROR: $errorMsg');
      debugPrint('[UIParser] Script preview: $scriptPreview...');
      debugPrint('[UIParser] Stack trace: $stackTrace');
      throw FormatException('[UIParser] $errorMsg');
    }
  }

  /// Get widget constructor functions script
  String _getWidgetConstructorsScript() {
    return '''
      fun Screen({id, title, children}) {
        final result = {
          widgetType: 'Screen',
          id: id,
          title: title,
          children: children ?? [],
        }
        return result
      }
      
      fun Form({entity, fields, children}) {
        final result = {
          widgetType: 'Form',
          entity: entity,
          fields: fields ?? [],
          children: children ?? [],
        }
        return result
      }
      
      fun TextField({field, label, required, placeholder}) {
        final result = {
          widgetType: 'TextField',
          field: field,
          label: label,
          required: required ?? false,
          placeholder: placeholder,
        }
        return result
      }
      
      fun NumberField({field, label, type, required, placeholder}) {
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
      
      fun ActionButton({label, action, style}) {
        final result = {
          widgetType: 'ActionButton',
          label: label,
          action: action,
          style: style,
        }
        return result
      }
      
      fun Text({text, style, align, padding}) {
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
    
    final properties = <String, dynamic>{};
    final children = <ParsedWidget>[];

    for (final key in value.keys) {
      final keyStr = key;
      final val = value[key];
      
      // Handle children arrays (can be 'children' or 'fields')
      if (keyStr == 'children' || keyStr == 'fields') {
        // Handle null case
        if (val == null) {
          continue;
        }
        
        // Skip empty 'children' array if we already have 'fields' (Form widgets)
        // Form widgets use 'fields' for their child widgets, 'children' is typically empty
        if (keyStr == 'children' && value.containsKey('fields')) {
          if (val is List && (val as List).isEmpty) {
            continue;
          }
        }
        
        // Parse children directly from HTStruct without converting first
        // This preserves HTStruct objects that would be lost in conversion
        if (val is List || val is Iterable) {
          final iterable = val is List ? val : (val as Iterable).toList();
          // Iterate directly over the list without converting
          for (var i = 0; i < iterable.length; i++) {
            final child = iterable[i];
            
            if (child is HTStruct) {
              // Parse HTStruct directly - this is the preferred path
              try {
                children.add(parseFromHTValue(child));
              } catch (e) {
                debugPrint('[UIParser] parseFromHTValue: Failed to parse child $i from HTStruct: $e');
              }
            } else if (child is Map) {
              // Handle Map (from previous conversion or other source)
              if (child.containsKey('widgetType') || 
                  child.containsKey('id') || 
                  child.containsKey('entity') || 
                  child.containsKey('field')) {
                try {
                  final childMap = Map<String, dynamic>.from(child);
                  final childWidget = _parseFromMap(childMap);
                  if (childWidget != null) {
                    children.add(childWidget);
                  }
                } catch (e) {
                  debugPrint('[UIParser] parseFromHTValue: Failed to parse child $i from Map: $e');
                }
              }
            }
          }
        } else {
          // Not a List - try converting to see what we get
          final dartVal = WidgetRegistry.htValueToDart(val);
          
          if (dartVal is List) {
            // Parse children from converted list
            for (var i = 0; i < dartVal.length; i++) {
              final child = dartVal[i];
              
              if (child is Map) {
                if (child.containsKey('widgetType') || 
                    child.containsKey('id') || 
                    child.containsKey('entity') || 
                    child.containsKey('field')) {
                  try {
                    final childMap = Map<String, dynamic>.from(child);
                    final childWidget = _parseFromMap(childMap);
                    if (childWidget != null) {
                      children.add(childWidget);
                    }
                  } catch (e) {
                    debugPrint('[UIParser] parseFromHTValue: Failed to parse child $i from Map: $e');
                  }
                }
              } else if (child is HTStruct) {
                try {
                  children.add(parseFromHTValue(child));
                } catch (e) {
                  debugPrint('[UIParser] parseFromHTValue: Failed to parse child $i from HTStruct: $e');
                }
              }
            }
          }
        }
      } else if (keyStr != 'widgetType') {
        // Store property, but skip widgetType (it's metadata)
        properties[keyStr] = WidgetRegistry.htValueToDart(val);
      }
    }
    return ParsedWidget(
      widgetName: widgetName,
      properties: properties,
      children: children,
    );
  }

  /// Parse widget from Map (used when converting from HTStruct to Dart Map)
  ParsedWidget? _parseFromMap(Map<String, dynamic> map) {
    try {
      final widgetName = map['widgetType']?.toString() ?? _inferWidgetNameFromMap(map);
      if (widgetName == 'Unknown') {
        return null;
      }
      
      final properties = <String, dynamic>{};
      final children = <ParsedWidget>[];
      
      for (final entry in map.entries) {
        final key = entry.key;
        final val = entry.value;
        
        if (key == 'widgetType') {
          continue; // Skip metadata
        } else if (key == 'children' || key == 'fields') {
          if (val is List) {
            for (final child in val) {
              if (child is Map) {
                final childWidget = _parseFromMap(child as Map<String, dynamic>);
                if (childWidget != null) {
                  children.add(childWidget);
                }
              } else if (child is HTStruct) {
                children.add(parseFromHTValue(child));
              }
            }
          }
        } else {
          properties[key] = val;
        }
      }
      
      return ParsedWidget(
        widgetName: widgetName,
        properties: properties,
        children: children,
      );
    } catch (e) {
      debugPrint('[UIParser] _parseFromMap error: $e');
      return null;
    }
  }

  /// Infer widget name from Map structure
  String _inferWidgetNameFromMap(Map<String, dynamic> map) {
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

