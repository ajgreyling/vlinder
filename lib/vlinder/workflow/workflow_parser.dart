import 'package:flutter/foundation.dart';
import 'yaml_workflow_parser.dart';

/// Workflow step definition
class WorkflowStep {
  final String id;
  final String? label;
  final String? screenId;
  final Map<String, dynamic> conditions;
  final List<String> nextSteps;

  WorkflowStep({
    required this.id,
    this.label,
    this.screenId,
    this.conditions = const {},
    this.nextSteps = const [],
  });
}

/// Workflow definition
class Workflow {
  final String id;
  final String? label;
  final String initialStep;
  final Map<String, WorkflowStep> steps;
  final Map<String, dynamic> state;

  Workflow({
    required this.id,
    this.label,
    required this.initialStep,
    required this.steps,
    this.state = const {},
  });
}

/// Parser for workflows.yaml files
/// Delegates to YAMLWorkflowParser for YAML parsing
class WorkflowParser {
  final YAMLWorkflowParser _yamlParser;

  /// Create a WorkflowParser
  /// Note: Hetu interpreter is no longer required for workflow parsing
  WorkflowParser({Object? interpreter}) 
      : _yamlParser = YAMLWorkflowParser() {
    // Interpreter parameter kept for backward compatibility but not used
    if (interpreter != null) {
      debugPrint('[WorkflowParser] Warning: Hetu interpreter parameter is deprecated and ignored. Workflows now use YAML format.');
    }
  }

  /// Load workflows from workflows.yaml file content
  Map<String, Workflow> loadWorkflows(String yamlContent) {
    try {
      return _yamlParser.loadWorkflows(yamlContent);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to load workflows: $e';
      debugPrint('[WorkflowParser] ERROR: $errorMsg');
      debugPrint('[WorkflowParser] Stack trace: $stackTrace');
      throw FormatException('[WorkflowParser] $errorMsg');
    }
  }
}

