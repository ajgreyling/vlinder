import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart';
import 'workflow_parser.dart';

/// Parser for YAML workflow definitions
/// Converts YAML structure to Workflow objects
class YAMLWorkflowParser {
  /// Parse workflows from YAML file content
  /// Returns a map of workflow IDs to Workflow objects
  Map<String, Workflow> loadWorkflows(String yamlContent) {
    try {
      final yamlDoc = loadYaml(yamlContent);
      
      if (yamlDoc is! Map) {
        throw FormatException('[YAMLWorkflowParser] Expected YAML document to be a Map, got ${yamlDoc.runtimeType}');
      }

      // Look for 'workflows' key
      if (!yamlDoc.containsKey('workflows')) {
        throw FormatException('[YAMLWorkflowParser] Expected "workflows" key in YAML document');
      }

      final workflowsValue = yamlDoc['workflows'];
      if (workflowsValue is! Map) {
        throw FormatException('[YAMLWorkflowParser] Expected "workflows" to be a Map, got ${workflowsValue.runtimeType}');
      }

      final workflows = <String, Workflow>{};

      // Parse each workflow
      for (final entry in (workflowsValue as Map).entries) {
        final workflowId = entry.key.toString();
        final workflowData = entry.value;
        
        if (workflowData is Map) {
          final workflow = _parseWorkflow(workflowId, workflowData);
          if (workflow != null) {
            workflows[workflow.id] = workflow;
          }
        }
      }

      debugPrint('[YAMLWorkflowParser] Successfully loaded ${workflows.length} workflows');
      return workflows;
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to parse YAML workflow definition: $e';
      debugPrint('[YAMLWorkflowParser] ERROR: $errorMsg');
      debugPrint('[YAMLWorkflowParser] Stack trace: $stackTrace');
      throw FormatException('[YAMLWorkflowParser] $errorMsg');
    }
  }

  /// Parse a workflow from YAML map
  Workflow? _parseWorkflow(String workflowId, Map workflowData) {
    try {
      // Extract required fields
      final id = workflowData.containsKey('id') 
          ? workflowData['id'].toString() 
          : workflowId;
      
      if (!workflowData.containsKey('initialStep')) {
        debugPrint('[YAMLWorkflowParser] Workflow "$id" missing required field "initialStep"');
        return null;
      }

      final label = workflowData.containsKey('label') 
          ? workflowData['label'].toString() 
          : null;
      final initialStep = workflowData['initialStep'].toString();
      
      final stepsMap = <String, WorkflowStep>{};
      
      // Parse steps
      if (workflowData.containsKey('steps')) {
        final stepsValue = workflowData['steps'];
        if (stepsValue is Map) {
          for (final stepEntry in stepsValue.entries) {
            final stepId = stepEntry.key.toString();
            final stepData = stepEntry.value;
            if (stepData is Map) {
              final step = _parseStep(stepId, stepData);
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
    } catch (e, stackTrace) {
      debugPrint('[YAMLWorkflowParser] Error parsing workflow "$workflowId": $e');
      debugPrint('[YAMLWorkflowParser] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse a workflow step from YAML map
  WorkflowStep? _parseStep(String stepId, Map stepData) {
    try {
      final id = stepData.containsKey('id') 
          ? stepData['id'].toString() 
          : stepId;
      final label = stepData.containsKey('label') 
          ? stepData['label'].toString() 
          : null;
      final screenId = stepData.containsKey('screenId') 
          ? stepData['screenId'].toString() 
          : null;
      
      // Parse conditions
      final conditions = <String, dynamic>{};
      if (stepData.containsKey('conditions')) {
        final conditionsValue = stepData['conditions'];
        if (conditionsValue is Map) {
          for (final entry in conditionsValue.entries) {
            conditions[entry.key.toString()] = _convertYamlValue(entry.value);
          }
        }
      }

      // Parse nextSteps
      final nextSteps = <String>[];
      if (stepData.containsKey('nextSteps')) {
        final nextStepsValue = stepData['nextSteps'];
        if (nextStepsValue is List) {
          for (final step in nextStepsValue) {
            nextSteps.add(step.toString());
          }
        } else if (nextStepsValue is String) {
          // Handle single string value
          nextSteps.add(nextStepsValue);
        }
      }

      return WorkflowStep(
        id: id,
        label: label,
        screenId: screenId,
        conditions: conditions,
        nextSteps: nextSteps,
      );
    } catch (e, stackTrace) {
      debugPrint('[YAMLWorkflowParser] Error parsing step "$stepId": $e');
      debugPrint('[YAMLWorkflowParser] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Convert YAML value to Dart type
  dynamic _convertYamlValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map((e) => _convertYamlValue(e)).toList();
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key.toString()] = _convertYamlValue(entry.value);
      }
      return result;
    }
    return value.toString();
  }
}
