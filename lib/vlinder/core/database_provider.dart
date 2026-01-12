import 'package:flutter/material.dart';
import '../drift/database_api.dart';

/// Provider for accessing DatabaseAPI instance
class DatabaseAPIProvider extends InheritedWidget {
  final DatabaseAPI databaseAPI;

  const DatabaseAPIProvider({
    super.key,
    required this.databaseAPI,
    required super.child,
  });

  static DatabaseAPI? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DatabaseAPIProvider>()?.databaseAPI;
  }

  @override
  bool updateShouldNotify(DatabaseAPIProvider oldWidget) {
    return databaseAPI != oldWidget.databaseAPI;
  }
}




