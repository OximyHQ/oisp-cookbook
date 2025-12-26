#!/bin/bash
# Test script for python/02-litellm
#
# This script:
# 1. Starts the OISP sensor
# 2. Runs the LiteLLM example app
# 3. Validates captured events
#
# Environment:
#   OISP_SENSOR_BIN   Path to sensor binary (required)
#   OPENAI_API_KEY    OpenAI API key (required)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
OUTPUT_DIR="./output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
SENSOR_LOG="$OUTPUT_DIR/sensor.log"
EXPECTED_FILE="./expected-events.json"
VALIDATE_SCRIPT="../../shared/scripts/validate.py"
WAIT_SCRIPT="../../shared/scripts/wait-for-events.sh"

# Get sensor binary
OISP_SENSOR_BIN="${OISP_SENSOR_BIN:-../../bin/oisp-sensor}"

# Use sudo only if not root
SUDO=""
if [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

# Check requirements
if [ ! -f "$OISP_SENSOR_BIN" ]; then
    echo "ERROR: Sensor binary not found at $OISP_SENSOR_BIN"
    echo "Set OISP_SENSOR_BIN or run 'make download-sensor' from repo root"
    exit 2
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY not set"
    exit 2
fi

echo "=== LiteLLM Test ==="
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Stop sensor if running
    if [ -n "$SENSOR_PID" ] && kill -0 "$SENSOR_PID" 2>/dev/null; then
        $SUDO kill "$SENSOR_PID" 2>/dev/null || true
        wait "$SENSOR_PID" 2>/dev/null || true
    fi

    # Deactivate virtualenv
    deactivate 2>/dev/null || true
}
trap cleanup EXIT

# Create output directory
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE" "$SENSOR_LOG"

# Start sensor in background
echo "Starting OISP Sensor..."
$SUDO "$OISP_SENSOR_BIN" record \
    --output "$EVENTS_FILE" \
     \
    --process python \
    > "$SENSOR_LOG" 2>&1 &
SENSOR_PID=$!

# Wait for sensor to initialize
sleep 3

if ! kill -0 "$SENSOR_PID" 2>/dev/null; then
    echo "ERROR: Sensor failed to start. Check $SENSOR_LOG"
    cat "$SENSOR_LOG"
    exit 1
fi

echo "Sensor started (PID: $SENSOR_PID)"

# Setup Python environment
echo ""
echo "Setting up Python environment..."
python3 -m venv .venv 2>/dev/null || true
source .venv/bin/activate
pip install -q -r requirements.txt

# Run the app
echo ""
echo "Running LiteLLM example..."
python app.py

# Wait for events to be captured
echo ""
"$WAIT_SCRIPT" "$EVENTS_FILE" 2 30

# Give sensor more time to process and emit ai.response
sleep 5

# Stop sensor gracefully
echo ""
echo "Stopping sensor..."
$SUDO kill -TERM "$SENSOR_PID" 2>/dev/null || true
sleep 2

# Validate events
echo ""
echo "Validating captured events..."
python "$VALIDATE_SCRIPT" "$EVENTS_FILE" "$EXPECTED_FILE"
RESULT=$?

# Show summary
echo ""
if [ $RESULT -eq 0 ]; then
    echo "=== TEST PASSED ==="
else
    echo "=== TEST FAILED ==="
    echo ""
    echo "Captured events:"
    cat "$EVENTS_FILE" | head -20
    echo ""
    echo "Sensor log:"
    cat "$SENSOR_LOG" | tail -50
fi

exit $RESULT
