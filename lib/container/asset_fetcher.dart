import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'config.dart';

/// Fetcher for downloading .ht files from server
class AssetFetcher {
  final String? serverUrl;

  AssetFetcher({String? serverUrl}) : serverUrl = serverUrl?.trim();

  /// Fetch all asset files
  /// Always fetches fresh from server - caching is disabled
  Future<Map<String, String>> fetchAllAssets({bool forceRefresh = false}) async {
    final assets = <String, String>{};

    // Server URL is required - no cache fallback
    if (serverUrl == null || serverUrl!.isEmpty) {
      throw Exception('No server URL configured - cannot fetch assets');
    }

    // Always fetch fresh from server - no caching
    for (final fileName in ContainerConfig.assetFiles) {
      final content = await fetchAsset(fileName, forceRefresh: true);
      assets[fileName] = content;
    }

    return assets;
  }

  /// Fetch a single asset file
  /// Always fetches fresh from server - caching is disabled
  Future<String> fetchAsset(String fileName, {bool forceRefresh = false}) async {
    if (serverUrl == null || serverUrl!.isEmpty) {
      throw Exception('No server URL configured - cannot fetch $fileName');
    }

    // Trim serverUrl to handle any whitespace issues
    final trimmedServerUrl = serverUrl!.trim();
    final url = '$trimmedServerUrl/$fileName';
    debugPrint('[AssetFetcher] Fetching $fileName from $url (cache disabled - always fresh)');
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final content = response.body;
      debugPrint('[AssetFetcher] Successfully fetched $fileName (${content.length} characters)');
      // Do NOT cache - always fetch fresh
      return content;
    } else {
      debugPrint('[AssetFetcher] HTTP ${response.statusCode} error fetching $fileName: ${response.reasonPhrase}');
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  /// Save asset to cache
  Future<void> saveToCache(String fileName, String content) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File(p.join(cacheDir.path, fileName));
      await file.writeAsString(content);
    } catch (e) {
      // Ignore cache errors - fetching is more important
    }
  }

  /// Load asset from cache
  Future<String?> loadFromCache(String fileName) async {
    try {
      final cacheDir = await getCacheDirectory();
      final file = File(p.join(cacheDir.path, fileName));
      
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      // Ignore cache errors
    }
    return null;
  }

  /// Get cache directory
  Future<Directory> getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(appDir.path, ContainerConfig.cacheDirName));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Check if assets are cached
  Future<bool> hasCachedAssets() async {
    try {
      final cacheDir = await getCacheDirectory();
      for (final fileName in ContainerConfig.assetFiles) {
        final file = File(p.join(cacheDir.path, fileName));
        if (!await file.exists()) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}


