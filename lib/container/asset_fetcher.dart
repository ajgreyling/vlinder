import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'config.dart';

/// Fetcher for downloading .ht files from server
class AssetFetcher {
  final String? serverUrl;

  AssetFetcher({String? serverUrl}) : serverUrl = serverUrl;

  /// Fetch all asset files
  Future<Map<String, String>> fetchAllAssets() async {
    final assets = <String, String>{};

    // If no server URL, only use cache
    if (serverUrl == null || serverUrl!.isEmpty) {
      debugPrint('[AssetFetcher] No server URL configured, loading from cache only');
      for (final fileName in ContainerConfig.assetFiles) {
        final cached = await loadFromCache(fileName);
        if (cached != null) {
          assets[fileName] = cached;
        } else {
          throw Exception('No server URL configured and no cached $fileName found');
        }
      }
      return assets;
    }

    for (final fileName in ContainerConfig.assetFiles) {
      try {
        final content = await fetchAsset(fileName);
        assets[fileName] = content;
      } catch (e) {
        // Try to load from cache if fetch fails
        final cached = await loadFromCache(fileName);
        if (cached != null) {
          assets[fileName] = cached;
        } else {
          throw Exception('Failed to fetch $fileName: $e');
        }
      }
    }

    return assets;
  }

  /// Fetch a single asset file
  Future<String> fetchAsset(String fileName) async {
    if (serverUrl == null || serverUrl!.isEmpty) {
      // No server URL, try cache only
      final cached = await loadFromCache(fileName);
      if (cached != null) {
        return cached;
      }
      throw Exception('No server URL configured and no cached $fileName found');
    }

    final url = '$serverUrl/$fileName';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final content = response.body;
        
        // Cache the content
        await saveToCache(fileName, content);
        
        return content;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      // Try cache as fallback
      final cached = await loadFromCache(fileName);
      if (cached != null) {
        return cached;
      }
      rethrow;
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


