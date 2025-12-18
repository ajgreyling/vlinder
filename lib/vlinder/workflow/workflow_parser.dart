import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:flutter/foundation.dart';

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

/// Parser for workflows.ht files
class WorkflowParser {
  final Hetu interpreter;

  WorkflowParser({required this.interpreter}) {
    _initializeWorkflowConstructors();
  }

  /// Initialize workflow constructor functions in Hetu
  void _initializeWorkflowConstructors() {
    // Check if functions are already defined to avoid redefinition errors
    try {
      interpreter.fetch('defineWorkflow');
      // Functions already exist, skip definition
      return;
    } catch (_) {
      // Functions don't exist, proceed with definition
    }

    final workflowScript = '''
      fun defineWorkflow(id, label, initialStep, steps) {
        final result = {
          workflowType: 'Workflow',
          id: id,
          label: label,
          initialStep: initialStep,
          steps: steps,
        }
        return result
      }
      
      fun defineStep(id, label, screenId, conditions, nextSteps) {
        final result = {
          stepType: 'WorkflowStep',
          id: id,
          label: label,
          screenId: screenId,
          conditions: conditions ?? {},
          nextSteps: nextSteps ?? [],
        }
        return result
      }
    ''';

    try {
      interpreter.eval(workflowScript);
    } catch (e) {
      // Ignore if already defined (shouldn't happen due to check above, but keep for safety)
    }
  }

  /// Load workflows from workflows.ht file content
  Map<String, Workflow> loadWorkflows(String scriptContent) {
    final scriptPreview = scriptContent.length > 300 
        ? scriptContent.substring(0, 300) 
        : scriptContent;
    
    try {
      debugPrint('[WorkflowParser] Evaluating workflow script (${scriptContent.length} characters)');
      debugPrint('[WorkflowParser] Script preview: $scriptPreview...');
      
      // Workflow constructors are already defined in constructor, just evaluate user script
      try {
        interpreter.eval(scriptContent);
        debugPrint('[WorkflowParser] Workflow script evaluated successfully');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to evaluate workflow script: $e';
        debugPrint('[WorkflowParser] ERROR: $errorMsg');
        debugPrint('[WorkflowParser] Script preview: $scriptPreview...');
        debugPrint('[WorkflowParser] Stack trace: $stackTrace');
        
        // Try to extract line number from Hetu error if available
        String enhancedError = errorMsg;
        if (e.toString().contains('line') || e.toString().contains('Line')) {
          enhancedError = '$errorMsg (check line numbers in error message)';
        }
        
        throw FormatException('[WorkflowParser] $enhancedError');
      }

      final workflows = <String, Workflow>{};

      // Try to get workflows map
      try {
        final workflowsValue = interpreter.fetch('workflows');
        if (workflowsValue is HTStruct) {
          debugPrint('[WorkflowParser] Found workflows map with ${workflowsValue.keys.length} entries');
          for (final key in workflowsValue.keys) {
            final value = workflowsValue[key];
            if (value is HTStruct) {
              final workflow = _parseWorkflow(value);
              if (workflow != null) {
                workflows[workflow.id] = workflow;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[WorkflowParser] Could not fetch "workflows" map, trying individual variables: $e');
        // Try individual workflow variables
        _extractWorkflowsFromVariables(workflows);
      }

      debugPrint('[WorkflowParser] Successfully loaded ${workflows.length} workflows');
      return workflows;
    } catch (e, stackTrace) {
      if (e is FormatException && e.message.contains('[WorkflowParser]')) {
        rethrow;
      }
      final errorMsg = 'Failed to load workflows: $e';
      debugPrint('[WorkflowParser] ERROR: $errorMsg');
      debugPrint('[WorkflowParser] Script preview: $scriptPreview...');
      debugPrint('[WorkflowParser] Stack trace: $stackTrace');
      throw FormatException('[WorkflowParser] $errorMsg');
    }
  }

  /// Extract workflows from individual variables
  void _extractWorkflowsFromVariables(Map<String, Workflow> workflows) {
    // Try common workflow variable names
    final commonNames = ['customerWorkflow', 'orderWorkflow', 'inspectionWorkflow'];
    
    for (final name in commonNames) {
      try {
        final value = interpreter.fetch(name);
        if (value is HTStruct) {
          final workflow = _parseWorkflow(value);
          if (workflow != null) {
            workflows[workflow.id] = workflow;
          }
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Parse a workflow from HTStruct
  Workflow? _parseWorkflow(HTStruct struct) {
    try {
      if (!struct.containsKey('id') || !struct.containsKey('initialStep')) {
        return null;
      }

      final id = struct['id'].toString();
      final label = struct.containsKey('label') ? struct['label'].toString() : null;
      final initialStep = struct['initialStep'].toString();
      
      final stepsMap = <String, WorkflowStep>{};
      
      // Parse steps
      if (struct.containsKey('steps')) {
        final stepsValue = struct['steps'];
        if (stepsValue is HTStruct) {
          for (final stepId in stepsValue.keys) {
            final stepValue = stepsValue[stepId];
            if (stepValue is HTStruct) {
              final step = _parseStep(stepId, stepValue);
              if (step != null) {
                stepsMap[step.id] = step;
              }
            }
          }
        }
      }

      return Workflow(
        id: id,
        label: label,
        initialStep: initialStep,
        steps: stepsMap,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse a workflow step from HTStruct
  WorkflowStep? _parseStep(String stepId, HTStruct stepStruct) {
    try {
      final id = stepStruct.containsKey('id') 
          ? stepStruct['id'].toString() 
          : stepId;
      final label = stepStruct.containsKey('label') 
          ? stepStruct['label'].toString() 
          : null;
      final screenId = stepStruct.containsKey('screenId') 
          ? stepStruct['screenId'].toString() 
          : null;
      
      final conditions = <String, dynamic>{};
      if (stepStruct.containsKey('conditions')) {
        final conditionsValue = stepStruct['conditions'];
        if (conditionsValue is HTStruct) {
          for (final key in conditionsValue.keys) {
            conditions[key] = _convertHTValue(conditionsValue[key]);
          }
        }
      }

      final nextSteps = <String>[];
      if (stepStruct.containsKey('nextSteps')) {
        final nextStepsValue = stepStruct['nextSteps'];
        if (nextStepsValue is List) {
          for (final step in nextStepsValue) {
            nextSteps.add(step.toString());
          }
        }
      }

      return WorkflowStep(
        id: id,
        label: label,
        screenId: screenId,
        conditions: conditions,
        nextSteps: nextSteps,
      );
    } catch (e) {
      return null;
    }
  }

  /// Convert HTValue to Dart value
  dynamic _convertHTValue(dynamic value) {
    if (value is String) {
      return value;
    } else if (value is int) {
      return value;
    } else if (value is double) {
      return value;
    } else if (value is bool) {
      return value;
    } else if (value == null) {
      return null;
    }
    return value.toString();
  }

  /// Get workflow constructor functions script
  String _getWorkflowConstructorsScript() {
    return '''
      fun defineWorkflow(id, label, initialStep, steps) {
        final result = {
          workflowType: 'Workflow',
          id: id,
          label: label,
          initialStep: initialStep,
          steps: steps,
        }
        return result
      }
      
      fun defineStep(id, label, screenId, conditions, nextSteps) {
        final result = {
          stepType: 'WorkflowStep',
          id: id,
          label: label,
          screenId: screenId,
          conditions: conditions ?? {},
          nextSteps: nextSteps ?? [],
        }
        return result
      }
    ''';
  }
}

