import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../vlinder/vlinder.dart';
import '../vlinder/core/interpreter_provider.dart';
import '../vlinder/core/database_provider.dart';
import '../vlinder/core/ui_yaml_provider.dart';
import '../vlinder/drift/database_api.dart';
import '../vlinder/drift/database.dart';
import 'asset_fetcher.dart';
import 'debug_logger.dart';
import 'config.dart';

/// Loading state for initialization steps
enum LoadingStep {
  fetchingAssets,
  loadingSchemas,
  initializingDatabase,
  loadingWorkflows,
  loadingRules,
  loadingActions,
  loadingUI,
  complete,
}

/// Container app shell - minimal Flutter app that fetches and renders .ht files
class ContainerAppShell extends StatefulWidget {
  const ContainerAppShell({super.key});

  @override
  State<ContainerAppShell> createState() => _ContainerAppShellState();
}

class _ContainerAppShellState extends State<ContainerAppShell> {
  late final Hetu _interpreter;
  late final VlinderRuntime _runtime;
  late final VlinderDatabase _database;
  late final DatabaseAPI _databaseAPI;
  AssetFetcher? _fetcher;
  
  Widget? _loadedUI;
  String? _uiYamlContent;
  String? _errorMessage;
  bool _isLoading = true;
  bool _waitingForServerUrl = false;
  LoadingStep _currentStep = LoadingStep.fetchingAssets;

  @override
  void initState() {
    super.initState();
    // Create interpreter first
    _interpreter = Hetu();
    _interpreter.init();
    
    // Create database and API
    _database = VlinderDatabase();
    _databaseAPI = DatabaseAPI(database: _database);
    
    // Check app version and clear stored data if version changed
    // This ensures users scan a fresh QR code when a new app version is deployed
    ContainerConfig.checkAndClearOnVersionChange().then((_) {
      // Clear stored server URL on every app startup to force QR code scan
      // This ensures users always scan a QR code when the app opens
      ContainerConfig.clearServerUrl().then((_) {
        debugPrint('[ContainerAppShell] Cleared stored server URL - QR code scan required');
        
        // Register logging functions in the interpreter
        // This allows .ht files to use log(), logInfo(), logWarning(), logError()
        _registerLoggingFunctions();
        
        // Register database functions in the interpreter
        // This allows .ht files to use executeSQL(), query(), save(), etc.
        _registerDatabaseFunctions();
        
        // Create runtime with shared interpreter
        // This ensures UI scripts can access schemas, workflows, and rules
        _runtime = VlinderRuntime(interpreter: _interpreter);
        
        // Enable remote debug logging if configured
        // Pass log server URL explicitly from config
        final logServerUrl = ContainerConfig.debugLogServerUrl;
        if (logServerUrl != null && logServerUrl.isNotEmpty) {
          debugPrint('[ContainerAppShell] Enabling debug logging to: $logServerUrl');
          DebugLogger.instance.enable(logServerUrl: logServerUrl);
        } else {
          debugPrint('[ContainerAppShell] Debug logging disabled (no VLINDER_LOG_SERVER_URL configured)');
        }
        
        _checkServerUrl();
      });
    });
  }

  /// Check if server URL is configured, show landing screen if not
  Future<void> _checkServerUrl() async {
    final serverUrl = await ContainerConfig.serverUrl;
    if (serverUrl == null || serverUrl.isEmpty) {
      debugPrint('[ContainerAppShell] No server URL configured, showing landing screen');
      setState(() {
        _waitingForServerUrl = true;
        _isLoading = false;
      });
    } else {
      debugPrint('[ContainerAppShell] Server URL found: $serverUrl');
      _fetcher = AssetFetcher(serverUrl: serverUrl);
      _initializeApp(forceRefresh: true);
    }
  }

  /// Handle QR code scan result
  Future<void> _handleQRCodeScan(String? code) async {
    if (code == null || code.isEmpty) {
      return;
    }

    // Validate URL format
    final uri = Uri.tryParse(code);
    if (uri == null || (!uri.scheme.startsWith('http'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid URL format. Please scan a valid HTTP/HTTPS URL.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Trim and save URL to persistent storage
    final trimmedUrl = code.trim();
    await ContainerConfig.saveServerUrl(trimmedUrl);
    debugPrint('[ContainerAppShell] Server URL saved: $trimmedUrl');

    // Update fetcher with trimmed URL
    _fetcher = AssetFetcher(serverUrl: trimmedUrl);

    // Hide QR scanner and start initialization
    if (mounted) {
      setState(() {
        _waitingForServerUrl = false;
        _isLoading = true;
      });
      _initializeApp();
    }
  }

  /// Register logging functions in Hetu interpreter
  /// These functions allow .ht files to log messages that are sent to the debug logger
  void _registerLoggingFunctions() {
    debugPrint('[ContainerAppShell] Registering logging functions in Hetu interpreter...');
    
    // Check if functions are already defined to avoid redefinition errors
    try {
      _interpreter.fetch('log');
      debugPrint('[ContainerAppShell] Logging functions already defined, skipping registration');
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
      _interpreter.eval(loggingScript);
      debugPrint('[ContainerAppShell] Logging functions registered successfully');
    } catch (e) {
      debugPrint('[ContainerAppShell] Warning: Could not register logging functions: $e');
    }
  }

  /// Process logs from Hetu scripts after evaluation
  /// Extracts logs from _hetuLogs array and sends them to debug logger
  void _processHetuLogs() {
    try {
      final logsValue = _interpreter.fetch('_hetuLogs');
      if (logsValue is List && logsValue.isNotEmpty) {
        debugPrint('[ContainerAppShell] Processing ${logsValue.length} Hetu log entries');
        for (final logEntry in logsValue) {
          // Handle HTStruct (Hetu's struct type) and Map
          String? level;
          String? message;
          
          if (logEntry is HTStruct) {
            level = logEntry['level']?.toString() ?? 'DEBUG';
            message = logEntry['message']?.toString() ?? '';
          } else if (logEntry is Map) {
            level = logEntry['level']?.toString() ?? 'DEBUG';
            message = logEntry['message']?.toString() ?? '';
          }
          
          if (level != null && message != null) {
            _logFromHetu(level, message);
          }
        }
        // Clear the logs array
        _interpreter.eval('_hetuLogs = []');
      }
    } catch (e) {
      // Ignore errors - logging is not critical
      debugPrint('[ContainerAppShell] Warning: Could not process Hetu logs: $e');
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

  /// Register database functions in Hetu interpreter
  /// These functions allow .ht files to interact with the database
  /// Note: Database operations are async, so these functions queue operations
  /// that are processed by ActionHandler when actions are executed
  void _registerDatabaseFunctions() {
    debugPrint('[ContainerAppShell] Registering database functions in Hetu interpreter...');
    
    // Check if functions are already defined to avoid redefinition errors
    try {
      _interpreter.fetch('executeSQL');
      debugPrint('[ContainerAppShell] Database functions already defined, skipping registration');
      return;
    } catch (_) {
      // Functions don't exist, proceed with definition
    }

    // Create database functions that store operations in a queue
    // These operations will be processed by ActionHandler when actions execute
    // The results will be stored in _dbResults and can be accessed via getDbResult()
    final databaseScript = '''
      // Database operation queue - stores pending operations
      var _dbOperations = []
      var _dbResults = {}
      var _dbOperationId = 0
      
      // Execute raw SQL statement
      fun executeSQL(sql, params) {
        final opId = _dbOperationId++
        final operation = {
          type: 'executeSQL',
          id: opId,
          sql: sql,
          params: params ?? [],
        }
        _dbOperations.add(operation)
        return opId
      }
      
      // Execute SELECT query
      fun query(sql, params) {
        final opId = _dbOperationId++
        final operation = {
          type: 'query',
          id: opId,
          sql: sql,
          params: params ?? [],
        }
        _dbOperations.add(operation)
        return opId
      }
      
      // Save entity (INSERT or UPDATE)
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
      
      // Find entity by ID
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
      
      // Find all entities
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
      
      // Update entity
      fun update(entityName, id, data) {
        final opId = _dbOperationId++
        final operation = {
          type: 'update',
          id: opId,
          entityName: entityName,
          id: id,
          data: data,
        }
        _dbOperations.add(operation)
        return opId
      }
      
      // Delete entity
      fun delete(entityName, id) {
        final opId = _dbOperationId++
        final operation = {
          type: 'delete',
          id: opId,
          entityName: entityName,
          id: id,
        }
        _dbOperations.add(operation)
        return opId
      }
      
      // Get result from operation (called after processing)
      fun getDbResult(opId) {
        return _dbResults[opId]
      }
      
      // Clear results (called after processing)
      fun clearDbResults() {
        _dbResults = {}
      }
    ''';

    try {
      _interpreter.eval(databaseScript);
      debugPrint('[ContainerAppShell] Database functions registered successfully');
    } catch (e) {
      debugPrint('[ContainerAppShell] Warning: Could not register database functions: $e');
    }
    
    // Register navigation function
    _registerNavigationFunction();
  }
  
  /// Register navigation function in Hetu interpreter
  /// This function allows .ht files to request navigation to a screen
  void _registerNavigationFunction() {
    debugPrint('[ContainerAppShell] Registering navigation function in Hetu interpreter...');
    
    // Check if function is already defined to avoid redefinition errors
    try {
      _interpreter.fetch('navigate');
      debugPrint('[ContainerAppShell] Navigation function already defined, skipping registration');
      return;
    } catch (_) {
      // Function doesn't exist, proceed with definition
    }

    // Create navigation function that stores navigation request
    // Navigation requests are processed by ActionHandler after action execution
    final navigationScript = '''
      // Navigation request queue - stores pending navigation requests
      var _navigationRequest = null
      
      // Navigate to a screen by ID
      fun navigate(screenId) {
        _navigationRequest = screenId
        logInfo("Navigation requested to screen: " + screenId)
      }
    ''';

    try {
      _interpreter.eval(navigationScript);
      debugPrint('[ContainerAppShell] Navigation function registered successfully');
    } catch (e) {
      debugPrint('[ContainerAppShell] Warning: Could not register navigation function: $e');
    }
  }
  
  @override
  void reassemble() {
    super.reassemble();
    // Hot reload detected - fetch fresh .ht files
    debugPrint('[ContainerAppShell] Hot reload detected - fetching fresh .ht files');
    if (_fetcher != null && !_waitingForServerUrl) {
      // Only reload if we have a fetcher and app is initialized
      _initializeApp(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    // Flush remaining logs before disposing
    DebugLogger.instance.flush();
    super.dispose();
  }

  Future<void> _initializeApp({bool forceRefresh = false}) async {
    try {
      debugPrint('[ContainerAppShell] Starting app initialization');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentStep = LoadingStep.fetchingAssets;
      });

      // Fetch assets (cache disabled - always fetch fresh)
      debugPrint('[ContainerAppShell] Fetching assets${forceRefresh ? " (force refresh)" : ""}');
      setState(() {
        _currentStep = LoadingStep.fetchingAssets;
      });
      Map<String, String> assets;
      try {
        if (_fetcher == null) {
          throw Exception('AssetFetcher not initialized - server URL required');
        }
        assets = await _fetcher!.fetchAllAssets(forceRefresh: forceRefresh);
        debugPrint('[ContainerAppShell] Fetched ${assets.length} assets: ${assets.keys.join(", ")}');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to fetch assets: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        throw Exception('Step: Fetching assets - $errorMsg');
      }

      // Load schemas
      debugPrint('[ContainerAppShell] Loading schemas');
      setState(() {
        _currentStep = LoadingStep.loadingSchemas;
      });
      Map<String, EntitySchema> schemas;
      try {
        final schemaContent = assets['schema.yaml'] ?? '';
        final schemaLoader = SchemaLoader();
        schemas = schemaLoader.loadSchemas(schemaContent);
        
        // Update database API with loaded schemas
        _databaseAPI.updateSchemas(schemas);
        
        debugPrint('[ContainerAppShell] Loaded ${schemas.length} schemas: ${schemas.keys.join(", ")}');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to load schemas from schema.yaml (OpenAPI format): $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        final schemaContent = assets['schema.yaml'] ?? '';
        if (schemaContent.isNotEmpty) {
          final preview = schemaContent.length > 200 
              ? schemaContent.substring(0, 200) 
              : schemaContent;
          debugPrint('[ContainerAppShell] Schema content preview: $preview...');
        }
        throw Exception('Step: Loading schemas - File: schema.yaml (OpenAPI format) - $errorMsg');
      }

      // Initialize database with schemas
      debugPrint('[ContainerAppShell] Initializing database');
      setState(() {
        _currentStep = LoadingStep.initializingDatabase;
      });
      try {
        // Reuse existing database instance (created in initState)
        for (final schema in schemas.values) {
          debugPrint('[ContainerAppShell] Creating table for schema: ${schema.name}');
          try {
            await _database.createTableFromSchema(schema);
          } catch (e, stackTrace) {
            final errorMsg = 'Failed to create table for schema "${schema.name}": $e';
            debugPrint('[ContainerAppShell] ERROR: $errorMsg');
            debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
            throw Exception('Step: Initializing database - Schema: ${schema.name} - $errorMsg');
          }
        }
        debugPrint('[ContainerAppShell] Database initialization complete');
      } catch (e) {
        // Re-throw if it's our own exception, otherwise wrap it
        if (e.toString().contains('Step: Initializing database')) {
          rethrow;
        }
        final errorMsg = 'Failed to initialize database: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        throw Exception('Step: Initializing database - $errorMsg');
      }

      // Load workflows
      debugPrint('[ContainerAppShell] Loading workflows');
      setState(() {
        _currentStep = LoadingStep.loadingWorkflows;
      });
      try {
        final workflowContent = assets['workflows.yaml'] ?? '';
        final workflowParser = WorkflowParser();
        workflowParser.loadWorkflows(workflowContent);
        
        debugPrint('[ContainerAppShell] Workflows loaded');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to load workflows from workflows.yaml: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        final workflowContent = assets['workflows.yaml'] ?? '';
        if (workflowContent.isNotEmpty) {
          final preview = workflowContent.length > 200 
              ? workflowContent.substring(0, 200) 
              : workflowContent;
          debugPrint('[ContainerAppShell] Workflow content preview: $preview...');
        }
        throw Exception('Step: Loading workflows - File: workflows.yaml - $errorMsg');
      }

      // Load rules
      debugPrint('[ContainerAppShell] Loading rules');
      setState(() {
        _currentStep = LoadingStep.loadingRules;
      });
      try {
        final rulesContent = assets['rules.ht'] ?? '';
        final rulesParser = RulesParser(interpreter: _interpreter);
        rulesParser.loadRules(rulesContent);
        
        // Process any logs from Hetu script execution
        _processHetuLogs();
        
        debugPrint('[ContainerAppShell] Rules loaded');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to load rules from rules.ht: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        final rulesContent = assets['rules.ht'] ?? '';
        if (rulesContent.isNotEmpty) {
          final preview = rulesContent.length > 200 
              ? rulesContent.substring(0, 200) 
              : rulesContent;
          debugPrint('[ContainerAppShell] Rules content preview: $preview...');
        }
        throw Exception('Step: Loading rules - File: rules.ht - $errorMsg');
      }

      // Load actions (required file)
      debugPrint('[ContainerAppShell] Loading actions');
      setState(() {
        _currentStep = LoadingStep.loadingActions;
      });
      try {
        final actionsContent = assets['actions.ht'] ?? '';
        if (actionsContent.isEmpty) {
          final errorMsg = 'actions.ht file is required but not found in assets';
          debugPrint('[ContainerAppShell] ERROR: $errorMsg');
          throw Exception('Step: Loading actions - File: actions.ht - $errorMsg');
        }
        
        debugPrint('[ContainerAppShell] Evaluating actions.ht content (${actionsContent.length} characters)');
        
        // Evaluate actions script to register action functions
        _interpreter.eval(actionsContent);
        
        // Process any logs from Hetu script execution
        _processHetuLogs();
        
        // Actions script loaded successfully (eval() validates syntax)
        // Action functions are now registered and available for use
        debugPrint('[ContainerAppShell] Actions loaded successfully');
      } catch (e, stackTrace) {
        // Re-throw if it's our own exception, otherwise wrap it
        if (e.toString().contains('Step: Loading actions')) {
          rethrow;
        }
        final errorMsg = 'Failed to load actions from actions.ht: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        final actionsContent = assets['actions.ht'] ?? '';
        if (actionsContent.isNotEmpty) {
          final preview = actionsContent.length > 200 
              ? actionsContent.substring(0, 200) 
              : actionsContent;
          debugPrint('[ContainerAppShell] Actions content preview: $preview...');
        }
        throw Exception('Step: Loading actions - File: actions.ht - $errorMsg');
      }

      // Load UI
      debugPrint('[ContainerAppShell] Loading UI');
      setState(() {
        _currentStep = LoadingStep.loadingUI;
      });
      try {
        final uiContent = assets['ui.yaml'] ?? '';
        if (uiContent.isEmpty) {
          debugPrint('[ContainerAppShell] ERROR: No UI content found in assets');
          throw Exception('Step: Loading UI - File: ui.yaml - No UI content found');
        }

        // Store UI YAML content for later use in navigation
        _uiYamlContent = uiContent;
        debugPrint('[ContainerAppShell] Stored UI YAML content (${uiContent.length} characters)');

        final loadedWidget = _runtime.loadUI(uiContent, context);
        
        if (loadedWidget == null) {
          debugPrint('[ContainerAppShell] ERROR: loadUI returned null widget!');
          throw Exception('Step: Loading UI - File: ui.yaml - loadUI returned null widget');
        }

        setState(() {
          _loadedUI = loadedWidget;
          _currentStep = LoadingStep.complete;
          _isLoading = false;
        });
        debugPrint('[ContainerAppShell] App initialization complete. _loadedUI type: ${_loadedUI.runtimeType}');
      } catch (e, stackTrace) {
        // Re-throw if it's our own exception, otherwise wrap it
        if (e.toString().contains('Step: Loading UI')) {
          rethrow;
        }
        final errorMsg = 'Failed to load UI from ui.yaml: $e';
        debugPrint('[ContainerAppShell] ERROR: $errorMsg');
        debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
        final uiContent = assets['ui.yaml'] ?? '';
        if (uiContent.isNotEmpty) {
          final preview = uiContent.length > 300 
              ? uiContent.substring(0, 300) 
              : uiContent;
          debugPrint('[ContainerAppShell] UI content preview: $preview...');
        }
        throw Exception('Step: Loading UI - File: ui.yaml - $errorMsg');
      }
    } catch (e, stackTrace) {
      final errorMsg = e.toString();
      debugPrint('[ContainerAppShell] ERROR: Error during initialization: $errorMsg');
      debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    await _initializeApp();
  }

  String _getStepMessage() {
    switch (_currentStep) {
      case LoadingStep.fetchingAssets:
        return 'Fetching assets...';
      case LoadingStep.loadingSchemas:
        return 'Loading schemas...';
      case LoadingStep.initializingDatabase:
        return 'Initializing database...';
      case LoadingStep.loadingWorkflows:
        return 'Loading workflows...';
      case LoadingStep.loadingRules:
        return 'Loading rules...';
      case LoadingStep.loadingActions:
        return 'Loading actions...';
      case LoadingStep.loadingUI:
        return 'Loading UI...';
      case LoadingStep.complete:
        return 'Complete';
    }
  }

  double _getProgress() {
    switch (_currentStep) {
      case LoadingStep.fetchingAssets:
        return 0.12;
      case LoadingStep.loadingSchemas:
        return 0.25;
      case LoadingStep.initializingDatabase:
        return 0.40;
      case LoadingStep.loadingWorkflows:
        return 0.55;
      case LoadingStep.loadingRules:
        return 0.70;
      case LoadingStep.loadingActions:
        return 0.85;
      case LoadingStep.loadingUI:
        return 0.95;
      case LoadingStep.complete:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show landing screen if waiting for server URL
    if (_waitingForServerUrl) {
      return _buildLandingScreen();
    }

    // If UI is loaded, wrap it with providers so widgets can access the interpreter, database, and UI YAML
    if (!_isLoading && _loadedUI != null && _errorMessage == null && _uiYamlContent != null) {
      return DatabaseAPIProvider(
        databaseAPI: _databaseAPI,
        child: HetuInterpreterProvider(
          interpreter: _interpreter,
          child: UIYAMLProvider(
            uiYamlContent: _uiYamlContent!,
            child: _loadedUI!,
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon/Logo placeholder
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.apps,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App Title
                    Text(
                      'Vlinder Container',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 48),
                    // Progress indicator
                    SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _getProgress(),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Current step message
                    Text(
                      _getStepMessage(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 32),
                    // Step indicators
                    _buildStepIndicators(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error Loading App',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Text('No UI loaded'),
      ),
    );
  }

  Widget _buildStepIndicators() {
    final steps = [
      LoadingStep.fetchingAssets,
      LoadingStep.loadingSchemas,
      LoadingStep.initializingDatabase,
      LoadingStep.loadingWorkflows,
      LoadingStep.loadingRules,
      LoadingStep.loadingActions,
      LoadingStep.loadingUI,
    ];

    return Column(
      children: steps.map((step) {
        final isCompleted = _currentStep.index > step.index;
        final isCurrent = _currentStep == step;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: isCurrent
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                _getStepLabel(step),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCompleted || isCurrent
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getStepLabel(LoadingStep step) {
    switch (step) {
      case LoadingStep.fetchingAssets:
        return 'Fetching assets';
      case LoadingStep.loadingSchemas:
        return 'Loading schemas';
      case LoadingStep.initializingDatabase:
        return 'Initializing database';
      case LoadingStep.loadingWorkflows:
        return 'Loading workflows';
      case LoadingStep.loadingRules:
        return 'Loading rules';
      case LoadingStep.loadingActions:
        return 'Loading actions';
      case LoadingStep.loadingUI:
        return 'Loading UI';
      case LoadingStep.complete:
        return 'Complete';
    }
  }

  /// Build landing screen with Link button and manual input
  Widget _buildLandingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon/Logo placeholder
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.apps,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App Title
                    Text(
                      'Vlinder Container',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Instructions
                    Text(
                      'Link with your server',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 48),
                    // Manual URL input
                    _ManualUrlInput(
                      onConnect: (url) => _handleQRCodeScan(url),
                    ),
                    const SizedBox(height: 24),
                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Link with QR button
                    ElevatedButton.icon(
                      onPressed: () => _showQRScanner(),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Link with QR Code'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        textStyle: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show QR code scanner screen
  void _showQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          onScan: _handleQRCodeScan,
        ),
      ),
    );
  }
}

/// Manual URL Input Widget
class _ManualUrlInput extends StatefulWidget {
  final Function(String?) onConnect;

  const _ManualUrlInput({required this.onConnect});

  @override
  State<_ManualUrlInput> createState() => _ManualUrlInputState();
}

class _ManualUrlInputState extends State<_ManualUrlInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isConnecting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleConnect() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a server URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    widget.onConnect(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://example.com',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleConnect(),
          enabled: !_isConnecting,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isConnecting ? null : _handleConnect,
          icon: _isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.connect_without_contact),
          label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            textStyle: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

/// QR Code Scanner Screen
class _QRScannerScreen extends StatefulWidget {
  final Function(String?) onScan;

  const _QRScannerScreen({required this.onScan});

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _urlController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _handleManualConnect() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a server URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Stop scanning
    _controller.stop();
    // Process the URL
    widget.onScan(url);
    // Navigate back
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(_showManualInput ? Icons.qr_code_scanner : Icons.edit),
            tooltip: _showManualInput ? 'Show Scanner' : 'Enter URL Manually',
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
                if (_showManualInput) {
                  _controller.stop();
                } else {
                  _controller.start();
                }
              });
            },
          ),
        ],
      ),
      body: _showManualInput
          ? _buildManualInputView()
          : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final barcode = barcodes.first;
              if (barcode.rawValue != null) {
                // Stop scanning
                _controller.stop();
                // Process the scanned code
                widget.onScan(barcode.rawValue);
                // Navigate back
                Navigator.of(context).pop();
              }
            }
          },
        ),
        // Overlay with scanning area indicator
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Position the QR code within the frame',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.link,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://example.com',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleManualConnect(),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleManualConnect,
                icon: const Icon(Icons.connect_without_contact),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

