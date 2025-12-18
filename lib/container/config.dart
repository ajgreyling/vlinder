/// Configuration for container app
/// Server URL is injected at build time
class ContainerConfig {
  /// Server URL for fetching .ht files
  /// This is set at build time via environment variable or build args
  static String get serverUrl {
    // Try environment variable first
    const envUrl = String.fromEnvironment('VLINDER_SERVER_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Fallback to default (for development)
    // In production, this should be set via build configuration
    return 'http://localhost:8000';
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
}

