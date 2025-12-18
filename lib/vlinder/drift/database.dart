import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../binding/drift_binding.dart';

/// Vlinder database - SQLite database managed by Drift
/// Tables are generated from schemas at runtime using raw SQL
class VlinderDatabase {
  final LazyDatabase _db;
  dynamic _cachedDb;
  Database? _sqliteDb;
  File? _dbFile;

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

  /// Get the underlying database instance
  Future<dynamic> _getDatabase() async {
    if (_cachedDb == null) {
      debugPrint('[VlinderDatabase] Creating new database instance');
      final dbFolder = await getApplicationDocumentsDirectory();
      _dbFile = File(p.join(dbFolder.path, 'vlinder.db'));
      debugPrint('[VlinderDatabase] Database file: ${_dbFile!.path}');
      _cachedDb = NativeDatabase(_dbFile!);
    }
    return _cachedDb!;
  }

  /// Get sqlite3 database instance for custom SQL execution
  Future<Database> _getSqliteDatabase() async {
    if (_sqliteDb == null) {
      debugPrint('[VlinderDatabase] Opening sqlite3 database');
      if (_dbFile == null) {
        final dbFolder = await getApplicationDocumentsDirectory();
        _dbFile = File(p.join(dbFolder.path, 'vlinder.db'));
      }
      _sqliteDb = sqlite3.open(_dbFile!.path);
      debugPrint('[VlinderDatabase] Sqlite3 database opened');
    }
    return _sqliteDb!;
  }

  /// Get database connection (for Drift operations)
  /// Note: Custom SQL execution uses sqlite3 directly
  Future<DatabaseConnection> get connection async {
    debugPrint('[VlinderDatabase] Getting database connection');
    // For now, we use sqlite3 directly for custom SQL
    // This getter is kept for compatibility but may not be fully functional
    // If needed, we can implement it using LazyDatabase's connection mechanism
    throw UnimplementedError(
      'Connection getter not fully implemented. '
      'Use customStatement() for SQL execution instead.',
    );
  }

  /// Execute custom SQL statement
  Future<void> customStatement(String sql, [List<dynamic>? params]) async {
    try {
      // Use sqlite3 directly for custom SQL execution
      final db = await _getSqliteDatabase();
      if (params != null && params.isNotEmpty) {
        final stmt = db.prepare(sql);
        try {
          final boundParams = _convertParameters(params);
          stmt.execute(boundParams);
        } finally {
          stmt.dispose();
        }
      } else {
        db.execute(sql);
      }
    } catch (e) {
      debugPrint('[VlinderDatabase] Error executing SQL: $e');
      debugPrint('[VlinderDatabase] Error type: ${e.runtimeType}');
      debugPrint('[VlinderDatabase] SQL was: $sql');
      if (params != null) {
        debugPrint('[VlinderDatabase] Parameters: $params');
      }
      rethrow;
    }
  }

  /// Execute a SELECT query and return results
  /// Returns a list of maps, where each map represents a row
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    try {
      final db = await _getSqliteDatabase();
      final stmt = db.prepare(sql);
      try {
        final boundParams = params != null && params.isNotEmpty 
            ? _convertParameters(params)
            : [];
        
        final resultSet = stmt.select(boundParams);
        
        // Get column names from the first row if available, or parse SQL
        final columnNames = _extractColumnNames(sql, resultSet);
        
        final results = <Map<String, dynamic>>[];
        for (final row in resultSet) {
          final rowMap = <String, dynamic>{};
          for (var i = 0; i < row.length && i < columnNames.length; i++) {
            rowMap[columnNames[i]] = row[i];
          }
          results.add(rowMap);
        }
        
        return results;
      } finally {
        stmt.dispose();
      }
    } catch (e) {
      debugPrint('[VlinderDatabase] Error executing query: $e');
      debugPrint('[VlinderDatabase] Error type: ${e.runtimeType}');
      debugPrint('[VlinderDatabase] SQL was: $sql');
      if (params != null) {
        debugPrint('[VlinderDatabase] Parameters: $params');
      }
      rethrow;
    }
  }

  /// Extract column names from SQL query or result set
  /// Falls back to generic column names if extraction fails
  List<String> _extractColumnNames(String sql, Iterable<Row> resultSet) {
    // Try to parse column names from SQL SELECT statement
    final sqlUpper = sql.trim().toUpperCase();
    if (!sqlUpper.startsWith('SELECT')) {
      // Not a SELECT query, return empty
      return [];
    }
    
    // Extract the column list from SELECT ... FROM
    final selectMatch = RegExp(r'SELECT\s+(.+?)\s+FROM', caseSensitive: false).firstMatch(sql);
    if (selectMatch != null) {
      final columnList = selectMatch.group(1)?.trim() ?? '';
      
      // If it's SELECT *, we need to get column names from the table
      if (columnList == '*') {
        // For SELECT *, try to get column names from the first row
        // SQLite rows don't expose column names directly, so we'll use generic names
        // In practice, this should be handled by the caller specifying explicit columns
        final firstRow = resultSet.isNotEmpty ? resultSet.first : null;
        if (firstRow != null) {
          final columnNames = <String>[];
          for (var i = 0; i < firstRow.length; i++) {
            columnNames.add('column$i');
          }
          return columnNames;
        }
        return [];
      } else {
        // Parse explicit column names
        final columns = columnList.split(',').map((c) {
          // Remove aliases (AS clause) and trim
          final trimmed = c.trim();
          // Split on whitespace to get the first part (before AS or alias)
          final parts = trimmed.split(RegExp(r'\s+'));
          final cleaned = parts.first;
          // Remove table prefix if present (table.column)
          return cleaned.split('.').last;
        }).toList();
        return columns;
      }
    }
    
    // Fallback: use generic column names based on row length
    final firstRow = resultSet.isNotEmpty ? resultSet.first : null;
    if (firstRow != null) {
      final columnNames = <String>[];
      for (var i = 0; i < firstRow.length; i++) {
        columnNames.add('column$i');
      }
      return columnNames;
    }
    
    return [];
  }

  /// Convert parameters to sqlite3-compatible types
  List<Object?> _convertParameters(List<dynamic> params) {
    return params.map((param) {
      if (param == null) {
        return null;
      } else if (param is int) {
        return param;
      } else if (param is double) {
        return param;
      } else if (param is String) {
        return param;
      } else if (param is bool) {
        return param ? 1 : 0;
      } else {
        return param.toString();
      }
    }).toList();
  }

  /// Create table from schema using raw SQL
  Future<void> createTableFromSchema(EntitySchema schema) async {
    debugPrint('[VlinderDatabase] Creating table from schema: ${schema.name}');
    
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
    
    final sql = buffer.toString();
    
    await customStatement(sql);
    debugPrint('[VlinderDatabase] Table ${schema.name} created successfully');
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


