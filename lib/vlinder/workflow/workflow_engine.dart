import 'package:flutter/material.dart';
import 'workflow_parser.dart';
import 'package:hetu_script/hetu_script.dart';

/// Engine for managing workflow state and transitions
class WorkflowEngine {
  final Hetu interpreter;
  final Map<String, Workflow> workflows;
  final Map<String, String> _currentSteps = {}; // workflowId -> currentStepId
  final Map<String, Map<String, dynamic>> _workflowState = {}; // workflowId -> state

  WorkflowEngine({
    required this.interpreter,
    required this.workflows,
  });

  /// Get current step for a workflow
  String? getCurrentStep(String workflowId) {
    return _currentSteps[workflowId];
  }

  /// Initialize a workflow
  void initializeWorkflow(String workflowId) {
    final workflow = workflows[workflowId];
    if (workflow == null) {
      throw ArgumentError('Workflow not found: $workflowId');
    }

    _currentSteps[workflowId] = workflow.initialStep;
    _workflowState[workflowId] = Map.from(workflow.state);
  }

  /// Transition to next step
  /// Returns true if transition was successful
  bool transitionToStep(String workflowId, String stepId, {Map<String, dynamic>? context}) {
    final workflow = workflows[workflowId];
    if (workflow == null) {
      return false;
    }

    final currentStepId = _currentSteps[workflowId];
    if (currentStepId == null) {
      initializeWorkflow(workflowId);
    }

    final currentStep = workflow.steps[currentStepId ?? workflow.initialStep];
    if (currentStep == null) {
      return false;
    }

    // Check if stepId is in nextSteps
    if (!currentStep.nextSteps.contains(stepId)) {
      debugPrint('Step $stepId is not a valid next step from ${currentStep.id}');
      return false;
    }

    // Check conditions if any
    if (currentStep.conditions.isNotEmpty && context != null) {
      if (!_evaluateConditions(currentStep.conditions, context)) {
        debugPrint('Conditions not met for transition to $stepId');
        return false;
      }
    }

    _currentSteps[workflowId] = stepId;
    return true;
  }

  /// Evaluate conditions for step transition
  bool _evaluateConditions(Map<String, dynamic> conditions, Map<String, dynamic> context) {
    for (final entry in conditions.entries) {
      final key = entry.key;
      final expectedValue = entry.value;
      final actualValue = context[key];

      if (actualValue != expectedValue) {
        return false;
      }
    }
    return true;
  }

  /// Get workflow state
  Map<String, dynamic> getWorkflowState(String workflowId) {
    return Map.from(_workflowState[workflowId] ?? {});
  }

  /// Update workflow state
  void updateWorkflowState(String workflowId, Map<String, dynamic> updates) {
    if (!_workflowState.containsKey(workflowId)) {
      _workflowState[workflowId] = {};
    }
    _workflowState[workflowId]!.addAll(updates);
  }

  /// Check if workflow is complete
  bool isWorkflowComplete(String workflowId) {
    final currentStepId = _currentSteps[workflowId];
    if (currentStepId == null) {
      return false;
    }

    final workflow = workflows[workflowId];
    if (workflow == null) {
      return false;
    }

    final currentStep = workflow.steps[currentStepId];
    return currentStep?.nextSteps.isEmpty ?? false;
  }

  /// Get screen ID for current step
  String? getScreenIdForCurrentStep(String workflowId) {
    final currentStepId = _currentSteps[workflowId];
    if (currentStepId == null) {
      return null;
    }

    final workflow = workflows[workflowId];
    if (workflow == null) {
      return null;
    }

    final currentStep = workflow.steps[currentStepId];
    return currentStep?.screenId;
  }
}


