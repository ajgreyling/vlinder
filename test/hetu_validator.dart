import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:vlinder/vlinder/schema/schema_loader.dart';
import 'package:vlinder/vlinder/parser/yaml_ui_parser.dart';
import 'package:vlinder/vlinder/parser/ui_parser.dart';
import 'package:vlinder/vlinder/workflow/workflow_parser.dart';
import 'package:vlinder/vlinder/rules/rules_parser.dart';
import 'package:vlinder/vlinder/core/widget_registry.dart';

/// Validates Hetu script files using actual Vlinder parsers
void main() {
  group('Hetu Script Validation', () {
    final assetsDir = Directory('sample_app/assets');
    
    test('Schema file (schema.yaml) validation', () {
      final schemaFile = File('${assetsDir.path}/schema.yaml');
      expect(schemaFile.existsSync(), true, 
          reason: 'schema.yaml file (OpenAPI format) must exist in sample_app/assets/');
      
      final content = schemaFile.readAsStringSync();
      
      final loader = SchemaLoader();
      
      // Should parse without errors
      expect(() => loader.loadSchemas(content), returnsNormally,
          reason: 'Schema file should parse without errors');
      
      final schemas = loader.loadSchemas(content);
      
      // Validate schemas have required fields
      for (final schema in schemas.values) {
        expect(schema.name, isNotEmpty, 
            reason: 'Schema must have a name');
        expect(schema.primaryKey, isNotEmpty, 
            reason: 'Schema must have a primaryKey');
        expect(schema.fields, isNotEmpty, 
            reason: 'Schema must have fields');
        
        // Validate field types
        for (final field in schema.fields.values) {
          expect(['text', 'integer', 'decimal', 'date', 'boolean'], 
              contains(field.type),
              reason: 'Field type "${field.type}" must be valid');
        }
      }
    });
    
    test('UI file (ui.yaml) validation', () {
      final uiFile = File('${assetsDir.path}/ui.yaml');
      expect(uiFile.existsSync(), true, 
          reason: 'ui.yaml file must exist in sample_app/assets/');
      
      final content = uiFile.readAsStringSync();
      
      final registry = WidgetRegistry();
      final parser = YAMLUIParser(registry: registry);
      
      // Should parse without errors
      expect(() => parser.parse(content), returnsNormally,
          reason: 'UI file should parse without errors');
      
      final parsedWidget = parser.parse(content);
      
      // Validate screen structure
      expect(parsedWidget.widgetName, 'Screen',
          reason: 'Root widget must be a Screen');
      expect(parsedWidget.properties['id'], isNotNull,
          reason: 'Screen must have an id');
    });
    
    test('Workflow file (workflows.yaml) validation', () {
      final workflowFile = File('${assetsDir.path}/workflows.yaml');
      expect(workflowFile.existsSync(), true, 
          reason: 'workflows.yaml file must exist in sample_app/assets/');
      
      final content = workflowFile.readAsStringSync();
      
      final parser = WorkflowParser();
      
      // Should parse without errors
      expect(() => parser.loadWorkflows(content), returnsNormally,
          reason: 'Workflow file should parse without errors');
      
      final workflows = parser.loadWorkflows(content);
      
      // Validate workflow structure
      for (final workflow in workflows.values) {
        expect(workflow.id, isNotEmpty,
            reason: 'Workflow must have an id');
        expect(workflow.initialStep, isNotEmpty,
            reason: 'Workflow must have an initialStep');
        expect(workflow.steps, isNotEmpty,
            reason: 'Workflow must have steps');
        
        // Validate initialStep exists
        expect(workflow.steps.containsKey(workflow.initialStep), true,
            reason: 'Workflow initialStep "${workflow.initialStep}" must exist in steps');
        
        // Validate all nextSteps references exist
        for (final step in workflow.steps.values) {
          for (final nextStepId in step.nextSteps) {
            expect(workflow.steps.containsKey(nextStepId), true,
                reason: 'Step "${step.id}" references non-existent nextStep "$nextStepId"');
          }
        }
      }
    });
    
    test('Rules file (rules.ht) validation', () {
      final rulesFile = File('${assetsDir.path}/rules.ht');
      expect(rulesFile.existsSync(), true, 
          reason: 'rules.ht file must exist in sample_app/assets/');
      
      final content = rulesFile.readAsStringSync();
      final interpreter = Hetu();
      interpreter.init();
      
      final parser = RulesParser(interpreter: interpreter);
      
      // Should parse without errors
      expect(() => parser.loadRules(content), returnsNormally,
          reason: 'Rules file should parse without errors');
      
      final rules = parser.loadRules(content);
      
      // Validate rule structure
      for (final rule in rules.values) {
        expect(rule.id, isNotEmpty,
            reason: 'Rule must have an id');
        
        // Validate condition syntax (can be evaluated)
        if (rule.condition != null && rule.condition!.isNotEmpty) {
          try {
            // Try to evaluate condition with a sample context
            interpreter.eval('''
              final context = {
                field: "test",
                value: null,
                totalAmount: 0,
              }
              final result = ${rule.condition}
            ''');
            // If we get here, condition syntax is valid
          } catch (e) {
            fail('Rule "${rule.id}" has invalid condition syntax: ${rule.condition}\nError: $e');
          }
        }
      }
    });
    
    test('Cross-file reference validation', () {
      // Load all files
      final schemaLoader = SchemaLoader();
      final schemaContent = File('${assetsDir.path}/schema.yaml').readAsStringSync();
      final schemas = schemaLoader.loadSchemas(schemaContent);
      
      final registry = WidgetRegistry();
      final uiParser = YAMLUIParser(registry: registry);
      final uiContent = File('${assetsDir.path}/ui.yaml').readAsStringSync();
      final parsedWidget = uiParser.parse(uiContent);
      
      // Validate Form entity references match schema names
      void validateWidget(ParsedWidget widget) {
        if (widget.widgetName == 'Form') {
          final entityName = widget.properties['entity'] as String?;
          if (entityName != null) {
            expect(schemas.containsKey(entityName), true,
                reason: 'Form references entity "$entityName" which does not exist in schemas');
          }
        }
        
        // Recursively validate children
        for (final child in widget.children) {
          validateWidget(child);
        }
      }
      
      validateWidget(parsedWidget);
    });
  });
}

