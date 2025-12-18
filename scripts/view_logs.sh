#!/bin/bash
# View Vlinder debug logs in real-time

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/server/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Vlinder Debug Log Viewer${NC}"
echo -e "${BLUE}==================================${NC}"
echo "Log directory: $LOG_DIR"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Wait for log files if they don't exist yet
if [ -z "$(ls -A "$LOG_DIR"/*.log 2>/dev/null)" ]; then
    echo -e "${YELLOW}Waiting for log files to be created...${NC}"
    echo -e "${YELLOW}(Make sure the log server is running and the app is sending logs)${NC}"
    echo ""
    
    # Wait up to 60 seconds for log files
    COUNT=0
    while [ -z "$(ls -A "$LOG_DIR"/*.log 2>/dev/null)" ] && [ $COUNT -lt 60 ]; do
        sleep 1
        COUNT=$((COUNT + 1))
        if [ $((COUNT % 5)) -eq 0 ]; then
            echo -e "${YELLOW}Still waiting... (${COUNT}s)${NC}"
        fi
    done
    
    if [ -z "$(ls -A "$LOG_DIR"/*.log 2>/dev/null)" ]; then
        echo -e "${RED}No log files found after 60 seconds.${NC}"
        echo -e "${YELLOW}The log server may not be running or the app may not be sending logs.${NC}"
        echo ""
    else
        echo -e "${GREEN}Log files detected! Starting viewer...${NC}"
        echo ""
    fi
fi

# Function to format log line
format_log_line() {
    local line="$1"
    # Try to parse JSON
    timestamp=$(echo "$line" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('timestamp', '')[:19])" 2>/dev/null || echo "")
    level=$(echo "$line" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('level', 'DEBUG'))" 2>/dev/null || echo "DEBUG")
    component=$(echo "$line" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('component', ''))" 2>/dev/null || echo "")
    message=$(echo "$line" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('message', ''))" 2>/dev/null || echo "$line")
    
    # Format timestamp if empty
    if [ -z "$timestamp" ]; then
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    
    # Color code by level
    case "$level" in
        ERROR)
            echo -e "${RED}[$timestamp] [ERROR] [$component] $message${NC}"
            ;;
        WARNING)
            echo -e "${YELLOW}[$timestamp] [WARNING] [$component] $message${NC}"
            ;;
        INFO)
            echo -e "${GREEN}[$timestamp] [INFO] [$component] $message${NC}"
            ;;
        *)
            echo "[$timestamp] [$level] [$component] $message"
            ;;
    esac
}

# Tail all log files with formatting
if [ -n "$(ls -A "$LOG_DIR"/*.log 2>/dev/null)" ]; then
    tail -f "$LOG_DIR"/*.log 2>/dev/null | while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Format and display the log line
        format_log_line "$line"
    done
else
    echo -e "${RED}No log files found. Exiting.${NC}"
    echo ""
    echo "To troubleshoot:"
    echo "1. Check if log server is running: curl http://localhost:8001/health"
    echo "2. Check if log directory exists: ls -la $LOG_DIR"
    echo "3. Make sure the app is configured with VLINDER_LOG_SERVER_URL"
    exit 1
fi

