#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variable to track appload PID
APPLOAD_PID=""

# Cleanup function to kill appload on script exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping watch script...${NC}"
    if [ -n "$APPLOAD_PID" ] && kill -0 $APPLOAD_PID 2>/dev/null; then
        echo -e "${RED}Killing appload (PID: $APPLOAD_PID)${NC}"
        kill $APPLOAD_PID 2>/dev/null
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Function to start appload
start_appload() {
    if [ ! -f "./appload" ]; then
        echo -e "${RED}Error: appload binary not found in repo root${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Starting appload...${NC}"
    ./appload &
    APPLOAD_PID=$!
    echo -e "${BLUE}appload running (PID: $APPLOAD_PID)${NC}"
}

# Function to stop appload
stop_appload() {
    if [ -n "$APPLOAD_PID" ] && kill -0 $APPLOAD_PID 2>/dev/null; then
        echo -e "${RED}Stopping appload (PID: $APPLOAD_PID)${NC}"
        kill $APPLOAD_PID 2>/dev/null
        wait $APPLOAD_PID 2>/dev/null
    fi
    APPLOAD_PID=""
}

echo -e "${BLUE}Starting file watcher for backend/src and ui/${NC}"
echo -e "${YELLOW}Will rebuild and restart automatically on file changes...${NC}"
echo ""

# Run initial build
echo -e "${GREEN}Running initial build...${NC}"
./build-pc.sh

# Check if inotifywait is available
if ! command -v inotifywait &> /dev/null; then
    echo -e "${YELLOW}inotifywait not found. Installing inotify-tools...${NC}"
    echo "Please run: sudo apt-get install inotify-tools"
    echo ""
    echo "Or use watchexec: https://github.com/watchexec/watchexec"
    exit 1
fi

# Start appload after initial build
start_appload

# Watch for changes
echo ""
echo -e "${BLUE}Watching for changes... (Ctrl+C to stop)${NC}"
echo ""

while true; do
    # Wait for file changes in backend/src or ui directories
    inotifywait -r -e modify,create,delete,move \
        backend/src ui \
        --exclude '(\.swp|\.swx|~|4913|flycheck)' \
        2>/dev/null

    # Small debounce delay to avoid multiple rapid rebuilds
    sleep 0.5
    
    echo ""
    echo -e "${GREEN}Change detected! Restarting...${NC}"
    
    # Stop appload
    stop_appload
    
    # Rebuild
    ./build-pc.sh
    
    # Start appload again
    start_appload
    
    echo ""
    echo -e "${BLUE}Watching for changes... (Ctrl+C to stop)${NC}"
    echo ""
done
