import 'package:flutter/material.dart';
import 'rules_parser.dart';
import 'package:hetu_script/hetu_script.dart';

/// Engine for evaluating and executing rules
class RulesEngine {
  final Hetu interpreter;
  final Map<String, Rule> rules;

  RulesEngine({
    required this.interpreter,
    required this.rules,
  });

  /// Evaluate a rule condition
  bool evaluateRule(String ruleId, Map<String, dynamic> context) {
    final rule = rules[ruleId];
    if (rule == null) {
      debugPrint('Rule not found: $ruleId');
      return false;
    }

    if (rule.condition == null) {
      return true; // No condition means always true
    }

    try {
      // Inject context into interpreter
      _injectContext(context);

      // Evaluate condition as Hetu expression
      final conditionScript = 'final result = ${rule.condition}';
      interpreter.eval(conditionScript);
      
      final result = interpreter.fetch('result');
      if (result is bool) {
        return result;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error evaluating rule condition: $e');
      return false;
    }
  }

  /// Execute a rule action
  Future<void> executeRule(String ruleId, Map<String, dynamic> context) async {
    final rule = rules[ruleId];
    if (rule == null) {
      throw ArgumentError('Rule not found: $ruleId');
    }

    if (rule.action == null) {
      return; // No action to execute
    }

    try {
      // Inject context and rule params
      final fullContext = Map<String, dynamic>.from(context);
      fullContext.addAll(rule.params);
      _injectContext(fullContext);

      // Execute action as Hetu function call or expression
      if (rule.action!.contains('(')) {
        // Function call
        interpreter.eval(rule.action!);
      } else {
        // Variable assignment or expression
        interpreter.eval('final _ = ${rule.action}');
      }
    } catch (e) {
      debugPrint('Error executing rule action: $e');
      rethrow;
    }
  }

  /// Evaluate all rules that match a context
  List<String> evaluateRules(Map<String, dynamic> context) {
    final matchingRules = <String>[];

    for (final rule in rules.values) {
      if (evaluateRule(rule.id, context)) {
        matchingRules.add(rule.id);
      }
    }

    return matchingRules;
  }

  /// Execute all matching rules
  Future<void> executeMatchingRules(Map<String, dynamic> context) async {
    final matchingRules = evaluateRules(context);

    for (final ruleId in matchingRules) {
      try {
        await executeRule(ruleId, context);
      } catch (e) {
        debugPrint('Error executing rule $ruleId: $e');
      }
    }
  }

  /// Inject context into Hetu interpreter
  void _injectContext(Map<String, dynamic> context) {
    final contextScript = StringBuffer();
    contextScript.writeln('final context = {');
    
    context.forEach((key, value) {
      if (value is String) {
        contextScript.writeln('  $key: "$value",');
      } else if (value is num) {
        contextScript.writeln('  $key: $value,');
      } else if (value is bool) {
        contextScript.writeln('  $key: ${value.toString()},');
      } else if (value is Map) {
        contextScript.writeln('  $key: ${_mapToHetuStruct(value)},');
      } else {
        contextScript.writeln('  $key: null,');
      }
    });
    
    contextScript.writeln('}');

    try {
      interpreter.eval(contextScript.toString());
    } catch (e) {
      debugPrint('Warning: Could not inject context: $e');
    }
  }

  /// Convert Dart Map to Hetu struct string
  String _mapToHetuStruct(Map<dynamic, dynamic> map) {
    final buffer = StringBuffer();
    buffer.write('{');
    final entries = map.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final key = entry.key.toString();
      final value = entry.value;
      
      buffer.write('$key: ');
      if (value is String) {
        buffer.write('"$value"');
      } else if (value is num) {
        buffer.write(value.toString());
      } else if (value is bool) {
        buffer.write(value.toString());
      } else if (value is Map) {
        buffer.write(_mapToHetuStruct(value));
      } else {
        buffer.write('null');
      }
      
      if (i < entries.length - 1) {
        buffer.write(', ');
      }
    }
    buffer.write('}');
    return buffer.toString();
  }
}

