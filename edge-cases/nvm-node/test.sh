#!/bin/bash
# Test script for edge-cases/nvm-node
#
# This test validates NVM Node.js SSL detection behavior.
# Unlike other examples, this is a DIAGNOSTIC test - it checks whether
# SSL capture will work, not whether it captures events.
#
# Expected outcomes:
# - NVM with static OpenSSL: Test shows warning, no events captured (expected)
# - NVM with shared OpenSSL: Test captures events normally
# - System Node.js: Test captures events normally

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="./output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
SENSOR_BIN="${OISP_SENSOR_BIN:-../../bin/oisp-sensor}"

echo "=== NVM Node.js Edge Case Test ==="
echo ""

# Check if sensor exists
if [ ! -f "$SENSOR_BIN" ]; then
    echo "ERROR: Sensor binary not found at $SENSOR_BIN"
    echo "Set OISP_SENSOR_BIN or run from cookbook root with 'make download-sensor'"
    exit 2
fi

# Check for API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY not set"
    exit 2
fi

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found"
    exit 2
fi

NODE_PATH=$(which node)
NODE_VERSION=$(node --version)

echo "Node.js Path: $NODE_PATH"
echo "Node.js Version: $NODE_VERSION"
echo ""

# Run diagnosis first
echo "Running SSL diagnosis..."
chmod +x ./diagnose.sh
./diagnose.sh
echo ""

# Determine if we expect events to be captured
IS_NVM=false
HAS_DYNAMIC_SSL=false

if [[ "$NODE_PATH" == *".nvm"* ]]; then
    IS_NVM=true
    echo "Detected: NVM installation"
fi

# Check for dynamic SSL (Linux only)
if command -v ldd &> /dev/null; then
    if ldd "$NODE_PATH" 2>/dev/null | grep -q "libssl"; then
        HAS_DYNAMIC_SSL=true
        echo "Detected: Dynamic SSL linking"
    else
        echo "Detected: Static SSL linking (or no SSL)"
    fi
else
    # On macOS, assume dynamic linking for system installs
    if [[ "$NODE_PATH" != *".nvm"* ]]; then
        HAS_DYNAMIC_SSL=true
        echo "Detected: System installation (assumed dynamic SSL)"
    fi
fi

echo ""
echo "=== Running Capture Test ==="
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE"

# Install dependencies
npm install --silent

# Start sensor
echo "Starting sensor..."
sudo "$SENSOR_BIN" record \
    --output "$EVENTS_FILE" \
    --process node \
    --timeout 30 &
SENSOR_PID=$!

# Wait for sensor to initialize
sleep 3

# Run test app
echo "Running test app..."
node app.js || true

# Wait for sensor to capture
sleep 5

# Stop sensor
sudo kill $SENSOR_PID 2>/dev/null || true
wait $SENSOR_PID 2>/dev/null || true

# Analyze results
echo ""
echo "=== Results ==="
echo ""

EVENT_COUNT=0
if [ -f "$EVENTS_FILE" ]; then
    EVENT_COUNT=$(wc -l < "$EVENTS_FILE" | tr -d ' ')
fi

echo "Events captured: $EVENT_COUNT"
echo ""

# Interpret results based on expectations
if [ "$IS_NVM" = true ] && [ "$HAS_DYNAMIC_SSL" = false ]; then
    # NVM with static SSL - expect no capture
    if [ "$EVENT_COUNT" -eq 0 ]; then
        echo "=== EXPECTED BEHAVIOR ==="
        echo ""
        echo "No events captured - this is expected for NVM with static OpenSSL."
        echo ""
        echo "Solutions:"
        echo "  1. Use system Node.js: apt install nodejs"
        echo "  2. Rebuild with shared SSL: nvm install 20 --shared-openssl"
        echo "  3. Use Docker: docker run -it node:20 app.js"
        echo ""
        exit 0  # This is expected, not a failure
    else
        echo "=== UNEXPECTED SUCCESS ==="
        echo ""
        echo "Events were captured even with NVM static SSL."
        echo "This might mean:"
        echo "  - Your NVM Node.js was built with shared OpenSSL"
        echo "  - The sensor used an alternative capture method"
        echo ""
        exit 0
    fi
else
    # System Node.js or NVM with dynamic SSL - expect capture
    if [ "$EVENT_COUNT" -gt 0 ]; then
        echo "=== TEST PASSED ==="
        echo ""
        echo "Events captured successfully."
        echo ""
        # Show sample event
        echo "Sample event:"
        head -1 "$EVENTS_FILE" | python3 -m json.tool 2>/dev/null || head -1 "$EVENTS_FILE"
        exit 0
    else
        echo "=== TEST FAILED ==="
        echo ""
        echo "No events captured, but dynamic SSL was expected."
        echo ""
        echo "Debug:"
        echo "  - Check sensor logs"
        echo "  - Verify SSL libraries are accessible"
        echo "  - Run: sudo $SENSOR_BIN diagnose --pid \$(pgrep -f 'node app.js')"
        exit 1
    fi
fi
