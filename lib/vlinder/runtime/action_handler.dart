import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../binding/drift_binding.dart';
import '../drift/database_api.dart';

/// Handler for executing Hetu script actions
/// Supports navigation, form submission, and workflow transitions
class ActionHandler {
  final Hetu interpreter;
  final BuildContext? context;
  final FormStateManager? formState;
  final VoidCallback? onNavigation;
  final DatabaseAPI? databaseAPI;

  ActionHandler({
    required this.interpreter,
    this.context,
    this.formState,
    this.onNavigation,
    this.databaseAPI,
  });

  /// Check if action matches a known string-based pattern
  bool _isStringBasedAction(String actionName) {
    return actionName.startsWith('navigate_') ||
           actionName == 'submit' ||
           actionName.startsWith('submit_') ||
           actionName == 'cancel';
  }

  /// Execute an action by name
  /// Actions are Hetu script functions that can access form state and perform operations
  /// Falls back to string-based action handling for known patterns if Hetu function doesn't exist
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

      // Try to call the action as a Hetu function first
      // Check if function exists before attempting to invoke
      try {
        final func = interpreter.fetch(actionName);
        debugPrint('[ActionHandler] Function $actionName found in interpreter (type: ${func.runtimeType})');
      } catch (e) {
        debugPrint('[ActionHandler] Function $actionName NOT found in interpreter: $e');
        debugPrint('[ActionHandler] Trying string-based handler...');
        // If function doesn't exist, try as a string-based action
        if (_isStringBasedAction(actionName)) {
          debugPrint('[ActionHandler] Handling as string-based action: $actionName');
          await _handleStringAction(actionName, params);
        } else {
          // Unknown action - show error
          final errorMsg = 'Action "$actionName" not found as Hetu function and not a known string-based action';
          debugPrint('[ActionHandler] ERROR: $errorMsg');
          _showError(errorMsg);
          throw Exception(errorMsg);
        }
        return;
      }
      
      // Function exists, try to invoke it
      try {
        debugPrint('[ActionHandler] Invoking Hetu function: $actionName');
        interpreter.invoke(actionName, positionalArgs: []);
        debugPrint('[ActionHandler] Action "$actionName" executed successfully');
        
        // Process any database operations queued by the action
        if (databaseAPI != null) {
          await _processDatabaseOperations();
        }
        
        return;
      } catch (e, stackTrace) {
        debugPrint('[ActionHandler] Hetu function "$actionName" invocation failed: $e');
        debugPrint('[ActionHandler] Stack trace: $stackTrace');
        // If function invocation fails, try as a string-based action as fallback
        if (_isStringBasedAction(actionName)) {
          debugPrint('[ActionHandler] Falling back to string-based handler for: $actionName');
          await _handleStringAction(actionName, params);
        } else {
          // Unknown action - show error
          final errorMsg = 'Action "$actionName" failed to execute: $e';
          debugPrint('[ActionHandler] ERROR: $errorMsg');
          _showError(errorMsg);
          rethrow;
        }
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
  Future<void> _handleStringAction(String action, Map<String, dynamic>? params) async {
    // Handle common action patterns
    if (action.startsWith('navigate_')) {
      final screenId = action.substring('navigate_'.length);
      _navigateToScreen(screenId);
    } else if (action == 'submit' || action.startsWith('submit_')) {
      await _submitForm(action);
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
  Future<void> _submitForm(String action) async {
    if (formState == null) {
      _showError('No form to submit');
      return;
    }

    // formState is guaranteed to be non-null after the check above
    final state = formState!;

    if (!state.validate()) {
      _showError('Please fix form errors before submitting');
      return;
    }

    // Try to save form data to database if entity is specified and database API is available
    if (databaseAPI != null && state.schema.name.isNotEmpty) {
      try {
        debugPrint('[ActionHandler] Saving form data to database for entity: ${state.schema.name}');
        await databaseAPI!.save(state.schema.name, state.values);
        _showSuccess('Form submitted and saved successfully');
      } catch (e) {
        debugPrint('[ActionHandler] Error saving form data: $e');
        _showError('Failed to save form data: $e');
      }
    } else {
      debugPrint('[ActionHandler] Submitting form: ${state.values}');
      _showSuccess('Form submitted successfully');
    }
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

  /// Process database operations queued by Hetu scripts
  Future<void> _processDatabaseOperations() async {
    if (databaseAPI == null) {
      return;
    }

    try {
      // Check if database functions are registered, initialize if not
      try {
        interpreter.fetch('save');
      } catch (e) {
        // Database functions not registered, initialize them
        debugPrint('[ActionHandler] Database functions not found, initializing...');
        interpreter.eval('''
          var _dbOperations = []
          var _dbResults = {}
          var _dbOperationId = 0
          
          fun save(entityName, data) {
            final opId = _dbOperationId++
            final operation = {
              type: 'save',
              id: opId,
              entityName: entityName,
              data: data,
            }
            _dbOperations.add(operation)
            return opId
          }
          
          fun findById(entityName, id) {
            final opId = _dbOperationId++
            final operation = {
              type: 'findById',
              id: opId,
              entityName: entityName,
              id: id,
            }
            _dbOperations.add(operation)
            return opId
          }
          
          fun findAll(entityName, where, orderBy, limit) {
            final opId = _dbOperationId++
            final operation = {
              type: 'findAll',
              id: opId,
              entityName: entityName,
              where: where ?? {},
              orderBy: orderBy,
              limit: limit,
            }
            _dbOperations.add(operation)
            return opId
          }
        ''');
        debugPrint('[ActionHandler] Database functions initialized');
      }
      
      // Check if _dbOperations exists, initialize if not
      dynamic operationsValue;
      try {
        operationsValue = interpreter.fetch('_dbOperations');
      } catch (e) {
        // _dbOperations doesn't exist, initialize it
        debugPrint('[ActionHandler] _dbOperations not found, initializing...');
        interpreter.eval('var _dbOperations = []');
        operationsValue = interpreter.fetch('_dbOperations');
      }
      
      if (operationsValue is List && (operationsValue as List).isNotEmpty) {
        debugPrint('[ActionHandler] Processing ${operationsValue.length} database operations');
        
        final results = <int, dynamic>{};
        
        for (final operation in operationsValue) {
          if (operation is Map) {
            final opId = operation['id'];
            final opType = operation['type']?.toString() ?? '';
            
            try {
              dynamic result;
              
              switch (opType) {
                case 'executeSQL':
                  final sql = operation['sql']?.toString() ?? '';
                  final params = operation['params'] as List?;
                  await databaseAPI!.executeSQL(sql, params);
                  result = {'success': true};
                  break;
                  
                case 'query':
                  final sql = operation['sql']?.toString() ?? '';
                  final params = operation['params'] as List?;
                  result = await databaseAPI!.query(sql, params);
                  break;
                  
                case 'save':
                  final entityName = operation['entityName']?.toString() ?? '';
                  final data = operation['data'];
                  if (data != null) {
                    final dartData = _convertHetuValueToDart(data);
                    result = await databaseAPI!.save(entityName, dartData);
                  }
                  break;
                  
                case 'findById':
                  final entityName = operation['entityName']?.toString() ?? '';
                  final id = operation['id'];
                  result = await databaseAPI!.findById(entityName, id);
                  break;
                  
                case 'findAll':
                  final entityName = operation['entityName']?.toString() ?? '';
                  final where = operation['where'];
                  final orderBy = operation['orderBy'];
                  final limit = operation['limit'];
                  final dartWhere = where != null ? _convertHetuValueToDart(where) as Map<String, dynamic>? : null;
                  result = await databaseAPI!.findAll(
                    entityName,
                    where: dartWhere,
                    orderBy: orderBy,
                    limit: limit is int ? limit : null,
                  );
                  break;
                  
                case 'update':
                  final entityName = operation['entityName']?.toString() ?? '';
                  final id = operation['id'];
                  final data = operation['data'];
                  if (data != null) {
                    final dartData = _convertHetuValueToDart(data);
                    result = await databaseAPI!.update(entityName, id, dartData);
                  }
                  break;
                  
                case 'delete':
                  final entityName = operation['entityName']?.toString() ?? '';
                  final id = operation['id'];
                  result = await databaseAPI!.delete(entityName, id);
                  break;
                  
                default:
                  result = {'error': 'Unknown operation type: $opType'};
              }
              
              results[opId] = result;
            } catch (e, stackTrace) {
              debugPrint('[ActionHandler] Error processing database operation $opId ($opType): $e');
              debugPrint('[ActionHandler] Stack trace: $stackTrace');
              results[opId] = {'error': e.toString()};
            }
          }
        }
        
        // Ensure _dbResults exists before storing results
        try {
          interpreter.fetch('_dbResults');
        } catch (e) {
          // _dbResults doesn't exist, initialize it
          interpreter.eval('var _dbResults = {}');
        }
        
        // Store results in Hetu interpreter
        final resultsScript = StringBuffer();
        resultsScript.writeln('_dbResults = {');
        for (final entry in results.entries) {
          resultsScript.writeln('  ${entry.key}: ${_dartToHetuValue(entry.value)},');
        }
        resultsScript.writeln('}');
        
        interpreter.eval(resultsScript.toString());
        
        // Clear operations queue
        interpreter.eval('_dbOperations = []');
        
        debugPrint('[ActionHandler] Database operations processed successfully');
      }
    } catch (e) {
      debugPrint('[ActionHandler] Warning: Could not process database operations: $e');
    }
  }

  /// Convert Hetu value to Dart value
  dynamic _convertHetuValueToDart(dynamic value) {
    if (value is String || value is int || value is double || value is bool || value == null) {
      return value;
    } else if (value is List) {
      return value.map((e) => _convertHetuValueToDart(e)).toList();
    } else if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        result[key] = _convertHetuValueToDart(entry.value);
      }
      return result;
    }
    return value.toString();
  }

  /// Convert Dart value to Hetu script representation
  String _dartToHetuValue(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is String) {
      return '"${value.replaceAll('"', '\\"')}"';
    } else if (value is num) {
      return value.toString();
    } else if (value is bool) {
      return value.toString();
    } else if (value is List) {
      final items = value.map((e) => _dartToHetuValue(e)).join(', ');
      return '[$items]';
    } else if (value is Map) {
      final entries = value.entries.map((e) {
        final key = e.key.toString();
        final val = _dartToHetuValue(e.value);
        return '$key: $val';
      }).join(', ');
      return '{$entries}';
    }
    return '"${value.toString().replaceAll('"', '\\"')}"';
  }
}

