#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# -------------------------------
# Configurable Variables
# -------------------------------
WAIT_TIME=8              # Time to wait (in seconds) after launching Chromium
LOCAL_IP="127.0.0.1"     # IP address for MCP server and Inspector connections
CHROME_PORT=9222         # Chromium CDP port
MCP_PORT=8931            # Port for MCP server

# -------------------------------
# Function to Kill Process on Port
# -------------------------------
free_port() {
  PORT=$1
  PID=$(lsof -ti tcp:$PORT || true)
  if [ -n "$PID" ]; then
    echo "Releasing port $PORT (PID: $PID)..."
    kill -9 "$PID"
    sleep 1
  fi
}

# -------------------------------
# Function to Launch Chromium
# -------------------------------
launch_chromium() {
  echo "Launching Chromium..."
  chromium --remote-debugging-port=$CHROME_PORT --disable-gpu --disable-dev-shm-usage --enable-unsafe-swiftshader &
  CHROMIUM_PID=$!
  echo "Waiting for $WAIT_TIME seconds to allow Chromium to start..."
  sleep "$WAIT_TIME"
}

# -------------------------------
# Function to Retrieve CDP Endpoint
# -------------------------------
get_cdp_endpoint() {
  echo "Retrieving WebSocket Debugger URL..."
  CDP_ENDPOINT=$(curl -s "http://$LOCAL_IP:$CHROME_PORT/json/version" | jq -r '.webSocketDebuggerUrl')
  echo "WebSocket Debugger URL: $CDP_ENDPOINT"
}

# -------------------------------
# Function to Start Playwright MCP Server
# -------------------------------
start_mcp_server() {
  echo "Starting Playwright MCP server on port $MCP_PORT..."
  npx @playwright/mcp@latest --cdp-endpoint="$CDP_ENDPOINT" --port="$MCP_PORT" &
  MCP_PID=$!
  echo "Waiting for $WAIT_TIME seconds to allow MCP server to start..."
  sleep "$WAIT_TIME"
}

# -------------------------------
# Function to Launch MCP Inspector
# -------------------------------
launch_inspector() {
  echo "Launching MCP Inspector..."
  npx @modelcontextprotocol/inspector node build/index.js --serverUrl="http://$LOCAL_IP:$MCP_PORT/sse"
}

# -------------------------------
# Cleanup Function
# -------------------------------
cleanup() {
  echo "Cleaning up..."
  kill "$CHROMIUM_PID" "$MCP_PID" 2>/dev/null || true
  exit
}
trap cleanup EXIT

# -------------------------------
# Release Ports Before Start
# -------------------------------
free_port $CHROME_PORT
free_port $MCP_PORT

# -------------------------------
# Execute Functions
# -------------------------------
launch_chromium
get_cdp_endpoint
start_mcp_server
launch_inspector
