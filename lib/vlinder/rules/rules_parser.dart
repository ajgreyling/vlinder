import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:flutter/foundation.dart';

/// Rule definition
class Rule {
  final String id;
  final String? name;
  final String? condition;
  final String? action;
  final Map<String, dynamic> params;

  Rule({
    required this.id,
    this.name,
    this.condition,
    this.action,
    this.params = const {},
  });
}

/// Parser for rules.ht files
class RulesParser {
  final Hetu interpreter;

  RulesParser({required this.interpreter}) {
    _initializeRuleConstructors();
  }

  /// Initialize rule constructor functions in Hetu
  void _initializeRuleConstructors() {
    // Check if function is already defined to avoid redefinition errors
    try {
      interpreter.fetch('defineRule');
      // Function already exists, skip definition
      return;
    } catch (_) {
      // Function doesn't exist, proceed with definition
    }

    final ruleScript = '''
      fun defineRule(id, name, condition, action, params) {
        final result = {
          ruleType: 'Rule',
          id: id,
          name: name,
          condition: condition,
          action: action,
          params: params ?? {},
        }
        return result
      }
    ''';

    try {
      interpreter.eval(ruleScript);
    } catch (e) {
      // Ignore if already defined (shouldn't happen due to check above, but keep for safety)
    }
  }

  /// Load rules from rules.ht file content
  Map<String, Rule> loadRules(String scriptContent) {
    final scriptPreview = scriptContent.length > 300 
        ? scriptContent.substring(0, 300) 
        : scriptContent;
    
    try {
      debugPrint('[RulesParser] Evaluating rules script (${scriptContent.length} characters)');
      debugPrint('[RulesParser] Script preview: $scriptPreview...');
      
      // Rule constructors are already defined in constructor, just evaluate user script
      try {
        interpreter.eval(scriptContent);
        debugPrint('[RulesParser] Rules script evaluated successfully');
      } catch (e, stackTrace) {
        final errorMsg = 'Failed to evaluate rules script: $e';
        debugPrint('[RulesParser] ERROR: $errorMsg');
        debugPrint('[RulesParser] Script preview: $scriptPreview...');
        debugPrint('[RulesParser] Stack trace: $stackTrace');
        
        // Try to extract line number from Hetu error if available
        String enhancedError = errorMsg;
        if (e.toString().contains('line') || e.toString().contains('Line')) {
          enhancedError = '$errorMsg (check line numbers in error message)';
        }
        
        throw FormatException('[RulesParser] $enhancedError');
      }

      final rules = <String, Rule>{};

      // Try to get rules map
      try {
        final rulesValue = interpreter.fetch('rules');
        if (rulesValue is HTStruct) {
          debugPrint('[RulesParser] Found rules map with ${rulesValue.keys.length} entries');
          for (final key in rulesValue.keys) {
            final value = rulesValue[key];
            if (value is HTStruct) {
              final rule = _parseRule(value);
              if (rule != null) {
                rules[rule.id] = rule;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[RulesParser] Could not fetch "rules" map, trying individual variables: $e');
        // Try individual rule variables
        _extractRulesFromVariables(rules);
      }

      debugPrint('[RulesParser] Successfully loaded ${rules.length} rules');
      return rules;
    } catch (e, stackTrace) {
      if (e is FormatException && e.message.contains('[RulesParser]')) {
        rethrow;
      }
      final errorMsg = 'Failed to load rules: $e';
      debugPrint('[RulesParser] ERROR: $errorMsg');
      debugPrint('[RulesParser] Script preview: $scriptPreview...');
      debugPrint('[RulesParser] Stack trace: $stackTrace');
      throw FormatException('[RulesParser] $errorMsg');
    }
  }

  /// Extract rules from individual variables
  void _extractRulesFromVariables(Map<String, Rule> rules) {
    // Try common rule variable names
    final commonNames = ['validationRules', 'businessRules', 'fieldRules'];
    
    for (final name in commonNames) {
      try {
        final value = interpreter.fetch(name);
        if (value is HTStruct) {
          for (final key in value.keys) {
            final ruleValue = value[key];
            if (ruleValue is HTStruct) {
              final rule = _parseRule(ruleValue);
              if (rule != null) {
                rules[rule.id] = rule;
              }
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Parse a rule from HTStruct
  Rule? _parseRule(HTStruct struct) {
    try {
      if (!struct.containsKey('id')) {
        return null;
      }

      final id = struct['id'].toString();
      final name = struct.containsKey('name') ? struct['name'].toString() : null;
      final condition = struct.containsKey('condition') 
          ? struct['condition'].toString() 
          : null;
      final action = struct.containsKey('action') 
          ? struct['action'].toString() 
          : null;
      
      final params = <String, dynamic>{};
      if (struct.containsKey('params')) {
        final paramsValue = struct['params'];
        if (paramsValue is HTStruct) {
          for (final key in paramsValue.keys) {
            params[key] = _convertHTValue(paramsValue[key]);
          }
        }
      }

      return Rule(
        id: id,
        name: name,
        condition: condition,
        action: action,
        params: params,
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

  /// Get rule constructor functions script
  String _getRuleConstructorsScript() {
    return '''
      fun defineRule(id, name, condition, action, params) {
        final result = {
          ruleType: 'Rule',
          id: id,
          name: name,
          condition: condition,
          action: action,
          params: params ?? {},
        }
        return result
      }
    ''';
  }
}

