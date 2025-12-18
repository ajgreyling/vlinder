import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../binding/drift_binding.dart';

/// Handler for executing Hetu script actions
/// Supports navigation, form submission, and workflow transitions
class ActionHandler {
  final Hetu interpreter;
  final BuildContext? context;
  final FormStateManager? formState;
  final VoidCallback? onNavigation;

  ActionHandler({
    required this.interpreter,
    this.context,
    this.formState,
    this.onNavigation,
  });

  /// Execute an action by name
  /// Actions are Hetu script functions that can access form state and perform operations
  Future<void> executeAction(String actionName, {Map<String, dynamic>? params}) async {
    try {
      debugPrint('[ActionHandler] Executing action: $actionName');
      debugPrint('[ActionHandler] Parameters: $params');
      
      // Prepare action context
      final actionContext = _prepareActionContext(params);
      debugPrint('[ActionHandler] Action context prepared: ${actionContext.keys.join(", ")}');
      
      // Inject context into Hetu interpreter
      try {
        _injectActionContext(actionContext);
        debugPrint('[ActionHandler] Action context injected successfully');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to inject action context: $e';
        debugPrint('[ActionHandler] ERROR: $errorMsg');
        debugPrint('[ActionHandler] Stack trace: $stackTrace');
        throw Exception('Failed to prepare action context: $e');
      }

      // Try to call the action function
      try {
        debugPrint('[ActionHandler] Invoking Hetu function: $actionName');
        interpreter.invoke(actionName, positionalArgs: []);
        debugPrint('[ActionHandler] Action "$actionName" executed successfully');
        return;
      } catch (e, stackTrace) {
        debugPrint('[ActionHandler] Hetu function "$actionName" not found or failed: $e');
        debugPrint('[ActionHandler] Stack trace: $stackTrace');
        // If function doesn't exist, try as a string-based action
        debugPrint('[ActionHandler] Trying string-based action handler...');
        _handleStringAction(actionName, params);
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to execute action "$actionName": $e';
      debugPrint('[ActionHandler] ERROR: $errorMsg');
      debugPrint('[ActionHandler] Parameters: $params');
      debugPrint('[ActionHandler] Stack trace: $stackTrace');
      _showError('Failed to execute action: $actionName');
      rethrow;
    }
  }

  /// Prepare action context with form values and other data
  Map<String, dynamic> _prepareActionContext(Map<String, dynamic>? params) {
    final context = <String, dynamic>{
      'formValues': formState?.values ?? {},
      'isValid': formState?.isValid ?? false,
    };

    if (params != null) {
      context.addAll(params);
    }

    return context;
  }

  /// Inject action context into Hetu interpreter
  void _injectActionContext(Map<String, dynamic> context) {
    // Create a Hetu struct from the context
    final contextScript = StringBuffer();
    contextScript.writeln('final actionContext = {');
    
    context.forEach((key, value) {
      if (value is String) {
        contextScript.writeln('  $key: "$value",');
      } else if (value is num) {
        contextScript.writeln('  $key: $value,');
      } else if (value is bool) {
        contextScript.writeln('  $key: ${value.toString()},');
      } else if (value is Map) {
        contextScript.writeln('  $key: ${_mapToHetuStruct(value)},');
      } else {
        contextScript.writeln('  $key: null,');
      }
    });
    
    contextScript.writeln('}');

    try {
      interpreter.eval(contextScript.toString());
    } catch (e) {
      debugPrint('Warning: Could not inject action context: $e');
    }
  }

  /// Convert Dart Map to Hetu struct string
  String _mapToHetuStruct(Map<dynamic, dynamic> map) {
    final buffer = StringBuffer();
    buffer.write('{');
    final entries = map.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final key = entry.key.toString();
      final value = entry.value;
      
      buffer.write('$key: ');
      if (value is String) {
        buffer.write('"$value"');
      } else if (value is num) {
        buffer.write(value.toString());
      } else if (value is bool) {
        buffer.write(value.toString());
      } else if (value is Map) {
        buffer.write(_mapToHetuStruct(value));
      } else {
        buffer.write('null');
      }
      
      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Handle string-based actions (navigation, form submission, etc.)
  void _handleStringAction(String action, Map<String, dynamic>? params) {
    // Handle common action patterns
    if (action.startsWith('navigate_')) {
      final screenId = action.substring('navigate_'.length);
      _navigateToScreen(screenId);
    } else if (action == 'submit' || action.startsWith('submit_')) {
      _submitForm(action);
    } else if (action == 'cancel') {
      _cancelAction();
    } else {
      debugPrint('Unknown action: $action');
      _showError('Unknown action: $action');
    }
  }

  /// Navigate to a screen
  void _navigateToScreen(String screenId) {
    if (context != null && context!.mounted) {
      // In a full implementation, this would use Navigator
      debugPrint('Navigate to screen: $screenId');
      onNavigation?.call();
    }
  }

  /// Submit form
  void _submitForm(String action) {
    if (formState == null) {
      _showError('No form to submit');
      return;
    }

    if (!formState!.validate()) {
      _showError('Please fix form errors before submitting');
      return;
    }

    // In a full implementation, this would save to Drift database
    debugPrint('Submitting form: ${formState!.values}');
    _showSuccess('Form submitted successfully');
  }

  /// Cancel action
  void _cancelAction() {
    if (context != null && context!.mounted) {
      Navigator.of(context!).pop();
    }
  }

  /// Show error message
  void _showError(String message) {
    if (context != null && context!.mounted) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show success message
  void _showSuccess(String message) {
    if (context != null && context!.mounted) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

