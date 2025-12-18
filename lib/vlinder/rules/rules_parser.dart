import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';

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
      // Ignore if already defined
    }
  }

  /// Load rules from rules.ht file content
  Map<String, Rule> loadRules(String scriptContent) {
    try {
      final fullScript = _getRuleConstructorsScript() + '\n\n' + scriptContent;
      interpreter.eval(fullScript);

      final rules = <String, Rule>{};

      // Try to get rules map
      try {
        final rulesValue = interpreter.fetch('rules');
        if (rulesValue is HTStruct) {
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
      } catch (_) {
        // Try individual rule variables
        _extractRulesFromVariables(rules);
      }

      return rules;
    } catch (e) {
      throw FormatException('Failed to load rules: $e');
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

