#!/bin/bash
# Build container app with ngrok URL injected

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Vlinder Container App${NC}"
echo "===================================="

# Get ngrok URL
NGROK_URL=""

# Try to get from file first
if [ -f /tmp/vlinder_ngrok_url.txt ]; then
    NGROK_URL=$(cat /tmp/vlinder_ngrok_url.txt)
fi

# Try environment variable
if [ -z "$NGROK_URL" ] && [ -n "$NGROK_URL_ENV" ]; then
    NGROK_URL="$NGROK_URL_ENV"
fi

# Try command line argument
if [ -z "$NGROK_URL" ] && [ -n "$1" ]; then
    NGROK_URL="$1"
fi

# Prompt if still not set
if [ -z "$NGROK_URL" ]; then
    echo -e "${YELLOW}Ngrok URL not found${NC}"
    echo "Usage: $0 <ngrok_url>"
    echo "Or set NGROK_URL environment variable"
    echo "Or run ./scripts/start_dev_server.sh first"
    exit 1
fi

echo -e "${GREEN}Using server URL: $NGROK_URL${NC}"

# Determine target platform
TARGET="${2:-android}" # Default to android

if [ "$TARGET" != "android" ] && [ "$TARGET" != "ios" ]; then
    echo -e "${RED}Error: Invalid target platform: $TARGET${NC}"
    echo "Supported platforms: android, ios"
    exit 1
fi

echo -e "${GREEN}Target platform: $TARGET${NC}"

# Create config file with server URL
CONFIG_FILE="$PROJECT_ROOT/lib/container/config.dart"
CONFIG_BACKUP="$CONFIG_FILE.backup"

# Backup original config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_BACKUP"
fi

# Create config with injected URL
cat > "$CONFIG_FILE" << EOF
/// Configuration for container app
/// Server URL is injected at build time
class ContainerConfig {
  /// Server URL for fetching .ht files
  /// This is set at build time via environment variable or build args
  static String get serverUrl {
    // Build-time injected URL
    const envUrl = String.fromEnvironment('VLINDER_SERVER_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Fallback to configured URL
    return '$NGROK_URL';
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
}
EOF

echo -e "${GREEN}Configuration updated${NC}"

# Build Flutter app
cd "$PROJECT_ROOT"

echo -e "${GREEN}Building Flutter app...${NC}"

if [ "$TARGET" == "android" ]; then
    flutter build apk --dart-define=VLINDER_SERVER_URL="$NGROK_URL"
    echo -e "${GREEN}Build complete! APK: build/app/outputs/flutter-apk/app-release.apk${NC}"
elif [ "$TARGET" == "ios" ]; then
    flutter build ios --dart-define=VLINDER_SERVER_URL="$NGROK_URL"
    echo -e "${GREEN}Build complete! iOS app in: build/ios${NC}"
fi

# Restore original config if backup exists
if [ -f "$CONFIG_BACKUP" ]; then
    mv "$CONFIG_BACKUP" "$CONFIG_FILE"
    echo -e "${GREEN}Configuration restored${NC}"
fi

echo -e "${GREEN}Done!${NC}"

