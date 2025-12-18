import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:vlinder/vlinder/runtime/vlinder_runtime.dart';
import 'package:vlinder/vlinder/schema/schema_loader.dart';
import 'package:vlinder/vlinder/workflow/workflow_parser.dart';
import 'package:vlinder/vlinder/rules/rules_parser.dart';
import 'package:vlinder/vlinder/rules/rules_engine.dart';

/// End-to-end integration test simulating app startup
void main() {
  group('Integration Test - App Startup Simulation', () {
    final assetsDir = Directory('sample_app/assets');
    
    testWidgets('Complete app initialization with all .ht files', (WidgetTester tester) async {
      // Step 1: Initialize Hetu interpreter
      final interpreter = Hetu();
      interpreter.init();
      
      // Step 2: Load and parse schemas
      final schemaFile = File('${assetsDir.path}/schema.ht');
      expect(schemaFile.existsSync(), true, 
          reason: 'schema.ht must exist');
      
      final schemaLoader = SchemaLoader(interpreter: interpreter);
      final schemas = schemaLoader.loadSchemas(schemaFile.readAsStringSync());
      expect(schemas, isNotEmpty, 
          reason: 'At least one schema must be loaded');
      
      // Step 3: Load and parse workflows
      final workflowFile = File('${assetsDir.path}/workflows.ht');
      expect(workflowFile.existsSync(), true, 
          reason: 'workflows.ht must exist');
      
      final workflowParser = WorkflowParser(interpreter: interpreter);
      final workflows = workflowParser.loadWorkflows(workflowFile.readAsStringSync());
      expect(workflows, isNotEmpty, 
          reason: 'At least one workflow must be loaded');
      
      // Step 4: Load and parse rules
      final rulesFile = File('${assetsDir.path}/rules.ht');
      expect(rulesFile.existsSync(), true, 
          reason: 'rules.ht must exist');
      
      final rulesParser = RulesParser(interpreter: interpreter);
      final rules = rulesParser.loadRules(rulesFile.readAsStringSync());
      expect(rules, isNotEmpty, 
          reason: 'At least one rule must be loaded');
      
      // Step 5: Create rules engine
      final rulesEngine = RulesEngine(interpreter: interpreter, rules: rules);
      expect(rulesEngine, isNotNull,
          reason: 'Rules engine must be created successfully');
      
      // Step 6: Initialize VlinderRuntime and load UI
      final runtime = VlinderRuntime();
      final uiFile = File('${assetsDir.path}/ui.ht');
      expect(uiFile.existsSync(), true, 
          reason: 'ui.ht must exist');
      
      final uiContent = uiFile.readAsStringSync();
      
      // Should build UI without errors (using widget tester for context)
      Widget? builtWidget;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              builtWidget = runtime.loadUI(uiContent, context);
              return builtWidget ?? Container();
            },
          ),
        ),
      );
      
      expect(builtWidget, isA<Widget>(),
          reason: 'loadUI should return a Widget');
    });
    
    test('Workflow step references are valid', () {
      final interpreter = Hetu();
      interpreter.init();
      
      final workflowParser = WorkflowParser(interpreter: interpreter);
      final workflowFile = File('${assetsDir.path}/workflows.ht');
      final workflows = workflowParser.loadWorkflows(workflowFile.readAsStringSync());
      
      for (final workflow in workflows.values) {
        // Check that initialStep exists
        expect(workflow.steps.containsKey(workflow.initialStep), true,
            reason: 'Workflow "${workflow.id}" initialStep "${workflow.initialStep}" must exist');
        
        // Check all nextSteps references
        for (final step in workflow.steps.values) {
          for (final nextStepId in step.nextSteps) {
            expect(workflow.steps.containsKey(nextStepId), true,
                reason: 'Step "${step.id}" in workflow "${workflow.id}" references invalid nextStep "$nextStepId"');
          }
        }
      }
    });
    
    test('Rules can be evaluated', () {
      final interpreter = Hetu();
      interpreter.init();
      
      final rulesParser = RulesParser(interpreter: interpreter);
      final rulesFile = File('${assetsDir.path}/rules.ht');
      final rules = rulesParser.loadRules(rulesFile.readAsStringSync());
      
      final rulesEngine = RulesEngine(interpreter: interpreter, rules: rules);
      
      // Test rule evaluation with sample context
      final testContext = {
        'field': 'email',
        'value': null,
        'totalAmount': 1500,
      };
      
      // Should evaluate without errors
      expect(() {
        rulesEngine.evaluateRules(testContext);
      }, returnsNormally,
          reason: 'Rules should evaluate without errors');
    });
  });
}
