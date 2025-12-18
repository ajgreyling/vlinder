import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../core/widget_registry.dart';
import '../parser/ui_parser.dart';
import '../widgets/screen.dart';
import '../widgets/form.dart';
import '../widgets/text_field.dart';
import '../widgets/number_field.dart';
import '../widgets/action_button.dart';

/// Main runtime engine for Vlinder
/// Coordinates parser, factory, and binding to execute ui.ht files
class VlinderRuntime {
  final Hetu interpreter;
  final WidgetRegistry registry;
  late final UIParser parser;

  VlinderRuntime()
      : interpreter = Hetu(),
        registry = WidgetRegistry() {
    interpreter.init();
    _registerWidgets();
    // Initialize parser with the same registry instance
    parser = UIParser(
      interpreter: interpreter,
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

    return VlinderTextField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
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

    return VlinderNumberField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      type: type,
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
    debugPrint('[VlinderRuntime] Building Text widget: text="$text", style=$style');
    
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

  /// Load and parse a ui.ht file
  /// Returns a widget tree that can be displayed
  Widget loadUI(String scriptContent, BuildContext context) {
    try {
      debugPrint('[VlinderRuntime] loadUI called with script length: ${scriptContent.length}');
      debugPrint('[VlinderRuntime] Script preview (first 200 chars): ${scriptContent.substring(0, scriptContent.length > 200 ? 200 : scriptContent.length)}...');
      
      // Parse the Hetu script
      debugPrint('[VlinderRuntime] Parsing UI script...');
      final parsedWidget = parser.parse(scriptContent);
      debugPrint('[VlinderRuntime] Parse successful: widgetName=${parsedWidget.widgetName}, properties=${parsedWidget.properties.keys.join(", ")}, childrenCount=${parsedWidget.children.length}');

      // Build Flutter widget tree
      debugPrint('[VlinderRuntime] Building widget tree...');
      final widget = parser.buildWidgetTree(context, parsedWidget);
      debugPrint('[VlinderRuntime] Widget tree built successfully: ${widget.runtimeType}');
      return widget;
    } catch (e, stackTrace) {
      debugPrint('[VlinderRuntime] Error in loadUI: $e');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      return _buildErrorWidget('Failed to load UI: $e');
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
  void executeScript(String scriptContent) {
    try {
      interpreter.eval(scriptContent);
    } catch (e) {
      debugPrint('Script execution error: $e');
      rethrow;
    }
  }

  /// Get a value from the Hetu interpreter
  dynamic getValue(String identifier) {
    try {
      return interpreter.fetch(identifier);
    } catch (e) {
      debugPrint('Failed to get value "$identifier": $e');
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

