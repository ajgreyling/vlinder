import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import '../vlinder/vlinder.dart';
import '../vlinder/schema/schema_loader.dart';
import '../vlinder/workflow/workflow_parser.dart';
import '../vlinder/workflow/workflow_engine.dart';
import '../vlinder/rules/rules_parser.dart';
import '../vlinder/rules/rules_engine.dart';
import '../vlinder/drift/database.dart';
import 'asset_fetcher.dart';
import 'config.dart';

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

  @override
  void initState() {
    super.initState();
    _interpreter = Hetu();
    _interpreter.init();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check if we have cached assets (offline mode)
      final hasCache = await _fetcher.hasCachedAssets();
      if (hasCache) {
        _isOffline = true;
      }

      // Fetch assets
      final assets = await _fetcher.fetchAllAssets();

      // Load schemas
      final schemaLoader = SchemaLoader(interpreter: _interpreter);
      final schemas = schemaLoader.loadSchemas(assets['schema.ht'] ?? '');

      // Initialize database with schemas
      final database = VlinderDatabase();
      for (final schema in schemas.values) {
        await database.createTableFromSchema(schema);
      }

      // Load workflows
      final workflowParser = WorkflowParser(interpreter: _interpreter);
      final workflows = workflowParser.loadWorkflows(assets['workflows.ht'] ?? '');

      // Load rules
      final rulesParser = RulesParser(interpreter: _interpreter);
      final rules = rulesParser.loadRules(assets['rules.ht'] ?? '');

      // Create workflow engine
      final workflowEngine = WorkflowEngine(
        interpreter: _interpreter,
        workflows: workflows,
      );

      // Create rules engine
      final rulesEngine = RulesEngine(
        interpreter: _interpreter,
        rules: rules,
      );

      // Load UI
      final uiContent = assets['ui.ht'] ?? '';
      if (uiContent.isEmpty) {
        throw Exception('No UI content found');
      }

      setState(() {
        _loadedUI = _runtime.loadUI(uiContent, context);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    await _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _isOffline ? 'Loading from cache...' : 'Fetching assets...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
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

    return _loadedUI ?? const Scaffold(
      body: Center(
        child: Text('No UI loaded'),
      ),
    );
  }
}

