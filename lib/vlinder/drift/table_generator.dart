import 'package:drift/drift.dart';
import '../binding/drift_binding.dart';

/// Generator for creating Drift table definitions from EntitySchema
class TableGenerator {
  /// Generate a Drift table from an EntitySchema
  TableInfo generateTable(EntitySchema schema) {
    // Create table columns based on schema fields
    final columns = <GeneratedColumn>[];

    for (final field in schema.fields.values) {
      final column = _generateColumn(field);
      if (column != null) {
        columns.add(column);
      }
    }

    // Create table class
    // Note: This is a simplified approach. In practice, you'd use code generation
    // For now, we'll create a dynamic table structure
    return _createDynamicTable(schema, columns);
  }

  /// Generate a column from a SchemaField
  /// Note: This method is not fully implemented as Drift requires compile-time table definitions
  GeneratedColumn? _generateColumn(SchemaField field) {
    // Drift column classes are abstract and cannot be instantiated at runtime
    // This method is a placeholder - actual implementation requires code generation
    throw UnimplementedError(
      'Column generation not fully implemented. '
      'Drift requires compile-time table definitions. '
      'Use RuntimeTableHelper.generateTableCode() for code generation.',
    );
  }

  /// Get max length constraint from field
  int? _getMaxLength(SchemaField field) {
    return field.constraints?['maxLength'] as int?;
  }

  /// Create a dynamic table (simplified - in production use code generation)
  TableInfo _createDynamicTable(EntitySchema schema, List<GeneratedColumn> columns) {
    // This is a placeholder - actual Drift tables need to be generated at compile time
    // For runtime generation, we'd need a different approach
    throw UnimplementedError(
      'Dynamic table generation not fully implemented. '
      'Use code generation or pre-defined tables.',
    );
  }
}

/// Helper class for runtime table creation
/// Note: Drift requires compile-time table definitions, so this is a workaround
class RuntimeTableHelper {
  /// Create table definition string for code generation
  static String generateTableCode(EntitySchema schema) {
    final buffer = StringBuffer();
    buffer.writeln('class ${schema.name}Table extends Table {');
    buffer.writeln('  @override');
    buffer.writeln('  String get tableName => \'${schema.name.toLowerCase()}\';');
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln('  Set<Column> get primaryKey => {');

    if (schema.primaryKey != null) {
      buffer.writeln('    ${schema.primaryKey!.toLowerCase()},');
    } else {
      // Default to 'id' if exists
      if (schema.fields.containsKey('id')) {
        buffer.writeln('    id,');
      }
    }

    buffer.writeln('  };');
    buffer.writeln('');

    // Generate columns
    for (final field in schema.fields.values) {
      buffer.writeln(_generateColumnCode(field));
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  /// Generate column code
  static String _generateColumnCode(SchemaField field) {
    final nullable = field.required ? '' : '?';
    final columnType = _getColumnType(field.type);
    return '  $columnType get ${field.name} => $columnType()${nullable};';
  }

  /// Get Drift column type string
  static String _getColumnType(String fieldType) {
    switch (fieldType) {
      case 'text':
      case 'string':
        return 'TextColumn';
      case 'integer':
      case 'int':
        return 'IntColumn';
      case 'number':
      case 'decimal':
      case 'float':
      case 'double':
        return 'RealColumn';
      case 'boolean':
      case 'bool':
        return 'BoolColumn';
      case 'date':
      case 'datetime':
        return 'DateTimeColumn';
      default:
        return 'TextColumn';
    }
  }
}

