import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart';
import '../binding/drift_binding.dart';

/// Result of parsing a property
class _PropertyParseResult {
  final SchemaField? field;
  final String? relationship; // Referenced entity name from $ref
  final String? foreignKey; // Foreign key reference from x-foreign-key

  _PropertyParseResult({
    this.field,
    this.relationship,
    this.foreignKey,
  });
}

/// Loader for parsing schema.yaml files (OpenAPI 3.0 format) and converting to EntitySchema objects
class SchemaLoader {
  SchemaLoader();

  /// Load schemas from schema.yaml file content (OpenAPI 3.0 format)
  /// Returns a map of entity names to EntitySchema objects
  Map<String, EntitySchema> loadSchemas(String yamlContent) {
    try {
      final yamlDoc = loadYaml(yamlContent);
      
      if (yamlDoc is! Map) {
        throw FormatException('[SchemaLoader] Expected YAML document to be a Map, got ${yamlDoc.runtimeType}');
      }

      // Check for OpenAPI version
      if (!yamlDoc.containsKey('openapi')) {
        throw FormatException('[SchemaLoader] Expected "openapi" key in YAML document (OpenAPI 3.0 format required)');
      }

      final openapiVersion = yamlDoc['openapi']?.toString();
      if (openapiVersion != '3.0.0' && openapiVersion != '3.0') {
        debugPrint('[SchemaLoader] Warning: OpenAPI version is $openapiVersion, expected 3.0.0');
      }

      // Extract components/schemas section
      if (!yamlDoc.containsKey('components')) {
        throw FormatException('[SchemaLoader] Expected "components" key in YAML document');
      }

      final components = yamlDoc['components'];
      if (components is! Map) {
        throw FormatException('[SchemaLoader] Expected "components" to be a Map, got ${components.runtimeType}');
      }

      if (!components.containsKey('schemas')) {
        throw FormatException('[SchemaLoader] Expected "components.schemas" key in YAML document');
      }

      final schemasValue = components['schemas'];
      if (schemasValue is! Map) {
        throw FormatException('[SchemaLoader] Expected "components.schemas" to be a Map, got ${schemasValue.runtimeType}');
      }

      final schemas = <String, EntitySchema>{};

      // Parse each schema definition
      for (final entry in (schemasValue as Map).entries) {
        final schemaName = entry.key.toString();
        final schemaData = entry.value;
        
        if (schemaData is Map) {
          final schema = _parseOpenAPISchema(schemaName, schemaData, schemasValue as Map);
          if (schema != null) {
            schemas[schema.name] = schema;
          }
        }
      }

      debugPrint('[SchemaLoader] Successfully loaded ${schemas.length} schemas');
      return schemas;
    } catch (e, stackTrace) {
      if (e is FormatException && e.message.contains('[SchemaLoader]')) {
        rethrow;
      }
      final errorMsg = 'Failed to parse OpenAPI schema definition: $e';
      debugPrint('[SchemaLoader] ERROR: $errorMsg');
      debugPrint('[SchemaLoader] Stack trace: $stackTrace');
      throw FormatException('[SchemaLoader] $errorMsg');
    }
  }

  /// Parse a single OpenAPI schema definition
  EntitySchema? _parseOpenAPISchema(String schemaName, Map schemaData, Map allSchemas) {
    try {
      // Extract x-primary-key extension
      String? primaryKey;
      if (schemaData.containsKey('x-primary-key')) {
        primaryKey = schemaData['x-primary-key']?.toString();
      }

      // Extract properties
      if (!schemaData.containsKey('properties')) {
        debugPrint('[SchemaLoader] Warning: Schema "$schemaName" has no properties');
        return null;
      }

      final properties = schemaData['properties'];
      if (properties is! Map) {
        debugPrint('[SchemaLoader] Warning: Schema "$schemaName" properties is not a Map');
        return null;
      }

      // Extract required fields
      final requiredFields = <String>{};
      if (schemaData.containsKey('required')) {
        final required = schemaData['required'];
        if (required is List) {
          for (final field in required) {
            requiredFields.add(field.toString());
          }
        }
      }

      final fieldsMap = <String, SchemaField>{};
      final relationships = <String, String>{};
      final foreignKeys = <String, String>{};

      // Parse each property
      for (final entry in (properties as Map).entries) {
        final fieldName = entry.key.toString();
        final propertyData = entry.value;
        
        if (propertyData is Map) {
          final result = _parseProperty(
            fieldName,
            propertyData,
            requiredFields.contains(fieldName),
            allSchemas,
          );
          
          if (result.field != null) {
            fieldsMap[fieldName] = result.field!;
          }
          
          if (result.relationship != null) {
            relationships[fieldName] = result.relationship!;
          }
          
          if (result.foreignKey != null) {
            foreignKeys[fieldName] = result.foreignKey!;
          }
        }
      }

      return EntitySchema(
        name: schemaName,
        fields: fieldsMap,
        primaryKey: primaryKey,
        relationships: relationships,
        foreignKeys: foreignKeys,
      );
    } catch (e, stackTrace) {
      debugPrint('[SchemaLoader] ERROR: Failed to parse schema "$schemaName": $e');
      debugPrint('[SchemaLoader] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse a property definition from OpenAPI schema
  _PropertyParseResult _parseProperty(
    String fieldName,
    Map propertyData,
    bool required,
    Map allSchemas,
  ) {
    try {
      String? relationship;
      String? foreignKey;

      // Check for $ref reference (relationship)
      if (propertyData.containsKey('\$ref')) {
        final ref = propertyData['\$ref']?.toString();
        if (ref != null) {
          relationship = _resolveRef(ref);
        }
      }

      // Check for array with $ref in items (one-to-many relationship)
      if (propertyData.containsKey('type') && propertyData['type'] == 'array') {
        final items = propertyData['items'];
        if (items is Map && items.containsKey('\$ref')) {
          final ref = items['\$ref']?.toString();
          if (ref != null) {
            relationship = _resolveRef(ref);
          }
        }
      }

      // Check for x-foreign-key extension
      if (propertyData.containsKey('x-foreign-key')) {
        foreignKey = propertyData['x-foreign-key']?.toString();
      }

      // Determine field type
      String fieldType = 'text'; // Default
      dynamic defaultValue;
      final constraints = <String, dynamic>{};

      // If it's a relationship, we still need a base type for the field
      // For relationships, we'll use 'text' as the base type
      if (relationship == null) {
        // Parse type and format
        final type = propertyData['type']?.toString();
        final format = propertyData['format']?.toString();

        fieldType = _mapJsonSchemaType(type, format);

        // Extract constraints
        if (propertyData.containsKey('maxLength')) {
          constraints['maxLength'] = propertyData['maxLength'];
        }
        if (propertyData.containsKey('minimum')) {
          constraints['min'] = propertyData['minimum'];
        }
        if (propertyData.containsKey('maximum')) {
          constraints['max'] = propertyData['maximum'];
        }
        if (propertyData.containsKey('pattern')) {
          constraints['pattern'] = propertyData['pattern']?.toString();
        }

        // Extract default value
        if (propertyData.containsKey('default')) {
          defaultValue = propertyData['default'];
        }
      } else {
        // For relationships, use text type
        fieldType = 'text';
      }

      final field = SchemaField(
        name: fieldName,
        type: fieldType,
        required: required,
        defaultValue: defaultValue,
        constraints: constraints.isNotEmpty ? constraints : null,
      );

      return _PropertyParseResult(
        field: field,
        relationship: relationship,
        foreignKey: foreignKey,
      );
    } catch (e, stackTrace) {
      debugPrint('[SchemaLoader] ERROR: Failed to parse property "$fieldName": $e');
      debugPrint('[SchemaLoader] Stack trace: $stackTrace');
      return _PropertyParseResult();
    }
  }

  /// Resolve a $ref reference to an entity name
  /// Handles references like '#/components/schemas/EntityName'
  String? _resolveRef(String ref) {
    if (ref.startsWith('#/components/schemas/')) {
      return ref.substring('#/components/schemas/'.length);
    }
    // Handle other reference formats if needed
    debugPrint('[SchemaLoader] Warning: Unsupported $ref format: $ref');
    return null;
  }

  /// Map JSON Schema type and format to Vlinder field type
  String _mapJsonSchemaType(String? type, String? format) {
    if (type == null) {
      return 'text';
    }

    switch (type) {
      case 'string':
        if (format == 'date-time') {
          return 'date';
        }
        // email, uri, etc. are still text
        return 'text';
      
      case 'integer':
        return 'integer';
      
      case 'number':
        if (format == 'decimal') {
          return 'decimal';
        }
        return 'decimal'; // Default number to decimal
      
      case 'boolean':
        return 'boolean';
      
      case 'array':
        // Arrays are handled as relationships, but we need a base type
        return 'text';
      
      default:
        debugPrint('[SchemaLoader] Warning: Unknown JSON Schema type: $type');
        return 'text';
    }
  }
}
