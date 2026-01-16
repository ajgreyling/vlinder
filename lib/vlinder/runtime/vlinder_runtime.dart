import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../core/widget_registry.dart';
import '../parser/yaml_ui_parser.dart';
import '../parser/ui_parser.dart';
import '../widgets/screen.dart';
import '../widgets/form.dart';
import '../widgets/text_field.dart';
import '../widgets/number_field.dart';
import '../widgets/boolean_field.dart';
import '../widgets/single_select_field.dart';
import '../widgets/action_button.dart';
import '../../container/debug_logger.dart';

/// Main runtime engine for Vlinder
/// Coordinates parser, factory, and binding to execute ui.yaml files
class VlinderRuntime {
  final Hetu? interpreter;
  final WidgetRegistry registry;
  late final YAMLUIParser parser;
  final bool _ownsInterpreter;

  /// Create a VlinderRuntime instance
  /// 
  /// [interpreter] - Optional Hetu interpreter instance to use.
  ///                 If provided, allows access to schemas, workflows, and rules.
  ///                 Not required for YAML UI parsing, but useful for shared state.
  VlinderRuntime({Hetu? interpreter})
      : interpreter = interpreter,
        _ownsInterpreter = interpreter == null,
        registry = WidgetRegistry() {
    _registerWidgets();
    // Initialize YAML parser with the registry instance
    parser = YAMLUIParser(
      registry: registry,
    );
  }

  /// Register all SDK widgets with the registry
  void _registerWidgets() {
    debugPrint('[VlinderRuntime] Registering widgets...');
    // App & Navigation
    registry.register('Screen', VlinderScreen.fromProperties);
    debugPrint('[VlinderRuntime] Registered: Screen');

    // Form Containers
    registry.register('Form', VlinderForm.fromProperties);
    debugPrint('[VlinderRuntime] Registered: Form');

    // Input Fields - using wrapper functions to work around static method access issue
    registry.register('TextField', _buildTextField);
    debugPrint('[VlinderRuntime] Registered: TextField');
    registry.register('NumberField', _buildNumberField);
    debugPrint('[VlinderRuntime] Registered: NumberField');
    registry.register('BooleanField', _buildBooleanField);
    debugPrint('[VlinderRuntime] Registered: BooleanField');
    registry.register('SingleSelectField', _buildSingleSelectField);
    debugPrint('[VlinderRuntime] Registered: SingleSelectField');

    // Actions & Feedback
    registry.register('ActionButton', VlinderActionButton.fromProperties);
    debugPrint('[VlinderRuntime] Registered: ActionButton');

    // Display widgets
    registry.register('Text', _buildText);
    debugPrint('[VlinderRuntime] Registered: Text');
    debugPrint('[VlinderRuntime] Widget registration complete. Total widgets: ${registry.getRegisteredWidgets().length}');
  }


  /// Build TextField widget from properties
  static Widget _buildTextField(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final field = properties['field'] as String? ?? 'field';
    final label = properties['label'] as String?;
    final required = properties['required'] as bool?;
    final placeholder = properties['placeholder'] as String?;
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;

    return VlinderTextField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      readOnly: readOnly,
      visible: visible,
    );
  }

  /// Build NumberField widget from properties
  static Widget _buildNumberField(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final field = properties['field'] as String? ?? 'field';
    final label = properties['label'] as String?;
    final required = properties['required'] as bool?;
    final placeholder = properties['placeholder'] as String?;
    final type = properties['type'] as String?;
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;

    return VlinderNumberField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      type: type,
      readOnly: readOnly,
      visible: visible,
    );
  }

  /// Build BooleanField widget from properties
  static Widget _buildBooleanField(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final field = properties['field'] as String? ?? 'field';
    final label = properties['label'] as String?;
    final required = properties['required'] as bool?;
    final placeholder = properties['placeholder'] as String?;
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;

    return VlinderBooleanField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      readOnly: readOnly,
      visible: visible,
    );
  }

  /// Build SingleSelectField widget from properties
  static Widget _buildSingleSelectField(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final field = properties['field'] as String? ?? 'field';
    final label = properties['label'] as String?;
    final required = properties['required'] as bool?;
    final placeholder = properties['placeholder'] as String?;
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;
    final options = properties['options'] as List<dynamic>?;

    return VlinderSingleSelectField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      readOnly: readOnly,
      visible: visible,
      options: options,
    );
  }

  /// Build Text widget from properties
  static Widget _buildText(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final text = properties['text'] as String? ?? properties['value'] as String? ?? '';
    final style = properties['style'] as String?;
    
    TextStyle? textStyle;
    if (style == 'headline') {
      textStyle = Theme.of(context).textTheme.headlineMedium;
    } else if (style == 'title') {
      textStyle = Theme.of(context).textTheme.titleLarge;
    } else if (style == 'body') {
      textStyle = Theme.of(context).textTheme.bodyLarge;
    } else if (style == 'caption') {
      textStyle = Theme.of(context).textTheme.bodySmall;
    }

    return Padding(
      padding: EdgeInsets.all(properties['padding'] as double? ?? 16.0),
      child: Text(
        text,
        style: textStyle,
        textAlign: properties['align'] == 'center' 
            ? TextAlign.center 
            : properties['align'] == 'right'
                ? TextAlign.right
                : TextAlign.left,
      ),
    );
  }

  /// Load and parse a ui.yaml file
  /// Returns a widget tree that can be displayed
  Widget loadUI(String yamlContent, BuildContext context) {
    try {
      // Parse the YAML content
      ParsedWidget parsedWidget;
      try {
        parsedWidget = parser.parse(yamlContent);
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to parse UI YAML: $e';
        debugPrint('[VlinderRuntime] ERROR: $errorMsg');
        debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
        return _buildErrorWidget('Failed to parse UI: $e');
      }

      // Build Flutter widget tree
      Widget widget;
      try {
        widget = parser.buildWidgetTree(context, parsedWidget);
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to build widget tree for ${parsedWidget.widgetName}: $e';
        debugPrint('[VlinderRuntime] ERROR: $errorMsg');
        debugPrint('[VlinderRuntime] Widget name: ${parsedWidget.widgetName}');
        debugPrint('[VlinderRuntime] Widget properties: ${parsedWidget.properties.keys.join(", ")}');
        debugPrint('[VlinderRuntime] Children count: ${parsedWidget.children.length}');
        debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
        return _buildErrorWidget('Failed to build widget tree: $e');
      }
      
      return widget;
    } catch (e, stackTrace) {
      final errorMsg = 'Unexpected error in loadUI: $e';
      debugPrint('[VlinderRuntime] ERROR: $errorMsg');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      return _buildErrorWidget('Failed to load UI: $e');
    }
  }

  /// Load a specific screen by ID from UI YAML
  /// Takes YAML content, screen ID, and BuildContext
  /// Returns the Widget for the requested screen
  Widget loadScreenById(String yamlContent, String screenId, BuildContext context) {
    try {
      // Parse the specific screen from YAML
      ParsedWidget parsedWidget;
      try {
        parsedWidget = parser.parseScreenById(yamlContent, screenId);
        debugPrint('[VlinderRuntime] Parsed screen "$screenId" successfully');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to parse screen "$screenId" from UI YAML: $e';
        debugPrint('[VlinderRuntime] ERROR: $errorMsg');
        debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
        return _buildErrorWidget('Screen "$screenId" not found: $e');
      }

      // Build Flutter widget tree
      Widget widget;
      try {
        widget = parser.buildWidgetTree(context, parsedWidget);
        debugPrint('[VlinderRuntime] Built widget tree for screen "$screenId"');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to build widget tree for screen "$screenId": $e';
        debugPrint('[VlinderRuntime] ERROR: $errorMsg');
        debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
        return _buildErrorWidget('Failed to build screen "$screenId": $e');
      }
      
      return widget;
    } catch (e, stackTrace) {
      final errorMsg = 'Unexpected error loading screen "$screenId": $e';
      debugPrint('[VlinderRuntime] ERROR: $errorMsg');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      return _buildErrorWidget('Failed to load screen "$screenId": $e');
    }
  }

  /// Load UI from asset file
  Future<Widget> loadUIFromAsset(
    String assetPath,
    BuildContext context,
  ) async {
    try {
      // In a real implementation, you'd load from assets
      // For now, return an error widget
      return _buildErrorWidget('Asset loading not yet implemented');
    } catch (e) {
      return _buildErrorWidget('Failed to load UI from asset: $e');
    }
  }

  /// Execute Hetu script code (for rules, workflows, etc.)
  /// Requires interpreter to be provided
  void executeScript(String scriptContent, {String? scriptName}) {
    if (interpreter == null) {
      throw StateError('Cannot execute script: no interpreter provided');
    }
    
    final scriptPreview = scriptContent.length > 200 
        ? scriptContent.substring(0, 200) 
        : scriptContent;
    
    try {
      debugPrint('[VlinderRuntime] Executing script${scriptName != null ? " ($scriptName)" : ""} (${scriptContent.length} characters)');
      debugPrint('[VlinderRuntime] Script preview: $scriptPreview...');
      interpreter!.eval(scriptContent);
      debugPrint('[VlinderRuntime] Script executed successfully${scriptName != null ? " ($scriptName)" : ""}');
    } catch (e, stackTrace) {
      final errorMsg = 'Script execution error${scriptName != null ? " in $scriptName" : ""}: $e';
      debugPrint('[VlinderRuntime] ERROR: $errorMsg');
      debugPrint('[VlinderRuntime] Script preview: $scriptPreview...');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get a value from the Hetu interpreter
  /// Requires interpreter to be provided
  dynamic getValue(String identifier) {
    if (interpreter == null) {
      throw StateError('Cannot get value: no interpreter provided');
    }
    
    try {
      debugPrint('[VlinderRuntime] Fetching value: $identifier');
      final value = interpreter!.fetch(identifier);
      debugPrint('[VlinderRuntime] Successfully fetched "$identifier": ${value.runtimeType}');
      return value;
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to get value "$identifier": $e';
      debugPrint('[VlinderRuntime] ERROR: $errorMsg');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      return null;
    }
  }

  Widget _buildErrorWidget(String message) {
    return Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'UI Loading Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

