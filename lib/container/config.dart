import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for container app
/// Server URL is stored persistently after QR code scan
class ContainerConfig {
  static const String _serverUrlKey = 'vlinder_server_url';

  /// Server URL for fetching .ht files
  /// Returns null if no URL has been configured (user needs to scan QR code)
  static Future<String?> get serverUrl async {
    // Try environment variable first (for development/testing)
    const envUrl = String.fromEnvironment('VLINDER_SERVER_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Try persistent storage (from QR code scan)
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString(_serverUrlKey);
      if (storedUrl != null && storedUrl.isNotEmpty) {
        return storedUrl;
      }
    } catch (e) {
      // Ignore storage errors
    }

    // No URL configured - user needs to scan QR code
    return null;
  }

  /// Save server URL to persistent storage
  static Future<void> saveServerUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverUrlKey, url);
    } catch (e) {
      // Ignore storage errors
    }
  }

  /// Asset file names to fetch
  static const List<String> assetFiles = [
    'ui.ht',
    'schema.ht',
    'workflows.ht',
    'rules.ht',
  ];

  /// Cache directory name
  static const String cacheDirName = 'vlinder_cache';

  /// Debug log server URL
  /// Set via VLINDER_LOG_SERVER_URL environment variable at build time
  static String? get debugLogServerUrl {
    const envUrl = String.fromEnvironment('VLINDER_LOG_SERVER_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return null; // Logging disabled by default
  }

  /// Clear stored server URL (for testing/reset)
  static Future<void> clearServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_serverUrlKey);
    } catch (e) {
      // Ignore storage errors
    }
  }
}

