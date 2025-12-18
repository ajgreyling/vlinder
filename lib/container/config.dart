import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Configuration for container app
/// Server URL is stored persistently after QR code scan
class ContainerConfig {
  static const String _serverUrlKey = 'vlinder_server_url';
  static const String _appVersionKey = 'vlinder_app_version';

  /// Server URL for fetching .ht files
  /// Returns null if no URL has been configured (user needs to scan QR code)
  static Future<String?> get serverUrl async {
    // Try environment variable first (for development/testing)
    const envUrl = String.fromEnvironment('VLINDER_SERVER_URL');
    if (envUrl.isNotEmpty) {
      return envUrl.trim();
    }

    // Try persistent storage (from QR code scan)
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString(_serverUrlKey);
      if (storedUrl != null && storedUrl.isNotEmpty) {
        return storedUrl.trim();
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
      // Trim whitespace and newlines before saving
      await prefs.setString(_serverUrlKey, url.trim());
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
    'actions.ht',
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

  /// Check if app version has changed and clear stored data if it has
  /// This ensures users scan a fresh QR code when a new app version is deployed
  static Future<void> checkAndClearOnVersionChange() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getString(_appVersionKey);
      
      if (storedVersion == null || storedVersion != currentVersion) {
        debugPrint('[ContainerConfig] App version changed: $storedVersion -> $currentVersion');
        debugPrint('[ContainerConfig] Clearing stored server URL and cache...');
        
        // Clear server URL
        await clearServerUrl();
        
        // Clear asset cache
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final cacheDir = Directory(p.join(appDir.path, cacheDirName));
          if (await cacheDir.exists()) {
            await cacheDir.delete(recursive: true);
            debugPrint('[ContainerConfig] Cleared asset cache directory');
          }
        } catch (e) {
          debugPrint('[ContainerConfig] Error clearing cache: $e');
          // Continue even if cache clearing fails
        }
        
        // Update stored version
        await prefs.setString(_appVersionKey, currentVersion);
        
        debugPrint('[ContainerConfig] Cleared stored data for new app version');
      } else {
        debugPrint('[ContainerConfig] App version unchanged: $currentVersion');
      }
    } catch (e) {
      debugPrint('[ContainerConfig] Error checking app version: $e');
      // Don't fail app startup if version check fails
    }
  }
}

