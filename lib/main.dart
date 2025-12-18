import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../vlinder/vlinder.dart';
import 'container/app_shell.dart';

void main() {
  runApp(const VlinderApp());
}

class VlinderApp extends StatelessWidget {
  const VlinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vlinder Container',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ContainerAppShell(),
    );
  }
}

class VlinderHomePage extends StatefulWidget {
  const VlinderHomePage({super.key});

  @override
  State<VlinderHomePage> createState() => _VlinderHomePageState();
}

class _VlinderHomePageState extends State<VlinderHomePage> {
  final VlinderRuntime _runtime = VlinderRuntime();
  Widget? _loadedUI;
  String? _uiScript;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExampleUI();
  }

  Future<void> _loadExampleUI() async {
    try {
      // Load example ui.ht file
      final uiScript = await rootBundle.loadString('example/ui.ht');
      
      // Store the script - we'll build the UI in the build method when context is available
      setState(() {
        _uiScript = uiScript;
      });
    } catch (e) {
      // For errors, we can't use context yet, so store error message
      setState(() {
        _errorMessage = 'Failed to load example UI: $e';
      });
    }
  }

  Widget _buildErrorWidget(String message) {
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
                'Error',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error if we have one
    if (_errorMessage != null && _loadedUI == null) {
      return _buildErrorWidget(_errorMessage!);
    }

    // Build UI from script if we have it but haven't built yet
    if (_uiScript != null && _loadedUI == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            try {
              _loadedUI = _runtime.loadUI(_uiScript!, context);
            } catch (e) {
              _loadedUI = _buildErrorWidget('Failed to build UI: $e');
            }
          });
        }
      });
    }

    return _loadedUI ?? const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

