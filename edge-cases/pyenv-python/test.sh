#!/bin/bash
# Test script for edge-cases/pyenv-python
#
# This test validates pyenv Python SSL detection behavior.
# Unlike other examples, this is a DIAGNOSTIC test - it checks whether
# SSL capture will work, not whether it captures events.
#
# Expected outcomes:
# - pyenv with static OpenSSL: Test shows warning, no events captured (expected)
# - pyenv with shared OpenSSL: Test captures events normally
# - System Python: Test captures events normally

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="./output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
SENSOR_BIN="${OISP_SENSOR_BIN:-../../bin/oisp-sensor}"

echo "=== pyenv Python Edge Case Test ==="
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

# Check Python
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "ERROR: Python not found"
    exit 2
fi

PYTHON_PATH=$(which $PYTHON_CMD)
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)

echo "Python Path: $PYTHON_PATH"
echo "Python Version: $PYTHON_VERSION"
echo ""

# Run diagnosis first
echo "Running SSL diagnosis..."
chmod +x ./diagnose.sh
./diagnose.sh
echo ""

# Determine if we expect events to be captured
IS_PYENV=false
HAS_DYNAMIC_SSL=false

if [[ "$PYTHON_PATH" == *".pyenv"* ]]; then
    IS_PYENV=true
    echo "Detected: pyenv installation"
fi

# Check for dynamic SSL (Linux only)
if command -v ldd &> /dev/null; then
    # Check the _ssl module specifically
    SSL_MODULE=$($PYTHON_CMD -c "import _ssl; print(_ssl.__file__)" 2>/dev/null || echo "")
    if [ -n "$SSL_MODULE" ] && [ -f "$SSL_MODULE" ]; then
        if ldd "$SSL_MODULE" 2>/dev/null | grep -q "libssl"; then
            HAS_DYNAMIC_SSL=true
            echo "Detected: Dynamic SSL linking in _ssl module"
        else
            echo "Detected: Static SSL linking in _ssl module"
        fi
    else
        # Fallback: check main binary
        if ldd "$PYTHON_PATH" 2>/dev/null | grep -q "libssl"; then
            HAS_DYNAMIC_SSL=true
            echo "Detected: Dynamic SSL linking in main binary"
        else
            echo "Detected: Static SSL linking (or no SSL in main binary)"
        fi
    fi
else
    # On macOS, assume dynamic linking for system installs
    if [[ "$PYTHON_PATH" != *".pyenv"* ]]; then
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
$PYTHON_CMD -m pip install -q -r requirements.txt

# Start sensor
echo "Starting sensor..."
sudo "$SENSOR_BIN" record \
    --output "$EVENTS_FILE" \
    --process python \
    --timeout 30 &
SENSOR_PID=$!

# Wait for sensor to initialize
sleep 3

# Run test app
echo "Running test app..."
$PYTHON_CMD app.py || true

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
if [ "$IS_PYENV" = true ] && [ "$HAS_DYNAMIC_SSL" = false ]; then
    # pyenv with static SSL - expect no capture
    if [ "$EVENT_COUNT" -eq 0 ]; then
        echo "=== EXPECTED BEHAVIOR ==="
        echo ""
        echo "No events captured - this is expected for pyenv with static OpenSSL."
        echo ""
        echo "Solutions:"
        echo "  1. Use system Python: apt install python3"
        echo "  2. Rebuild with shared SSL: PYTHON_CONFIGURE_OPTS=\"--enable-shared\" pyenv install 3.11"
        echo "  3. Use Docker: docker run -it python:3.11 python app.py"
        echo "  4. Use venv with system Python: /usr/bin/python3 -m venv .venv"
        echo ""
        exit 0  # This is expected, not a failure
    else
        echo "=== UNEXPECTED SUCCESS ==="
        echo ""
        echo "Events were captured even with pyenv static SSL."
        echo "This might mean:"
        echo "  - Your pyenv Python was built with shared OpenSSL"
        echo "  - The sensor used an alternative capture method"
        echo ""
        exit 0
    fi
else
    # System Python or pyenv with dynamic SSL - expect capture
    if [ "$EVENT_COUNT" -gt 0 ]; then
        echo "=== TEST PASSED ==="
        echo ""
        echo "Events captured successfully."
        echo ""
        # Show sample event
        echo "Sample event:"
        head -1 "$EVENTS_FILE" | $PYTHON_CMD -m json.tool 2>/dev/null || head -1 "$EVENTS_FILE"
        exit 0
    else
        echo "=== TEST FAILED ==="
        echo ""
        echo "No events captured, but dynamic SSL was expected."
        echo ""
        echo "Debug:"
        echo "  - Check sensor logs"
        echo "  - Verify SSL libraries are accessible"
        echo "  - Run: sudo $SENSOR_BIN diagnose --pid \$(pgrep -f 'python app.py')"
        exit 1
    fi
fi
