import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import '../binding/drift_binding.dart';
import '../drift/database_api.dart';
import '../widgets/text_field.dart';
import '../widgets/number_field.dart';

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
      
      // Ensure database functions are available BEFORE injecting action context
      // This is critical because action context injection or actions may reference database functions
      if (databaseAPI != null) {
        _ensureDatabaseFunctionsAvailable();
      }
      
      // Prepare action context
      final actionContext = _prepareActionContext(params);
      debugPrint('[ActionHandler] Action context prepared: ${actionContext.keys.join(", ")}');
      debugPrint('[ActionHandler] isValid: ${actionContext['isValid']}, formValues: ${actionContext['formValues']}');
      
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
      
      // Debug: Check what _dbOperations looks like before action invocation
      try {
        final opsBeforeAction = interpreter.fetch('_dbOperations');
        if (opsBeforeAction is List) {
          debugPrint('[ActionHandler] _dbOperations before action: ${opsBeforeAction.length} operations');
        }
      } catch (e) {
        debugPrint('[ActionHandler] Could not check _dbOperations before action: $e');
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
        
        // Process any Hetu logs before action (from previous operations)
        _processHetuLogsIfAvailable();
        
        interpreter.invoke(actionName, positionalArgs: []);
        debugPrint('[ActionHandler] Action "$actionName" executed successfully');
        
        // Process Hetu logs from the action execution
        _processHetuLogsIfAvailable();
        
        // Check if operations were queued before processing
        // This is critical - we need to see which _dbOperations array has the operations
        try {
          final opsBefore = interpreter.fetch('_dbOperations');
          if (opsBefore is List) {
            debugPrint('[ActionHandler] Operations queued before processing: ${opsBefore.length}');
            if (opsBefore.isNotEmpty) {
              debugPrint('[ActionHandler] First operation: ${opsBefore.first}');
            } else {
              debugPrint('[ActionHandler] WARNING: No operations queued - action may have failed validation or not called save()/findAll()');
            }
          } else {
            debugPrint('[ActionHandler] _dbOperations is not a List: ${opsBefore.runtimeType}');
          }
        } catch (e) {
          debugPrint('[ActionHandler] Could not check operations before processing: $e');
        }
        
        // Process any database operations queued by the action
        if (databaseAPI != null) {
          await _processDatabaseOperations();
          
          // After processing database operations, check if we need to navigate to saved customer screen
          // This happens when submit_customer action completes and we have a saved customer query ID
          try {
            final savedCustomerQueryId = interpreter.fetch('_savedCustomerQueryId');
            if (savedCustomerQueryId != null) {
              debugPrint('[ActionHandler] Found saved customer query ID: $savedCustomerQueryId');
              // Get the query result using getDbResult function
              try {
                debugPrint('[ActionHandler] Calling getDbResult with operation ID: $savedCustomerQueryId');
                final queryResult = interpreter.invoke('getDbResult', positionalArgs: [savedCustomerQueryId]);
                debugPrint('[ActionHandler] getDbResult returned: $queryResult (type: ${queryResult.runtimeType})');
                
                if (queryResult != null) {
                  debugPrint('[ActionHandler] Loaded saved customer from database: $queryResult');
                  debugPrint('[ActionHandler] Navigating to saved customer view screen');
                  _navigateToSavedCustomerScreen(queryResult);
                  // Clear the query ID so we don't navigate again
                  interpreter.eval('_savedCustomerQueryId = null');
                } else {
                  debugPrint('[ActionHandler] Query result is null for operation ID: $savedCustomerQueryId (type: ${savedCustomerQueryId.runtimeType})');
                  debugPrint('[ActionHandler] Checking _dbResults directly...');
                  try {
                    final dbResults = interpreter.fetch('_dbResults');
                    debugPrint('[ActionHandler] _dbResults contents: $dbResults');
                    if (dbResults is HTStruct) {
                      debugPrint('[ActionHandler] _dbResults keys: ${dbResults.keys.toList()}');
                      debugPrint('[ActionHandler] Attempting to access with string key: "${savedCustomerQueryId.toString()}"');
                      final directAccess = dbResults[savedCustomerQueryId.toString()];
                      debugPrint('[ActionHandler] Direct access result: $directAccess');
                    }
                  } catch (e) {
                    debugPrint('[ActionHandler] Could not fetch _dbResults: $e');
                  }
                }
              } catch (e, stackTrace) {
                debugPrint('[ActionHandler] Error getting query result: $e');
                debugPrint('[ActionHandler] Stack trace: $stackTrace');
              }
            }
          } catch (e) {
            // No saved customer query ID or error getting result - ignore
            debugPrint('[ActionHandler] No saved customer to navigate to: $e');
          }
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

  /// Navigate to saved customer screen with customer data from database
  void _navigateToSavedCustomerScreen(dynamic customerData) {
    if (context == null || !context!.mounted) {
      return;
    }

    debugPrint('[ActionHandler] Navigating to saved customer screen with data: $customerData');

    // Import required widgets
    final screenWidget = _buildSavedCustomerScreen(customerData);

    Navigator.of(context!).push(
      MaterialPageRoute(
        builder: (context) => screenWidget,
      ),
    );
  }

  /// Build saved customer screen widget with read-only form fields
  Widget _buildSavedCustomerScreen(dynamic customerData) {
    // Convert customer data to Map if it's not already
    Map<String, dynamic> customerMap;
    if (customerData is HTStruct) {
      // Convert HTStruct to Map
      customerMap = _convertHetuValueToDart(customerData) as Map<String, dynamic>;
    } else if (customerData is Map) {
      customerMap = Map<String, dynamic>.from(customerData);
    } else {
      // If it's a list (from findAll), get the first item
      if (customerData is List && customerData.isNotEmpty) {
        final firstItem = customerData[0];
        if (firstItem is HTStruct) {
          customerMap = _convertHetuValueToDart(firstItem) as Map<String, dynamic>;
        } else if (firstItem is Map) {
          customerMap = Map<String, dynamic>.from(firstItem);
        } else {
          customerMap = {};
        }
      } else {
        customerMap = {};
      }
    }

    debugPrint('[ActionHandler] Building saved customer screen with data: $customerMap');

    // Import required widgets
    return _SavedCustomerScreen(customerData: customerMap);
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

  /// Ensure database functions are available in the interpreter
  /// This must be called BEFORE invoking actions that may use database functions
  void _ensureDatabaseFunctionsAvailable() {
    // Check if database functions exist
    // If 'save' exists, assume ContainerAppShell registered all functions
    // (ContainerAppShell registers all database functions together)
    bool functionsExist = false;
    try {
      final saveFunc = interpreter.fetch('save');
      functionsExist = true;
      debugPrint('[ActionHandler] Database functions already available (save function type: ${saveFunc.runtimeType})');
    } catch (e) {
      functionsExist = false;
      debugPrint('[ActionHandler] save function not found: $e');
    }
    
    if (functionsExist) {
      // Functions exist - just ensure variables exist, don't recreate
      // Preserve existing _dbOperations to avoid losing queued operations
      try {
        final existingOps = interpreter.fetch('_dbOperations');
        if (existingOps is List) {
          debugPrint('[ActionHandler] _dbOperations already exists with ${existingOps.length} operations');
        } else {
          debugPrint('[ActionHandler] _dbOperations exists but is not a List (type: ${existingOps.runtimeType}), reinitializing...');
          interpreter.eval('_dbOperations = []');
        }
      } catch (_) {
        // _dbOperations doesn't exist, create it using assignment (not declaration)
        debugPrint('[ActionHandler] _dbOperations not found, initializing...');
        interpreter.eval('var _dbOperations = []');
        debugPrint('[ActionHandler] _dbOperations initialized');
      }
      
      // Ensure _dbResults exists
      try {
        interpreter.fetch('_dbResults');
      } catch (_) {
        debugPrint('[ActionHandler] _dbResults not found, initializing...');
        interpreter.eval('var _dbResults = {}');
      }
      
      // Ensure _dbOperationId exists
      try {
        interpreter.fetch('_dbOperationId');
      } catch (_) {
        debugPrint('[ActionHandler] _dbOperationId not found, initializing...');
        interpreter.eval('var _dbOperationId = 0');
      }
    } else {
      // Database functions don't exist (or not found), initialize them
      debugPrint('[ActionHandler] Database functions not found, initializing...');
      
      // CRITICAL: Check if _dbOperations already exists BEFORE creating functions
      // If ContainerAppShell registered functions but we can't find them (scope issue?),
      // the functions might still be using an existing _dbOperations array.
      // We MUST reuse that same array, not create a new one.
      bool dbOpsExists = false;
      int existingOpsCount = 0;
      try {
        final existing = interpreter.fetch('_dbOperations');
        if (existing is List) {
          dbOpsExists = true;
          existingOpsCount = existing.length;
          debugPrint('[ActionHandler] Found existing _dbOperations with $existingOpsCount operations - WILL REUSE IT');
        }
      } catch (_) {
        dbOpsExists = false;
      }
      
      // Initialize variables only if they don't exist
      // CRITICAL: If _dbOperations exists, DO NOT recreate it - reuse it!
      // This ensures that even if we redefine functions, they reference the same array
      if (!dbOpsExists) {
        interpreter.eval('var _dbOperations = []');
        debugPrint('[ActionHandler] Created new _dbOperations array');
      } else {
        debugPrint('[ActionHandler] REUSING existing _dbOperations array (${existingOpsCount} operations) - functions will reference this same array');
      }
      
      // Check and initialize _dbResults
      try {
        interpreter.fetch('_dbResults');
      } catch (_) {
        interpreter.eval('var _dbResults = {}');
      }
      
      // Check and initialize _dbOperationId
      try {
        interpreter.fetch('_dbOperationId');
      } catch (_) {
        interpreter.eval('var _dbOperationId = 0');
      }
      
      // Check each function individually before defining to avoid redefinition errors
      // Only define functions that don't already exist
      try {
        interpreter.fetch('save');
        debugPrint('[ActionHandler] save function already exists, skipping');
      } catch (_) {
        interpreter.eval('''
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
        ''');
        debugPrint('[ActionHandler] save function defined');
      }
      
      try {
        interpreter.fetch('findById');
        debugPrint('[ActionHandler] findById function already exists, skipping');
      } catch (_) {
        interpreter.eval('''
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
        ''');
        debugPrint('[ActionHandler] findById function defined');
      }
      
      try {
        interpreter.fetch('findAll');
        debugPrint('[ActionHandler] findAll function already exists, skipping');
      } catch (_) {
        interpreter.eval('''
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
        debugPrint('[ActionHandler] findAll function defined');
      }
      
      try {
        interpreter.fetch('getDbResult');
        debugPrint('[ActionHandler] getDbResult function already exists, skipping');
      } catch (_) {
        interpreter.eval('''
          fun getDbResult(opId) {
            // Convert opId to string to match how results are stored
            return _dbResults[opId.toString()]
          }
        ''');
        debugPrint('[ActionHandler] getDbResult function defined');
      }
      
      debugPrint('[ActionHandler] Database functions initialization complete');
    }
  }

  /// Process Hetu logs if available (for debugging action execution)
  void _processHetuLogsIfAvailable() {
    try {
      final logsValue = interpreter.fetch('_hetuLogs');
      if (logsValue is List && logsValue.isNotEmpty) {
        debugPrint('[ActionHandler] Processing ${logsValue.length} Hetu log entries from action');
        for (var i = 0; i < logsValue.length; i++) {
          final logEntry = logsValue[i];
          
          // Handle HTStruct (Hetu's struct type)
          if (logEntry is HTStruct) {
            final level = logEntry['level']?.toString() ?? 'DEBUG';
            final message = logEntry['message']?.toString() ?? '';
            debugPrint('[ActionHandler] [HetuScript] $level: $message');
          } else if (logEntry is Map) {
            final level = logEntry['level']?.toString() ?? 'DEBUG';
            final message = logEntry['message']?.toString() ?? '';
            debugPrint('[ActionHandler] [HetuScript] $level: $message');
          } else {
            debugPrint('[ActionHandler] [HetuScript] Log entry $i is not HTStruct or Map: ${logEntry.runtimeType}, value=$logEntry');
          }
        }
        // Clear the logs array
        try {
          interpreter.eval('_hetuLogs = []');
        } catch (e) {
          debugPrint('[ActionHandler] Could not clear _hetuLogs: $e');
        }
      } else {
        debugPrint('[ActionHandler] No Hetu logs to process (logsValue is ${logsValue.runtimeType}, isEmpty: ${logsValue is List ? (logsValue as List).isEmpty : 'N/A'})');
      }
    } catch (e) {
      debugPrint('[ActionHandler] Could not process Hetu logs: $e');
    }
  }

  /// Process database operations queued by Hetu scripts
  Future<void> _processDatabaseOperations() async {
    if (databaseAPI == null) {
      debugPrint('[ActionHandler] No databaseAPI available, skipping database operations');
      return;
    }

    try {
      debugPrint('[ActionHandler] Starting to process database operations...');
      
      // Database functions should already be available (ensured before action invocation)
      // Just fetch the operations queue
      dynamic operationsValue;
      try {
        operationsValue = interpreter.fetch('_dbOperations');
        debugPrint('[ActionHandler] Found _dbOperations, type: ${operationsValue.runtimeType}, length: ${operationsValue is List ? (operationsValue as List).length : 'N/A'}');
      } catch (e) {
        debugPrint('[ActionHandler] ERROR: _dbOperations not found even though functions should exist: $e');
        debugPrint('[ActionHandler] This should not happen - database functions were ensured before action invocation');
        return;
      }
      
      if (operationsValue is List && (operationsValue as List).isNotEmpty) {
        debugPrint('[ActionHandler] Processing ${operationsValue.length} database operations');
        
        final results = <int, dynamic>{};
        
        for (final operation in operationsValue) {
          // Handle both Map and HTStruct (operations from Hetu are HTStruct)
          if (operation is Map || operation is HTStruct) {
            final opId = operation['id'];
            final opType = operation['type']?.toString() ?? '';
            
            debugPrint('[ActionHandler] Processing operation $opId: type=$opType, operation type=${operation.runtimeType}');
            
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
              debugPrint('[ActionHandler] Operation $opId completed successfully, result type: ${result.runtimeType}');
            } catch (e, stackTrace) {
              debugPrint('[ActionHandler] Error processing database operation $opId ($opType): $e');
              debugPrint('[ActionHandler] Stack trace: $stackTrace');
              results[opId] = {'error': e.toString()};
            }
          } else {
            debugPrint('[ActionHandler] WARNING: Skipping operation - not a Map or HTStruct: ${operation.runtimeType}');
          }
        }
        
        debugPrint('[ActionHandler] Collected ${results.length} results from ${operationsValue.length} operations');
        
        // Ensure _dbResults exists before storing results
        try {
          interpreter.fetch('_dbResults');
        } catch (e) {
          // _dbResults doesn't exist, initialize it
          interpreter.eval('var _dbResults = {}');
        }
        
        // Store results in Hetu interpreter
        // Convert keys to strings to ensure consistent access via getDbResult
        final resultsScript = StringBuffer();
        resultsScript.writeln('_dbResults = {');
        for (final entry in results.entries) {
          // Convert key to string to ensure HTStruct can access it properly
          resultsScript.writeln('  "${entry.key}": ${_dartToHetuValue(entry.value)},');
        }
        resultsScript.writeln('}');
        
        interpreter.eval(resultsScript.toString());
        
        // Clear operations queue
        interpreter.eval('_dbOperations = []');
        
        debugPrint('[ActionHandler] Database operations processed successfully');
      } else {
        debugPrint('[ActionHandler] No database operations to process (operationsValue is ${operationsValue.runtimeType}, isEmpty: ${operationsValue is List ? (operationsValue as List).isEmpty : 'N/A'})');
      }
    } catch (e, stackTrace) {
      debugPrint('[ActionHandler] ERROR: Could not process database operations: $e');
      debugPrint('[ActionHandler] Stack trace: $stackTrace');
    }
  }

  /// Convert Hetu value to Dart value
  dynamic _convertHetuValueToDart(dynamic value) {
    if (value is String || value is int || value is double || value is bool || value == null) {
      return value;
    } else if (value is List) {
      return value.map((e) => _convertHetuValueToDart(e)).toList();
    } else if (value is HTStruct) {
      // Convert HTStruct to Map<String, dynamic>
      final result = <String, dynamic>{};
      for (final key in value.keys) {
        result[key.toString()] = _convertHetuValueToDart(value[key]);
      }
      return result;
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

/// Saved Customer Screen - displays saved customer data in read-only form
class _SavedCustomerScreen extends StatelessWidget {
  final Map<String, dynamic> customerData;

  const _SavedCustomerScreen({required this.customerData});

  @override
  Widget build(BuildContext context) {
    // Create a schema for the form
    final schema = EntitySchema(
      name: 'Customer',
      fields: {},
    );
    
    // Create form state with the customer data pre-populated
    final formState = FormStateManager(schema: schema);
    
    // Populate form state with customer data
    customerData.forEach((key, value) {
      formState.setValue(key, value);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Customer Details'),
      ),
      body: FormStateProvider(
        formState: formState,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Customer Successfully Saved',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The following customer data was retrieved from the database:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            if (customerData.containsKey('id'))
              VlinderTextField(
                field: 'id',
                label: 'Customer ID',
                readOnly: true,
              ),
            if (customerData.containsKey('name'))
              VlinderTextField(
                field: 'name',
                label: 'Full Name',
                readOnly: true,
              ),
            if (customerData.containsKey('email'))
              VlinderTextField(
                field: 'email',
                label: 'Email Address',
                readOnly: true,
              ),
            if (customerData.containsKey('age'))
              VlinderNumberField(
                field: 'age',
                label: 'Age',
                type: 'integer',
                readOnly: true,
              ),
            if (customerData.containsKey('phone'))
              VlinderTextField(
                field: 'phone',
                label: 'Phone Number',
                readOnly: true,
              ),
            if (customerData.containsKey('createdAt'))
              VlinderTextField(
                field: 'createdAt',
                label: 'Created At',
                readOnly: true,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Back to Registration'),
            ),
          ],
        ),
      ),
    );
  }
}

