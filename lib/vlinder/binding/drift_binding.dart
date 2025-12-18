import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

/// Schema field definition for validation and binding
class SchemaField {
  final String name;
  final String type; // 'text', 'number', 'integer', 'decimal', 'boolean', 'date', etc.
  final bool required;
  final dynamic defaultValue;
  final Map<String, dynamic>? constraints; // min, max, pattern, etc.

  SchemaField({
    required this.name,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.constraints,
  });
}

/// Entity schema definition
class EntitySchema {
  final String name;
  final Map<String, SchemaField> fields;
  final String? primaryKey;

  EntitySchema({
    required this.name,
    required this.fields,
    this.primaryKey,
  });

  SchemaField? getField(String fieldName) {
    return fields[fieldName];
  }
}

/// Form state manager for Drift entity binding
class FormStateManager {
  final EntitySchema schema;
  final Map<String, dynamic> _values = {};
  final Map<String, String?> _errors = {};
  final ValueNotifier<Map<String, dynamic>> _valueNotifier =
      ValueNotifier<Map<String, dynamic>>({});

  FormStateManager({required this.schema});

  /// Get current form values
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  /// Get value notifier for reactive updates
  ValueNotifier<Map<String, dynamic>> get valueNotifier => _valueNotifier;

  /// Set a field value
  void setValue(String fieldName, dynamic value) {
    _values[fieldName] = value;
    _validateField(fieldName, value);
    _valueNotifier.value = Map.from(_values);
  }

  /// Get a field value
  dynamic getValue(String fieldName) {
    return _values[fieldName] ?? schema.getField(fieldName)?.defaultValue;
  }

  /// Get field error
  String? getError(String fieldName) {
    return _errors[fieldName];
  }

  /// Validate a single field
  void _validateField(String fieldName, dynamic value) {
    final field = schema.getField(fieldName);
    if (field == null) {
      _errors[fieldName] = 'Unknown field: $fieldName';
      return;
    }

    // Required validation
    if (field.required && (value == null || value == '')) {
      _errors[fieldName] = 'This field is required';
      return;
    }

    // Type validation
    if (value != null && value != '') {
      switch (field.type) {
        case 'number':
        case 'integer':
        case 'decimal':
          if (value is! num) {
            try {
              num.parse(value.toString());
            } catch (e) {
              _errors[fieldName] = 'Must be a number';
              return;
            }
          }
          break;
        case 'boolean':
          if (value is! bool) {
            _errors[fieldName] = 'Must be true or false';
            return;
          }
          break;
      }

      // Constraint validation
      if (field.constraints != null) {
        if (field.type == 'number' || field.type == 'integer' || field.type == 'decimal') {
          final numValue = value is num ? value : num.parse(value.toString());
          if (field.constraints!['min'] != null && numValue < field.constraints!['min']) {
            _errors[fieldName] = 'Minimum value is ${field.constraints!['min']}';
            return;
          }
          if (field.constraints!['max'] != null && numValue > field.constraints!['max']) {
            _errors[fieldName] = 'Maximum value is ${field.constraints!['max']}';
            return;
          }
        }
        if (field.type == 'text' && field.constraints!['maxLength'] != null) {
          if (value.toString().length > field.constraints!['maxLength']) {
            _errors[fieldName] = 'Maximum length is ${field.constraints!['maxLength']}';
            return;
          }
        }
      }
    }

    // Clear error if validation passes
    _errors[fieldName] = null;
  }

  /// Validate all fields
  bool validate() {
    for (final fieldName in schema.fields.keys) {
      _validateField(fieldName, getValue(fieldName));
    }
    return _errors.values.every((error) => error == null);
  }

  /// Check if form is valid
  bool get isValid => _errors.values.every((error) => error == null);

  /// Reset form
  void reset() {
    _values.clear();
    _errors.clear();
    _valueNotifier.value = {};
  }
}

/// Provider for accessing form state managers
class FormStateProvider extends InheritedWidget {
  final FormStateManager formState;

  const FormStateProvider({
    super.key,
    required this.formState,
    required super.child,
  });

  static FormStateManager? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FormStateProvider>()?.formState;
  }

  @override
  bool updateShouldNotify(FormStateProvider oldWidget) {
    return formState != oldWidget.formState;
  }
}

