import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';

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
      // Ignore if already defined
    }
  }

  /// Load workflows from workflows.ht file content
  Map<String, Workflow> loadWorkflows(String scriptContent) {
    try {
      final fullScript = _getWorkflowConstructorsScript() + '\n\n' + scriptContent;
      interpreter.eval(fullScript);

      final workflows = <String, Workflow>{};

      // Try to get workflows map
      try {
        final workflowsValue = interpreter.fetch('workflows');
        if (workflowsValue is HTStruct) {
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
      } catch (_) {
        // Try individual workflow variables
        _extractWorkflowsFromVariables(workflows);
      }

      return workflows;
    } catch (e) {
      throw FormatException('Failed to load workflows: $e');
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

