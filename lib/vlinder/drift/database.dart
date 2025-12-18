import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../binding/drift_binding.dart';
import 'table_generator.dart';

/// Vlinder database - SQLite database managed by Drift
/// Tables are generated from schemas at runtime using raw SQL
class VlinderDatabase {
  final LazyDatabase _db;

  VlinderDatabase() : _db = _openConnection();

  /// Initialize database with schemas
  /// In a full implementation, this would create tables dynamically
  /// For now, we use a simplified approach
  Future<void> initializeWithSchemas(Map<String, EntitySchema> schemas) async {
    // Note: Drift requires compile-time table definitions
    // For runtime schema-to-table conversion, we'd need:
    // 1. Code generation from schemas, or
    // 2. Raw SQL execution, or
    // 3. A different ORM that supports runtime table creation
    
    // This is a placeholder for the actual implementation
    debugPrint('Initializing database with ${schemas.length} schemas');
    
    // In production, you would:
    // 1. Generate table classes from schemas
    // 2. Use build_runner to generate Drift code
    // 3. Or use raw SQL to create tables
  }

  /// Get database connection
  DatabaseConnection get connection => _db.connection;

  /// Execute custom SQL statement
  Future<void> customStatement(String sql) async {
    final executor = _db.connection.executor;
    await executor.runCustom(sql);
  }

  /// Create table from schema using raw SQL
  Future<void> createTableFromSchema(EntitySchema schema) async {
    final buffer = StringBuffer();
    buffer.write('CREATE TABLE IF NOT EXISTS ${schema.name.toLowerCase()} (');
    
    final columns = <String>[];
    
    for (final field in schema.fields.values) {
      final sqlType = _getSQLType(field.type);
      final nullable = field.required ? 'NOT NULL' : 'NULL';
      final defaultValue = field.defaultValue != null 
          ? 'DEFAULT ${_formatDefaultValue(field.defaultValue)}'
          : '';
      
      columns.add('${field.name} $sqlType $nullable $defaultValue');
    }
    
    buffer.write(columns.join(', '));
    
    if (schema.primaryKey != null) {
      buffer.write(', PRIMARY KEY (${schema.primaryKey})');
    }
    
    buffer.write(')');
    
    await customStatement(buffer.toString());
  }

  /// Get SQL type from schema field type
  String _getSQLType(String fieldType) {
    switch (fieldType) {
      case 'text':
      case 'string':
        return 'TEXT';
      case 'integer':
      case 'int':
        return 'INTEGER';
      case 'number':
      case 'decimal':
      case 'float':
      case 'double':
        return 'REAL';
      case 'boolean':
      case 'bool':
        return 'INTEGER'; // SQLite uses INTEGER for booleans (0/1)
      case 'date':
      case 'datetime':
        return 'INTEGER'; // SQLite stores dates as Unix timestamps
      default:
        return 'TEXT';
    }
  }

  /// Format default value for SQL
  String _formatDefaultValue(dynamic value) {
    if (value is String) {
      return "'$value'";
    } else if (value is num) {
      return value.toString();
    } else if (value is bool) {
      return value ? '1' : '0';
    }
    return 'NULL';
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vlinder.db'));
    return NativeDatabase(file);
  });
}

