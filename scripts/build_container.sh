#!/bin/bash
# Build container app
# Note: Server URL is no longer baked in - users scan QR code on first launch

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

# Determine target platform
TARGET="${1:-android}" # Default to android

if [ "$TARGET" != "android" ] && [ "$TARGET" != "ios" ]; then
    echo -e "${RED}Error: Invalid target platform: $TARGET${NC}"
    echo "Supported platforms: android, ios"
    exit 1
fi

echo -e "${GREEN}Target platform: $TARGET${NC}"
echo -e "${YELLOW}Note: Server URL will be configured via QR code scan on first launch${NC}"

# Build Flutter app
cd "$PROJECT_ROOT"

echo -e "${GREEN}Building Flutter app...${NC}"

if [ "$TARGET" == "android" ]; then
    flutter build apk
    echo -e "${GREEN}Build complete! APK: build/app/outputs/flutter-apk/app-release.apk${NC}"
elif [ "$TARGET" == "ios" ]; then
    flutter build ios
    echo -e "${GREEN}Build complete! iOS app in: build/ios${NC}"
fi

echo -e "${GREEN}Done!${NC}"
echo ""
echo "To deploy:"
echo "  1. Start server: ./scripts/start_dev_server.sh"
echo "  2. Install app on device"
echo "  3. Scan QR code shown in terminal window"


