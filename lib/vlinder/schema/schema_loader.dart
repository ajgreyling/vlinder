import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import '../binding/drift_binding.dart';

/// Loader for parsing schema.ht files and converting to EntitySchema objects
class SchemaLoader {
  final Hetu interpreter;

  SchemaLoader({required this.interpreter}) {
    _initializeSchemaConstructors();
  }

  /// Initialize schema constructor functions in Hetu
  void _initializeSchemaConstructors() {
    final schemaScript = '''
      fun defineSchema(name, primaryKey, fields) {
        final result = {
          schemaType: 'EntitySchema',
          name: name,
          primaryKey: primaryKey,
          fields: fields,
        }
        return result
      }
      
      fun defineField(name, type, required, defaultValue, constraints) {
        final result = {
          fieldType: 'SchemaField',
          name: name,
          type: type,
          required: required ?? false,
          defaultValue: defaultValue,
          constraints: constraints ?? {},
        }
        return result
      }
    ''';

    try {
      interpreter.eval(schemaScript);
    } catch (e) {
      // Ignore if already defined
    }
  }

  /// Load schemas from schema.ht file content
  /// Returns a map of entity names to EntitySchema objects
  Map<String, EntitySchema> loadSchemas(String scriptContent) {
    try {
      // Combine schema constructors with user script
      final fullScript = _getSchemaConstructorsScript() + '\n\n' + scriptContent;
      
      // Evaluate the script
      interpreter.eval(fullScript);

      // Extract schema definitions
      final schemas = <String, EntitySchema>{};
      
      // Look for schema variables (common patterns: customerSchema, productSchema, etc.)
      // Or look for a schemas map/object
      try {
        final schemasValue = interpreter.fetch('schemas');
        if (schemasValue is HTStruct) {
          for (final key in schemasValue.keys) {
            final value = schemasValue[key];
            if (value is HTStruct) {
              final schema = _parseSchema(value);
              if (schema != null) {
                schemas[schema.name] = schema;
              }
            }
          }
        }
      } catch (_) {
        // Try individual schema variables
        _extractSchemasFromVariables(schemas);
      }

      return schemas;
    } catch (e) {
      throw FormatException('Failed to load schemas: $e');
    }
  }

  /// Extract schemas from individual variables
  void _extractSchemasFromVariables(Map<String, EntitySchema> schemas) {
    // Try common schema variable names
    final commonNames = ['customerSchema', 'productSchema', 'orderSchema'];
    
    for (final name in commonNames) {
      try {
        final value = interpreter.fetch(name);
        if (value is HTStruct) {
          final schema = _parseSchema(value);
          if (schema != null) {
            schemas[schema.name] = schema;
          }
        }
      } catch (_) {
        continue;
      }
    }

    // Also try to find any variable ending in 'Schema'
    // This would require iterating through all variables, which Hetu doesn't directly support
    // So we rely on the script defining schemas in a known structure
  }

  /// Parse a schema from HTStruct
  EntitySchema? _parseSchema(HTStruct struct) {
    try {
      // Check if it's a schema definition
      final schemaType = struct['schemaType'];
      if (schemaType == null || schemaType.toString() != 'EntitySchema') {
        // Try to infer from structure
        if (!struct.containsKey('name') || !struct.containsKey('fields')) {
          return null;
        }
      }

      final name = struct['name'].toString();
      final primaryKey = struct.containsKey('primaryKey') 
          ? struct['primaryKey'].toString() 
          : null;
      
      final fieldsMap = <String, SchemaField>{};
      
      // Parse fields
      final fieldsValue = struct['fields'];
      if (fieldsValue is HTStruct) {
        for (final fieldName in fieldsValue.keys) {
          final fieldValue = fieldsValue[fieldName];
          if (fieldValue is HTStruct) {
            final field = _parseField(fieldName, fieldValue);
            if (field != null) {
              fieldsMap[field.name] = field;
            }
          }
        }
      }

      return EntitySchema(
        name: name,
        fields: fieldsMap,
        primaryKey: primaryKey,
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse a field definition from HTStruct
  SchemaField? _parseField(String fieldName, HTStruct fieldStruct) {
    try {
      // Get field type
      final type = fieldStruct.containsKey('type')
          ? fieldStruct['type'].toString()
          : 'text'; // Default to text
      
      final required = fieldStruct.containsKey('required')
          ? (fieldStruct['required'] is bool
              ? fieldStruct['required'] as bool
              : fieldStruct['required'].toString() == 'true')
          : false;
      
      final defaultValue = fieldStruct.containsKey('defaultValue')
          ? _convertHTValue(fieldStruct['defaultValue'])
          : null;
      
      Map<String, dynamic>? constraints;
      if (fieldStruct.containsKey('constraints')) {
        final constraintsValue = fieldStruct['constraints'];
        if (constraintsValue is HTStruct) {
          constraints = {};
          for (final key in constraintsValue.keys) {
            constraints![key] = _convertHTValue(constraintsValue[key]);
          }
        }
      }

      return SchemaField(
        name: fieldName,
        type: type,
        required: required,
        defaultValue: defaultValue,
        constraints: constraints,
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

  /// Get schema constructor functions script
  String _getSchemaConstructorsScript() {
    return '''
      fun defineSchema(name, primaryKey, fields) {
        final result = {
          schemaType: 'EntitySchema',
          name: name,
          primaryKey: primaryKey,
          fields: fields,
        }
        return result
      }
      
      fun defineField(name, type, required, defaultValue, constraints) {
        final result = {
          fieldType: 'SchemaField',
          name: name,
          type: type,
          required: required ?? false,
          defaultValue: defaultValue,
          constraints: constraints ?? {},
        }
        return result
      }
    ''';
  }
}

