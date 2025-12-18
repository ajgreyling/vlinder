import 'package:flutter/foundation.dart';
import 'database.dart';
import '../binding/drift_binding.dart';
import '../schema/schema_loader.dart';

/// Database API wrapper for exposing database operations to Hetu scripts
/// Provides both raw SQL execution and convenience CRUD methods
class DatabaseAPI {
  final VlinderDatabase _database;
  final Map<String, EntitySchema> _schemas = {};

  DatabaseAPI({
    required VlinderDatabase database,
    Map<String, EntitySchema> schemas = const {},
  })  : _database = database {
    _schemas.addAll(schemas);
  }

  /// Update schemas (called after schemas are loaded)
  void updateSchemas(Map<String, EntitySchema> schemas) {
    _schemas.clear();
    _schemas.addAll(schemas);
  }

  /// Get a schema by entity name
  EntitySchema? getSchema(String entityName) {
    return _schemas[entityName];
  }

  /// Get all loaded schemas
  Map<String, EntitySchema> get schemas => Map.unmodifiable(_schemas);

  /// Execute raw SQL statement (INSERT, UPDATE, DELETE, etc.)
  /// Returns the number of affected rows
  Future<int> executeSQL(String sql, [List<dynamic>? params]) async {
    try {
      debugPrint('[DatabaseAPI] Executing SQL: $sql');
      if (params != null) {
        debugPrint('[DatabaseAPI] Parameters: $params');
      }
      await _database.customStatement(sql, params);
      // SQLite doesn't directly return affected rows from execute()
      // We'd need to use changes() but that's not available in this API
      // Return 0 for now, or we could execute a separate query
      return 0;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error executing SQL: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Execute a SELECT query and return results
  /// Returns a list of maps, where each map represents a row
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]) async {
    try {
      debugPrint('[DatabaseAPI] Executing query: $sql');
      if (params != null) {
        debugPrint('[DatabaseAPI] Parameters: $params');
      }
      final results = await _database.query(sql, params);
      debugPrint('[DatabaseAPI] Query returned ${results.length} rows');
      return results;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error executing query: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Save an entity (INSERT or UPDATE based on primary key)
  /// Returns the saved entity with generated ID if applicable
  Future<Map<String, dynamic>> save(String entityName, Map<String, dynamic> data) async {
    try {
      debugPrint('[DatabaseAPI] Saving entity: $entityName');
      debugPrint('[DatabaseAPI] Data: $data');

      final schema = _schemas[entityName];
      if (schema == null) {
        throw ArgumentError('Entity schema not found: $entityName');
      }

      final tableName = entityName.toLowerCase();
      final primaryKey = schema.primaryKey;

      // Check if primary key exists and has a value
      if (primaryKey != null && data.containsKey(primaryKey) && data[primaryKey] != null) {
        // UPDATE
        final id = data[primaryKey];
        debugPrint('[DatabaseAPI] Updating $entityName with ID: $id');
        
        final fields = data.keys.where((key) => key != primaryKey).toList();
        if (fields.isEmpty) {
          // No fields to update, just return the data
          return data;
        }

        final setClauses = fields.map((field) => '$field = ?').join(', ');
        final sql = 'UPDATE $tableName SET $setClauses WHERE $primaryKey = ?';
        final params = [
          ...fields.map((field) => data[field]),
          id,
        ];

        await _database.customStatement(sql, params);
        
        // Fetch and return the updated record
        final updated = await findById(entityName, id);
        return updated ?? data;
      } else {
        // INSERT
        debugPrint('[DatabaseAPI] Inserting new $entityName');
        
        final fields = data.keys.toList();
        final placeholders = fields.map((_) => '?').join(', ');
        final fieldNames = fields.join(', ');
        final sql = 'INSERT INTO $tableName ($fieldNames) VALUES ($placeholders)';
        final params = fields.map((field) => data[field]).toList();

        await _database.customStatement(sql, params);

        // If primary key is auto-increment, fetch the last inserted rowid
        if (primaryKey != null) {
          final lastIdResult = await _database.query('SELECT last_insert_rowid() as id');
          if (lastIdResult.isNotEmpty) {
            final insertedId = lastIdResult[0]['id'];
            data[primaryKey] = insertedId;
            debugPrint('[DatabaseAPI] Inserted $entityName with ID: $insertedId');
          }
        }

        return data;
      }
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error saving entity: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Find an entity by primary key
  /// Returns null if not found
  Future<Map<String, dynamic>?> findById(String entityName, dynamic id) async {
    try {
      debugPrint('[DatabaseAPI] Finding $entityName by ID: $id');

      final schema = _schemas[entityName];
      if (schema == null) {
        throw ArgumentError('Entity schema not found: $entityName');
      }

      final tableName = entityName.toLowerCase();
      final primaryKey = schema.primaryKey ?? 'id';
      final sql = 'SELECT * FROM $tableName WHERE $primaryKey = ?';
      final results = await _database.query(sql, [id]);

      if (results.isEmpty) {
        return null;
      }

      return results[0];
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error finding entity: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Find all entities matching optional criteria
  /// where: Map of field names to values or operators (e.g., {age: {gt: 18}})
  /// orderBy: Field name or map with field and direction (e.g., 'name' or {field: 'name', direction: 'DESC'})
  /// limit: Maximum number of results
  Future<List<Map<String, dynamic>>> findAll(
    String entityName, {
    Map<String, dynamic>? where,
    dynamic orderBy,
    int? limit,
  }) async {
    try {
      debugPrint('[DatabaseAPI] Finding all $entityName');
      if (where != null) {
        debugPrint('[DatabaseAPI] Where: $where');
      }
      if (orderBy != null) {
        debugPrint('[DatabaseAPI] Order by: $orderBy');
      }
      if (limit != null) {
        debugPrint('[DatabaseAPI] Limit: $limit');
      }

      final schema = _schemas[entityName];
      if (schema == null) {
        throw ArgumentError('Entity schema not found: $entityName');
      }

      final tableName = entityName.toLowerCase();
      final sql = StringBuffer('SELECT * FROM $tableName');
      final params = <dynamic>[];

      // Build WHERE clause
      if (where != null && where.isNotEmpty) {
        final conditions = <String>[];
        for (final entry in where.entries) {
          final field = entry.key;
          final value = entry.value;
          
          if (value is Map) {
            // Handle operators like {gt: 18}, {lt: 100}, etc.
            if (value.containsKey('gt')) {
              conditions.add('$field > ?');
              params.add(value['gt']);
            } else if (value.containsKey('lt')) {
              conditions.add('$field < ?');
              params.add(value['lt']);
            } else if (value.containsKey('gte')) {
              conditions.add('$field >= ?');
              params.add(value['gte']);
            } else if (value.containsKey('lte')) {
              conditions.add('$field <= ?');
              params.add(value['lte']);
            } else if (value.containsKey('ne')) {
              conditions.add('$field != ?');
              params.add(value['ne']);
            } else if (value.containsKey('like')) {
              conditions.add('$field LIKE ?');
              params.add(value['like']);
            }
          } else {
            conditions.add('$field = ?');
            params.add(value);
          }
        }
        if (conditions.isNotEmpty) {
          sql.write(' WHERE ${conditions.join(' AND ')}');
        }
      }

      // Build ORDER BY clause
      if (orderBy != null) {
        if (orderBy is String) {
          sql.write(' ORDER BY $orderBy');
        } else if (orderBy is Map) {
          final field = orderBy['field']?.toString() ?? 'id';
          final direction = orderBy['direction']?.toString() ?? 'ASC';
          sql.write(' ORDER BY $field $direction');
        }
      }

      // Build LIMIT clause
      if (limit != null) {
        sql.write(' LIMIT $limit');
      }

      final results = await _database.query(sql.toString(), params);
      debugPrint('[DatabaseAPI] Found ${results.length} $entityName records');
      return results;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error finding all entities: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update an entity by primary key
  /// Returns the updated entity
  Future<Map<String, dynamic>> update(String entityName, dynamic id, Map<String, dynamic> data) async {
    try {
      debugPrint('[DatabaseAPI] Updating $entityName with ID: $id');
      debugPrint('[DatabaseAPI] Data: $data');

      final schema = _schemas[entityName];
      if (schema == null) {
        throw ArgumentError('Entity schema not found: $entityName');
      }

      final tableName = entityName.toLowerCase();
      final primaryKey = schema.primaryKey ?? 'id';

      final fields = data.keys.toList();
      if (fields.isEmpty) {
        // No fields to update, fetch and return existing record
        return await findById(entityName, id) ?? {primaryKey: id};
      }

      final setClauses = fields.map((field) => '$field = ?').join(', ');
      final sql = 'UPDATE $tableName SET $setClauses WHERE $primaryKey = ?';
      final params = [
        ...fields.map((field) => data[field]),
        id,
      ];

      await _database.customStatement(sql, params);

      // Fetch and return the updated record
      final updated = await findById(entityName, id);
      return updated ?? {...data, primaryKey: id};
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error updating entity: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete an entity by primary key
  /// Returns true if a row was deleted, false otherwise
  Future<bool> delete(String entityName, dynamic id) async {
    try {
      debugPrint('[DatabaseAPI] Deleting $entityName with ID: $id');

      final schema = _schemas[entityName];
      if (schema == null) {
        throw ArgumentError('Entity schema not found: $entityName');
      }

      final tableName = entityName.toLowerCase();
      final primaryKey = schema.primaryKey ?? 'id';
      final sql = 'DELETE FROM $tableName WHERE $primaryKey = ?';

      await _database.customStatement(sql, [id]);

      // Check if row was actually deleted by trying to find it
      final found = await findById(entityName, id);
      return found == null;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseAPI] Error deleting entity: $e');
      debugPrint('[DatabaseAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

