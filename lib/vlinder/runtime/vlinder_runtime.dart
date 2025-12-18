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
    // App & Navigation
    registry.register('Screen', VlinderScreen.fromProperties);

    // Form Containers
    registry.register('Form', VlinderForm.fromProperties);

    // Input Fields - using wrapper functions to work around static method access issue
    registry.register('TextField', _buildTextField);
    registry.register('NumberField', _buildNumberField);

    // Actions & Feedback
    registry.register('ActionButton', VlinderActionButton.fromProperties);
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

  /// Load and parse a ui.ht file
  /// Returns a widget tree that can be displayed
  Widget loadUI(String scriptContent, BuildContext context) {
    try {
      // Parse the Hetu script
      final parsedWidget = parser.parse(scriptContent);

      // Build Flutter widget tree
      return parser.buildWidgetTree(context, parsedWidget);
    } catch (e) {
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

