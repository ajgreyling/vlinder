import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../core/widget_registry.dart';
import '../parser/ui_parser.dart';
import '../widgets/screen.dart';
import '../widgets/form.dart';
import '../widgets/text_field.dart';
import '../widgets/number_field.dart';
import '../widgets/action_button.dart';
import '../../container/debug_logger.dart';

/// Main runtime engine for Vlinder
/// Coordinates parser, factory, and binding to execute ui.ht files
class VlinderRuntime {
  final Hetu interpreter;
  final WidgetRegistry registry;
  late final UIParser parser;
  final bool _ownsInterpreter;

  /// Create a VlinderRuntime instance
  /// 
  /// [interpreter] - Optional Hetu interpreter instance to use.
  ///                 If not provided, a new interpreter will be created.
  ///                 Sharing an interpreter allows UI scripts to access
  ///                 schemas, workflows, and rules loaded in other parsers.
  VlinderRuntime({Hetu? interpreter})
      : interpreter = interpreter ?? Hetu(),
        _ownsInterpreter = interpreter == null,
        registry = WidgetRegistry() {
    // Only initialize if we own the interpreter (newly created)
    // If shared, assume it's already initialized
    if (_ownsInterpreter) {
      this.interpreter.init();
    }
    _registerWidgets();
    _registerLoggingFunctions();
    // Initialize parser with the same registry instance
    parser = UIParser(
      interpreter: this.interpreter,
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

  /// Register logging functions in Hetu interpreter
  /// These functions allow .ht files to log messages that are sent to the debug logger
  void _registerLoggingFunctions() {
    debugPrint('[VlinderRuntime] Registering logging functions...');
    
    // Check if functions are already defined to avoid redefinition errors
    try {
      interpreter.fetch('log');
      debugPrint('[VlinderRuntime] Logging functions already defined, skipping registration');
      return;
    } catch (_) {
      // Functions don't exist, proceed with definition
    }

    final loggingScript = '''
      // Logging functions for Hetu scripts
      // These functions store logs in a global _hetuLogs array
      // The logs are processed after script evaluation
      
      var _hetuLogs = []
      
      fun log(message) {
        // DEBUG level logging
        final logEntry = {
          level: "DEBUG",
          message: (message ?? "").toString()
        }
        _hetuLogs.add(logEntry)
        return logEntry.message
      }
      
      fun logInfo(message) {
        // INFO level logging
        final logEntry = {
          level: "INFO",
          message: (message ?? "").toString()
        }
        _hetuLogs.add(logEntry)
        return logEntry.message
      }
      
      fun logWarning(message) {
        // WARNING level logging
        final logEntry = {
          level: "WARNING",
          message: (message ?? "").toString()
        }
        _hetuLogs.add(logEntry)
        return logEntry.message
      }
      
      fun logError(message) {
        // ERROR level logging
        final logEntry = {
          level: "ERROR",
          message: (message ?? "").toString()
        }
        _hetuLogs.add(logEntry)
        return logEntry.message
      }
    ''';

    try {
      interpreter.eval(loggingScript);
      debugPrint('[VlinderRuntime] Logging functions registered successfully');
    } catch (e) {
      debugPrint('[VlinderRuntime] Warning: Could not register logging functions: $e');
    }
  }

  /// Process logs from Hetu scripts after evaluation
  /// Extracts logs from _hetuLogs array and sends them to debug logger
  void _processHetuLogs() {
    try {
      final logsValue = interpreter.fetch('_hetuLogs');
      if (logsValue is List && logsValue.isNotEmpty) {
        debugPrint('[VlinderRuntime] Processing ${logsValue.length} Hetu log entries');
        for (final logEntry in logsValue) {
          if (logEntry is Map) {
            final level = logEntry['level']?.toString() ?? 'DEBUG';
            final message = logEntry['message']?.toString() ?? '';
            _logFromHetu(level, message);
          }
        }
        // Clear the logs array
        interpreter.eval('_hetuLogs = []');
      }
    } catch (e) {
      // Ignore errors - logging is not critical
      debugPrint('[VlinderRuntime] Warning: Could not process Hetu logs: $e');
    }
  }

  /// Helper method to log from Hetu scripts
  /// Called when processing Hetu logs after script evaluation
  void _logFromHetu(String level, String message) {
    // Use debugPrint which is intercepted by DebugLogger
    // Component will be extracted as "HetuScript"
    final component = 'HetuScript';
    final logMessage = level == 'DEBUG' 
        ? '[$component] $message'
        : level == 'INFO'
            ? '[$component] INFO: $message'
            : level == 'WARNING'
                ? '[$component] WARNING: $message'
                : '[$component] ERROR: $message';
    
    debugPrint(logMessage);
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
      // Parse the Hetu script
      ParsedWidget parsedWidget;
      try {
        parsedWidget = parser.parse(scriptContent);
        
        // Process any logs from Hetu script execution
        _processHetuLogs();
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to parse UI script: $e';
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
  void executeScript(String scriptContent, {String? scriptName}) {
    final scriptPreview = scriptContent.length > 200 
        ? scriptContent.substring(0, 200) 
        : scriptContent;
    
    try {
      debugPrint('[VlinderRuntime] Executing script${scriptName != null ? " ($scriptName)" : ""} (${scriptContent.length} characters)');
      debugPrint('[VlinderRuntime] Script preview: $scriptPreview...');
      interpreter.eval(scriptContent);
      debugPrint('[VlinderRuntime] Script executed successfully${scriptName != null ? " ($scriptName)" : ""}');
      
      // Process any logs from Hetu script execution
      _processHetuLogs();
    } catch (e, stackTrace) {
      final errorMsg = 'Script execution error${scriptName != null ? " in $scriptName" : ""}: $e';
      debugPrint('[VlinderRuntime] ERROR: $errorMsg');
      debugPrint('[VlinderRuntime] Script preview: $scriptPreview...');
      debugPrint('[VlinderRuntime] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get a value from the Hetu interpreter
  dynamic getValue(String identifier) {
    try {
      debugPrint('[VlinderRuntime] Fetching value: $identifier');
      final value = interpreter.fetch(identifier);
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

