#!/bin/bash
# Test script for multi-process/python-celery
#
# This script:
# 1. Starts Redis, OISP sensor, and Celery workers
# 2. Submits tasks via app.py
# 3. Validates that AI events from multiple workers are captured
# 4. Cleans up
#
# Environment:
#   OISP_SENSOR_BIN   Path to sensor binary (optional, uses Docker if not set)
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

# Get sensor binary (optional - Docker used if not available)
OISP_SENSOR_BIN="${OISP_SENSOR_BIN:-../../bin/oisp-sensor}"

# Use sudo only if not root
SUDO=""
if [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

# Check requirements
if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY not set"
    exit 2
fi

echo "=== Python + Celery Multi-Worker Test ==="
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Stop all containers
    docker compose down -v 2>/dev/null || true

    # Stop local sensor if running
    if [ -n "$SENSOR_PID" ] && kill -0 "$SENSOR_PID" 2>/dev/null; then
        $SUDO kill "$SENSOR_PID" 2>/dev/null || true
        wait "$SENSOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Create output directory
mkdir -p "$OUTPUT_DIR"
rm -f "$EVENTS_FILE" "$SENSOR_LOG"

# Decide whether to use local sensor or Docker sensor
USE_DOCKER_SENSOR=true
if [ -f "$OISP_SENSOR_BIN" ]; then
    echo "Using local sensor binary: $OISP_SENSOR_BIN"
    USE_DOCKER_SENSOR=false
else
    echo "Using Docker-based sensor"
fi

if [ "$USE_DOCKER_SENSOR" = "true" ]; then
    # Use Docker Compose for everything
    echo ""
    echo "Starting all services with Docker Compose..."
    docker compose up --build -d redis sensor worker

    # Wait for services to be ready
    echo "Waiting for services..."
    sleep 10

    # Run the submitter
    echo ""
    echo "Running task submitter..."
    docker compose run --rm submitter

    # Wait for events
    echo ""
    echo "Waiting for events to be captured..."
    sleep 10

else
    # Use local sensor + Docker for Redis/Celery
    echo ""
    echo "Starting Redis and Celery workers..."
    docker compose up --build -d redis worker

    # Wait for Redis
    echo "Waiting for Redis..."
    sleep 5

    # Start local sensor
    echo ""
    echo "Starting OISP Sensor..."
    $SUDO "$OISP_SENSOR_BIN" record \
        --output "$EVENTS_FILE" \
        > "$SENSOR_LOG" 2>&1 &
    SENSOR_PID=$!

    sleep 3

    if ! kill -0 "$SENSOR_PID" 2>/dev/null; then
        echo "ERROR: Sensor failed to start. Check $SENSOR_LOG"
        cat "$SENSOR_LOG"
        exit 1
    fi

    echo "Sensor started (PID: $SENSOR_PID)"

    # Run the submitter
    echo ""
    echo "Running task submitter..."
    docker compose run --rm submitter

    # Wait for events
    echo ""
    "$WAIT_SCRIPT" "$EVENTS_FILE" 4 60

    # Stop sensor gracefully
    echo ""
    echo "Stopping sensor..."
    $SUDO kill -TERM "$SENSOR_PID" 2>/dev/null || true
    sleep 2
fi

# Validate events
echo ""
echo "Validating captured events..."
python3 "$VALIDATE_SCRIPT" "$EVENTS_FILE" "$EXPECTED_FILE"
RESULT=$?

# Show summary
echo ""
if [ $RESULT -eq 0 ]; then
    echo "=== TEST PASSED ==="
    echo ""
    echo "Successfully captured AI events from multiple Celery workers!"
else
    echo "=== TEST FAILED ==="
    echo ""
    echo "Captured events:"
    cat "$EVENTS_FILE" 2>/dev/null | head -20 || echo "(no events)"
    echo ""
    echo "Sensor log:"
    cat "$SENSOR_LOG" 2>/dev/null | tail -50 || docker compose logs sensor | tail -50
fi

exit $RESULT
