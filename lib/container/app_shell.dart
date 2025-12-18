import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../vlinder/vlinder.dart';
import 'asset_fetcher.dart';

/// Loading state for initialization steps
enum LoadingStep {
  fetchingAssets,
  loadingSchemas,
  initializingDatabase,
  loadingWorkflows,
  loadingRules,
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
  final VlinderRuntime _runtime = VlinderRuntime();
  late final Hetu _interpreter;
  final AssetFetcher _fetcher = AssetFetcher();
  
  Widget? _loadedUI;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isOffline = false;
  LoadingStep _currentStep = LoadingStep.fetchingAssets;

  @override
  void initState() {
    super.initState();
    _interpreter = Hetu();
    _interpreter.init();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('[ContainerAppShell] Starting app initialization');
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentStep = LoadingStep.fetchingAssets;
      });

      // Check if we have cached assets (offline mode)
      debugPrint('[ContainerAppShell] Checking for cached assets');
      final hasCache = await _fetcher.hasCachedAssets();
      if (hasCache) {
        _isOffline = true;
        debugPrint('[ContainerAppShell] Using cached assets (offline mode)');
      }

      // Fetch assets
      debugPrint('[ContainerAppShell] Fetching assets');
      setState(() {
        _currentStep = LoadingStep.fetchingAssets;
      });
      final assets = await _fetcher.fetchAllAssets();
      debugPrint('[ContainerAppShell] Fetched ${assets.length} assets: ${assets.keys.join(", ")}');

      // Load schemas
      debugPrint('[ContainerAppShell] Loading schemas');
      setState(() {
        _currentStep = LoadingStep.loadingSchemas;
      });
      final schemaLoader = SchemaLoader(interpreter: _interpreter);
      final schemas = schemaLoader.loadSchemas(assets['schema.ht'] ?? '');
      debugPrint('[ContainerAppShell] Loaded ${schemas.length} schemas: ${schemas.keys.join(", ")}');

      // Initialize database with schemas
      debugPrint('[ContainerAppShell] Initializing database');
      setState(() {
        _currentStep = LoadingStep.initializingDatabase;
      });
      final database = VlinderDatabase();
      for (final schema in schemas.values) {
        debugPrint('[ContainerAppShell] Creating table for schema: ${schema.name}');
        await database.createTableFromSchema(schema);
      }
      debugPrint('[ContainerAppShell] Database initialization complete');

      // Load workflows
      debugPrint('[ContainerAppShell] Loading workflows');
      setState(() {
        _currentStep = LoadingStep.loadingWorkflows;
      });
      final workflowParser = WorkflowParser(interpreter: _interpreter);
      workflowParser.loadWorkflows(assets['workflows.ht'] ?? '');
      debugPrint('[ContainerAppShell] Workflows loaded');

      // Load rules
      debugPrint('[ContainerAppShell] Loading rules');
      setState(() {
        _currentStep = LoadingStep.loadingRules;
      });
      final rulesParser = RulesParser(interpreter: _interpreter);
      rulesParser.loadRules(assets['rules.ht'] ?? '');
      debugPrint('[ContainerAppShell] Rules loaded');

      // Note: WorkflowEngine and RulesEngine are created but not yet integrated
      // They will be used when action handlers are implemented
      // final workflows = workflowParser.loadWorkflows(assets['workflows.ht'] ?? '');
      // final rules = rulesParser.loadRules(assets['rules.ht'] ?? '');
      // final workflowEngine = WorkflowEngine(interpreter: _interpreter, workflows: workflows);
      // final rulesEngine = RulesEngine(interpreter: _interpreter, rules: rules);

      // Load UI
      debugPrint('[ContainerAppShell] Loading UI');
      setState(() {
        _currentStep = LoadingStep.loadingUI;
      });
      final uiContent = assets['ui.ht'] ?? '';
      if (uiContent.isEmpty) {
        debugPrint('[ContainerAppShell] ERROR: No UI content found in assets');
        throw Exception('No UI content found');
      }
      debugPrint('[ContainerAppShell] UI content length: ${uiContent.length} characters');
      debugPrint('[ContainerAppShell] UI content preview: ${uiContent.substring(0, uiContent.length > 300 ? 300 : uiContent.length)}...');

      debugPrint('[ContainerAppShell] Calling _runtime.loadUI()...');
      final loadedWidget = _runtime.loadUI(uiContent, context);
      debugPrint('[ContainerAppShell] loadUI returned widget: ${loadedWidget.runtimeType}');
      
      if (loadedWidget == null) {
        debugPrint('[ContainerAppShell] ERROR: loadUI returned null widget!');
        throw Exception('loadUI returned null widget');
      }

      setState(() {
        _loadedUI = loadedWidget;
        _currentStep = LoadingStep.complete;
        _isLoading = false;
      });
      debugPrint('[ContainerAppShell] App initialization complete. _loadedUI type: ${_loadedUI.runtimeType}');
    } catch (e, stackTrace) {
      debugPrint('[ContainerAppShell] Error during initialization: $e');
      debugPrint('[ContainerAppShell] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = e.toString();
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
        return _isOffline ? 'Loading from cache...' : 'Fetching assets...';
      case LoadingStep.loadingSchemas:
        return 'Loading schemas...';
      case LoadingStep.initializingDatabase:
        return 'Initializing database...';
      case LoadingStep.loadingWorkflows:
        return 'Loading workflows...';
      case LoadingStep.loadingRules:
        return 'Loading rules...';
      case LoadingStep.loadingUI:
        return 'Loading UI...';
      case LoadingStep.complete:
        return 'Complete';
    }
  }

  double _getProgress() {
    switch (_currentStep) {
      case LoadingStep.fetchingAssets:
        return 0.15;
      case LoadingStep.loadingSchemas:
        return 0.30;
      case LoadingStep.initializingDatabase:
        return 0.50;
      case LoadingStep.loadingWorkflows:
        return 0.65;
      case LoadingStep.loadingRules:
        return 0.80;
      case LoadingStep.loadingUI:
        return 0.95;
      case LoadingStep.complete:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ContainerAppShell] build() called: _isLoading=$_isLoading, _loadedUI=${_loadedUI != null ? _loadedUI.runtimeType : "null"}, _errorMessage=$_errorMessage');
    
    // If UI is loaded, show only the loaded UI (hide container welcome screen)
    if (!_isLoading && _loadedUI != null && _errorMessage == null) {
      debugPrint('[ContainerAppShell] Returning loaded UI widget: ${_loadedUI.runtimeType}');
      return _loadedUI!;
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
                if (_isOffline)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Offline mode - using cached assets',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
      case LoadingStep.loadingUI:
        return 'Loading UI';
      case LoadingStep.complete:
        return 'Complete';
    }
  }
}

