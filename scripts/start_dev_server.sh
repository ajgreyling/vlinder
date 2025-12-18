#!/bin/bash
# Start development server with ngrok tunnel and optional Flutter device deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$PROJECT_ROOT/server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Vlinder Development Server${NC}"
echo "=================================="

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    exit 1
fi

# Check if ngrok is available
if ! command -v ngrok &> /dev/null; then
    echo -e "${YELLOW}Warning: ngrok not found${NC}"
    echo "Install ngrok from https://ngrok.com/download"
    echo "Or set NGROK_URL environment variable to skip ngrok"
    exit 1
fi

# Cleanup existing processes
echo -e "${YELLOW}Checking for existing processes...${NC}"

# Kill existing Python servers if running
if [ -f /tmp/vlinder_server.pid ]; then
    OLD_SERVER_PID=$(cat /tmp/vlinder_server.pid 2>/dev/null)
    if [ -n "$OLD_SERVER_PID" ] && kill -0 $OLD_SERVER_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping existing Python server (PID: $OLD_SERVER_PID)${NC}"
        kill $OLD_SERVER_PID 2>/dev/null || true
        sleep 1
    fi
fi

if [ -f /tmp/vlinder_asset_server.pid ]; then
    OLD_ASSET_SERVER_PID=$(cat /tmp/vlinder_asset_server.pid 2>/dev/null)
    if [ -n "$OLD_ASSET_SERVER_PID" ] && kill -0 $OLD_ASSET_SERVER_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping existing asset server (PID: $OLD_ASSET_SERVER_PID)${NC}"
        kill $OLD_ASSET_SERVER_PID 2>/dev/null || true
        sleep 1
    fi
fi

if [ -f /tmp/vlinder_proxy.pid ]; then
    OLD_PROXY_PID=$(cat /tmp/vlinder_proxy.pid 2>/dev/null)
    if [ -n "$OLD_PROXY_PID" ] && kill -0 $OLD_PROXY_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping existing reverse proxy (PID: $OLD_PROXY_PID)${NC}"
        kill $OLD_PROXY_PID 2>/dev/null || true
        sleep 1
    fi
fi

# Kill any Python serve_assets.py processes
EXISTING_PYTHON=$(ps aux | grep "serve_assets.py" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING_PYTHON" ]; then
    echo -e "${YELLOW}Stopping existing asset server processes${NC}"
    echo "$EXISTING_PYTHON" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Kill any Python reverse_proxy.py processes
EXISTING_PROXY=$(ps aux | grep "reverse_proxy.py" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING_PROXY" ]; then
    echo -e "${YELLOW}Stopping existing reverse proxy processes${NC}"
    echo "$EXISTING_PROXY" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Kill any Python log_server.py processes
EXISTING_LOG_SERVER=$(ps aux | grep "log_server.py" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING_LOG_SERVER" ]; then
    echo -e "${YELLOW}Stopping existing log server processes${NC}"
    echo "$EXISTING_LOG_SERVER" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Kill existing ngrok if running
if [ -f /tmp/vlinder_ngrok.pid ]; then
    OLD_NGROK_PID=$(cat /tmp/vlinder_ngrok.pid 2>/dev/null)
    if [ -n "$OLD_NGROK_PID" ] && kill -0 $OLD_NGROK_PID 2>/dev/null; then
        echo -e "${YELLOW}Stopping existing ngrok (PID: $OLD_NGROK_PID)${NC}"
        kill $OLD_NGROK_PID 2>/dev/null || true
        sleep 1
    fi
fi

# Kill any ngrok processes pointing to port 8000
EXISTING_NGROK=$(ps aux | grep "ngrok http 8000" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING_NGROK" ]; then
    echo -e "${YELLOW}Stopping existing ngrok processes for port 8000${NC}"
    echo "$EXISTING_NGROK" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Kill any ngrok processes pointing to port 8001 (log server)
EXISTING_LOG_NGROK=$(ps aux | grep "ngrok http 8001" | grep -v grep | awk '{print $2}')
if [ -n "$EXISTING_LOG_NGROK" ]; then
    echo -e "${YELLOW}Stopping existing ngrok processes for port 8001${NC}"
    echo "$EXISTING_LOG_NGROK" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Check if port 8000 is still in use
if lsof -i :8000 >/dev/null 2>&1; then
    PORT_PID=$(lsof -ti :8000)
    if [ -n "$PORT_PID" ]; then
        echo -e "${YELLOW}Port 8000 is still in use (PID: $PORT_PID), killing...${NC}"
        kill $PORT_PID 2>/dev/null || true
        sleep 1
    fi
fi

# Check if port 8001 (log server) is still in use
if lsof -i :8001 >/dev/null 2>&1; then
    PORT_PID=$(lsof -ti :8001)
    if [ -n "$PORT_PID" ]; then
        echo -e "${YELLOW}Port 8001 is still in use (PID: $PORT_PID), killing...${NC}"
        kill $PORT_PID 2>/dev/null || true
        sleep 1
    fi
fi

# Check if port 4040 (ngrok API) is in use and kill associated ngrok
if lsof -i :4040 >/dev/null 2>&1; then
    NGROK_API_PID=$(lsof -ti :4040)
    if [ -n "$NGROK_API_PID" ]; then
        # Check if it's actually ngrok
        if ps -p $NGROK_API_PID -o comm= | grep -q ngrok; then
            echo -e "${YELLOW}Stopping ngrok using port 4040 (PID: $NGROK_API_PID)${NC}"
            kill $NGROK_API_PID 2>/dev/null || true
            sleep 1
        fi
    fi
fi

# Clean up old PID files
rm -f /tmp/vlinder_server.pid /tmp/vlinder_asset_server.pid /tmp/vlinder_log_server.pid /tmp/vlinder_proxy.pid /tmp/vlinder_ngrok.pid /tmp/vlinder_log_ngrok.pid /tmp/vlinder_flutter.pid

echo -e "${GREEN}Cleanup complete. Starting fresh...${NC}"
echo ""

# Copy .ht files from sample_app/assets to server/assets
echo -e "${GREEN}Copying .ht files from sample_app/assets to server/assets...${NC}"
SAMPLE_ASSETS_DIR="$PROJECT_ROOT/sample_app/assets"
SERVER_ASSETS_DIR="$PROJECT_ROOT/server/assets"

# Ensure server/assets directory exists
mkdir -p "$SERVER_ASSETS_DIR"

# Copy all .ht files
if [ -d "$SAMPLE_ASSETS_DIR" ]; then
    cp "$SAMPLE_ASSETS_DIR"/*.ht "$SERVER_ASSETS_DIR/" 2>/dev/null || true
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Copied .ht files to server/assets${NC}"
    else
        echo -e "${YELLOW}Warning: No .ht files found in sample_app/assets${NC}"
    fi
else
    echo -e "${YELLOW}Warning: sample_app/assets directory not found${NC}"
fi
echo ""

# Start Python asset server in background (internal port 8002)
echo -e "${GREEN}Starting Python asset server (internal port 8002)...${NC}"
cd "$SERVER_DIR"
python3 serve_assets.py &
ASSET_SERVER_PID=$!

# Wait for asset server to start
sleep 2

# Check if asset server is running
if ! kill -0 $ASSET_SERVER_PID 2>/dev/null; then
    echo -e "${RED}Error: Asset server failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}Asset server started (PID: $ASSET_SERVER_PID)${NC}"

# Start Python log server in background (internal port 8001)
echo -e "${GREEN}Starting Python log server (internal port 8001)...${NC}"
cd "$SERVER_DIR"
python3 log_server.py &
LOG_SERVER_PID=$!

# Wait for log server to start
sleep 2

# Check if log server is running
if ! kill -0 $LOG_SERVER_PID 2>/dev/null; then
    echo -e "${YELLOW}Warning: Log server failed to start (continuing anyway)${NC}"
    LOG_SERVER_PID=""
else
    echo -e "${GREEN}Log server started (PID: $LOG_SERVER_PID)${NC}"
fi

# Start reverse proxy router (public-facing port 8000)
echo -e "${GREEN}Starting reverse proxy router (port 8000)...${NC}"
cd "$SERVER_DIR"
python3 reverse_proxy.py &
PROXY_PID=$!

# Wait for reverse proxy to start
sleep 2

# Check if reverse proxy is running
if ! kill -0 $PROXY_PID 2>/dev/null; then
    echo -e "${RED}Error: Reverse proxy failed to start${NC}"
    kill $ASSET_SERVER_PID 2>/dev/null || true
    [ -n "$LOG_SERVER_PID" ] && kill $LOG_SERVER_PID 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}Reverse proxy started (PID: $PROXY_PID)${NC}"

# Start ngrok tunnel for reverse proxy (port 8000)
echo -e "${GREEN}Starting ngrok tunnel for reverse proxy...${NC}"
ngrok http 8000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Extract ngrok URL from API
NGROK_URL=""
MAX_RETRIES=10
RETRY_COUNT=0

while [ -z "$NGROK_URL" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4)
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ -z "$NGROK_URL" ]; then
    echo -e "${RED}Error: Could not get ngrok URL${NC}"
    echo "Check ngrok status: http://localhost:4040"
    kill $ASSET_SERVER_PID 2>/dev/null || true
    [ -n "$LOG_SERVER_PID" ] && kill $LOG_SERVER_PID 2>/dev/null || true
    kill $PROXY_PID 2>/dev/null || true
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}Ngrok tunnel started${NC}"
echo -e "${GREEN}Public URL (both services): $NGROK_URL${NC}"
echo -e "${GREEN}  - Assets: $NGROK_URL/*.ht${NC}"
echo -e "${GREEN}  - Logs: $NGROK_URL/logs${NC}"
echo ""
echo "Service PIDs:"
echo "  Asset Server (port 8002): $ASSET_SERVER_PID"
[ -n "$LOG_SERVER_PID" ] && echo "  Log Server (port 8001): $LOG_SERVER_PID"
echo "  Reverse Proxy (port 8000): $PROXY_PID"
echo "  Ngrok: $NGROK_PID"
echo ""
echo "To stop, run: kill $ASSET_SERVER_PID $PROXY_PID $NGROK_PID"
[ -n "$LOG_SERVER_PID" ] && echo "  kill $LOG_SERVER_PID"
echo ""
echo "Exporting URLs for build script..."
export NGROK_URL

# Save PID and URL to file for cleanup
echo "$ASSET_SERVER_PID" > /tmp/vlinder_asset_server.pid
[ -n "$LOG_SERVER_PID" ] && echo "$LOG_SERVER_PID" > /tmp/vlinder_log_server.pid
echo "$PROXY_PID" > /tmp/vlinder_proxy.pid
echo "$NGROK_PID" > /tmp/vlinder_ngrok.pid
echo "$NGROK_URL" > /tmp/vlinder_ngrok_url.txt

echo -e "${GREEN}Ready! Run build script with: ./scripts/build_container.sh${NC}"

# Open QR code terminal window
echo -e "${GREEN}Opening QR code window...${NC}"
if command -v qrencode &> /dev/null; then
    if command -v osascript &> /dev/null; then
        # macOS - open new Terminal window with QR code
        osascript <<EOF
tell application "Terminal"
    do script "clear && echo '========================================' && echo 'Vlinder Server QR Code' && echo '========================================' && echo '' && echo 'Server URL:' && echo '$NGROK_URL' && echo '' && echo 'Scan this QR code with the Vlinder Container app:' && echo '' && qrencode -m 2 -t utf8 <<< '$NGROK_URL' && echo '' && echo '========================================' && echo 'Press Ctrl+C to close this window' && echo '========================================'"
    activate
end tell
EOF
        echo -e "${GREEN}QR code window opened${NC}"
        sleep 2  # Give the terminal window time to open
    else
        echo -e "${YELLOW}Note: osascript not available. Displaying QR code here:${NC}"
        echo ""
        qrencode -m 2 -t utf8 <<< "$NGROK_URL"
        echo ""
    fi
else
    echo -e "${YELLOW}Warning: qrencode not found${NC}"
    echo "Install qrencode to display QR code:"
    echo "  macOS: brew install qrencode"
    echo "  Linux: sudo apt-get install qrencode"
    echo ""
    echo "Server URL: $NGROK_URL"
    echo "Scan this URL manually or install qrencode for QR code display"
fi

# Check if Flutter is available and offer device deployment
# Temporarily disable exit on error for user input handling
set +e
if command -v flutter &> /dev/null; then
    echo ""
    echo -e "${GREEN}Flutter detected.${NC}"
    
    # Pre-compilation check BEFORE device selection (much faster than flutter run)
    echo -e "${GREEN}Running pre-compilation check...${NC}"
    echo -e "${YELLOW}This will catch errors before the slow build process${NC}"
    
    cd "$PROJECT_ROOT"
    # Run flutter analyze to catch compilation errors quickly
    # Use --no-fatal-infos and --no-fatal-warnings to only fail on actual errors
    ANALYZE_OUTPUT=$(flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1)
    ANALYZE_EXIT_CODE=$?
    
    # Save full output for reference
    echo "$ANALYZE_OUTPUT" > /tmp/flutter_analyze.log
    
    if [ $ANALYZE_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ Pre-compilation check passed!${NC}"
        echo ""
    else
        echo -e "${RED}✗ Pre-compilation check failed!${NC}"
        echo ""
        echo -e "${RED}Errors found:${NC}"
        # Extract and display errors (more readable format)
        echo "$ANALYZE_OUTPUT" | grep -E "error •|Error:|ERROR" | head -n 30
        echo ""
        echo -e "${YELLOW}Full analysis output saved to: /tmp/flutter_analyze.log${NC}"
        echo -e "${YELLOW}View full output: cat /tmp/flutter_analyze.log${NC}"
        echo ""
        echo -e "${RED}Fix the errors above before continuing, or continue anyway (not recommended).${NC}"
        read -p "Continue anyway? (y/n): " CONTINUE_CHOICE
        if [ "$CONTINUE_CHOICE" != "y" ] && [ "$CONTINUE_CHOICE" != "Y" ]; then
            echo -e "${YELLOW}Skipping Flutter deployment due to compilation errors${NC}"
            echo -e "${YELLOW}Fix errors and run the script again${NC}"
            # Re-enable exit on error and exit
            set -e
            exit 0
        fi
        echo -e "${YELLOW}Continuing despite errors...${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}Would you like to deploy to a device?${NC}"
    read -p "Deploy to device? (y/n): " DEPLOY_CHOICE
    
    if [ "$DEPLOY_CHOICE" = "y" ] || [ "$DEPLOY_CHOICE" = "Y" ]; then
        # Get list of available devices
        echo -e "${GREEN}Checking available devices...${NC}"
        DEVICES_OUTPUT=$(flutter devices 2>&1)
        echo "$DEVICES_OUTPUT"
        
        # Parse device information from flutter devices output
        # Format: device_name • device_id • platform • version
        # We need the device_id (second field) for flutter run
        
        if [ -z "$(echo "$DEVICES_OUTPUT" | grep -E '•')" ]; then
            echo -e "${YELLOW}No devices found. Make sure a device is connected or emulator is running.${NC}"
            echo -e "${YELLOW}Continuing with server only...${NC}"
        else
            # Parse devices - extract device_id (2nd field) and device_name (1st field)
            # Format: device_name • device_id • platform • version
            DEVICE_ARRAY=()
            DEVICE_NAMES=()
            INDEX=1
            
            # Filter device lines (exclude header lines)
            DEVICE_LINES=$(echo "$DEVICES_OUTPUT" | grep -E '•' | grep -v '^Found' | grep -v '^Checking')
            
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # Extract device name (first field before •)
                    DEVICE_NAME=$(echo "$line" | awk -F '•' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    # Extract device ID (second field after first •) - this is what flutter run needs
                    DEVICE_ID=$(echo "$line" | awk -F '•' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ -n "$DEVICE_ID" ] && [ -n "$DEVICE_NAME" ]; then
                        DEVICE_ARRAY+=("$DEVICE_ID")
                        DEVICE_NAMES+=("$DEVICE_NAME")
                        echo "  [$INDEX] $DEVICE_NAME ($DEVICE_ID)"
                        INDEX=$((INDEX + 1))
                    fi
                fi
            done <<< "$DEVICE_LINES"
            
            # Ask user to select device
            echo ""
            read -p "Select device number (1-$((INDEX - 1))): " SELECTED_INDEX
            
            # Validate selection
            if [ "$SELECTED_INDEX" -ge 1 ] && [ "$SELECTED_INDEX" -lt "$INDEX" ] 2>/dev/null; then
                SELECTED_DEVICE="${DEVICE_ARRAY[$((SELECTED_INDEX - 1))]}"
                SELECTED_NAME="${DEVICE_NAMES[$((SELECTED_INDEX - 1))]}"
                
                echo -e "${GREEN}Selected: $SELECTED_NAME ($SELECTED_DEVICE)${NC}"
                echo -e "${GREEN}Building and deploying with server URL: $NGROK_URL${NC}"
                echo ""
                
                # Open log viewer window BEFORE running flutter
                echo -e "${GREEN}Opening debug log viewer window...${NC}"
                if command -v osascript &> /dev/null; then
                    # macOS - open new Terminal window
                    osascript <<EOF
tell application "Terminal"
    do script "cd '$PROJECT_ROOT' && '$PROJECT_ROOT/scripts/view_logs.sh'"
    activate
end tell
EOF
                    echo -e "${GREEN}Log viewer window opened${NC}"
                    sleep 2  # Give the terminal window time to open
                else
                    echo -e "${YELLOW}Note: osascript not available. Run '$PROJECT_ROOT/scripts/view_logs.sh' manually to view logs${NC}"
                fi
                
                # Build and run Flutter app
                # Note: Server URL is no longer baked in - user will scan QR code
                cd "$PROJECT_ROOT"
                
                # Build command - log server URL can still be passed for debugging
                FLUTTER_CMD="flutter run -d \"$SELECTED_DEVICE\" --dart-define=VLINDER_LOG_SERVER_URL=\"$NGROK_URL\""
                echo -e "${GREEN}Running: $FLUTTER_CMD${NC}"
                echo -e "${GREEN}Debug logs are visible in the log viewer window${NC}"
                echo -e "${GREEN}Both services accessible via: $NGROK_URL${NC}"
                eval "$FLUTTER_CMD" &
                FLUTTER_PID=$!
                echo "$FLUTTER_PID" > /tmp/vlinder_flutter.pid
                echo -e "${GREEN}Flutter app deploying (PID: $FLUTTER_PID)${NC}"
                echo -e "${GREEN}Flutter output will appear above. Server continues running below.${NC}"
            else
                echo -e "${RED}Invalid selection. Continuing with server only...${NC}"
            fi
        fi
    fi
else
    echo -e "${YELLOW}Flutter not found. Skipping device deployment.${NC}"
    echo -e "${YELLOW}Install Flutter from https://flutter.dev/docs/get-started/install${NC}"
fi

# Re-enable exit on error for monitoring loop
set -e

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down...${NC}"
    if [ -n "$ASSET_SERVER_PID" ] && kill -0 $ASSET_SERVER_PID 2>/dev/null; then
        kill $ASSET_SERVER_PID 2>/dev/null || true
        echo "Stopped asset server"
    fi
    if [ -n "$LOG_SERVER_PID" ] && kill -0 $LOG_SERVER_PID 2>/dev/null; then
        kill $LOG_SERVER_PID 2>/dev/null || true
        echo "Stopped log server"
    fi
    if [ -n "$PROXY_PID" ] && kill -0 $PROXY_PID 2>/dev/null; then
        kill $PROXY_PID 2>/dev/null || true
        echo "Stopped reverse proxy"
    fi
    if [ -n "$NGROK_PID" ] && kill -0 $NGROK_PID 2>/dev/null; then
        kill $NGROK_PID 2>/dev/null || true
        echo "Stopped ngrok"
    fi
    if [ -f /tmp/vlinder_flutter.pid ]; then
        FLUTTER_PID=$(cat /tmp/vlinder_flutter.pid)
        if kill -0 $FLUTTER_PID 2>/dev/null; then
            kill $FLUTTER_PID 2>/dev/null || true
            echo "Stopped Flutter app"
        fi
    fi
    rm -f /tmp/vlinder_asset_server.pid /tmp/vlinder_log_server.pid /tmp/vlinder_proxy.pid /tmp/vlinder_ngrok.pid /tmp/vlinder_ngrok_url.txt /tmp/vlinder_flutter.pid
    exit 0
}

# Trap signals to cleanup
trap cleanup SIGINT SIGTERM

# Keep script running and monitor processes
echo ""
echo -e "${GREEN}Server running. Press Ctrl+C to stop.${NC}"
while true; do
    # Check if reverse proxy is still running
    if ! kill -0 $PROXY_PID 2>/dev/null; then
        echo -e "${RED}Reverse proxy stopped unexpectedly${NC}"
        cleanup
    fi
    # Check if asset server is still running
    if ! kill -0 $ASSET_SERVER_PID 2>/dev/null; then
        echo -e "${RED}Asset server stopped unexpectedly${NC}"
        cleanup
    fi
    # Check if log server is still running
    if [ -n "$LOG_SERVER_PID" ] && ! kill -0 $LOG_SERVER_PID 2>/dev/null; then
        echo -e "${YELLOW}Log server stopped${NC}"
        # Don't exit, reverse proxy can still work without log server
    fi
    # Check if ngrok is still running
    if [ -n "$NGROK_PID" ] && ! kill -0 $NGROK_PID 2>/dev/null; then
        echo -e "${YELLOW}Ngrok stopped${NC}"
        # Don't exit, server can still work without ngrok (localhost access)
    fi
    sleep 5
done

