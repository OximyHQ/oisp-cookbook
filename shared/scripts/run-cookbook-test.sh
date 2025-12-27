#!/bin/bash
#
# Shared Test Harness for OISP Cookbooks
#
# This script replaces all individual test.sh scripts with a single,
# parameterized test runner that auto-detects language and handles
# all cookbook types (Python, Node.js, Docker Compose, Kubernetes).
#
# Usage:
#   ./run-cookbook-test.sh <cookbook-path>
#
# Environment Variables:
#   OISP_SENSOR_BIN   Path to sensor binary (default: ../../bin/oisp-sensor)
#   OPENAI_API_KEY    OpenAI API key (required for most tests)
#   ANTHROPIC_API_KEY Anthropic API key (required for Anthropic examples)
#
# Exit codes:
#   0 = Test passed
#   1 = Test failed (validation error)
#   2 = Prerequisites not met (missing binary, API key, etc.)
#
# This script:
#   1. Auto-detects language from requirements.txt/package.json
#   2. Starts OISP sensor
#   3. Sets up language environment (venv/npm install)
#   4. Runs the application
#   5. Waits for events to be captured
#   6. Validates events against expected-events.json
#   7. Cleans up and reports results

set -e

# Get script directory and cookbook path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKBOOK_PATH="${1:?Cookbook path required}"

# Convert to absolute path if relative
if [[ "$COOKBOOK_PATH" != /* ]]; then
    COOKBOOK_PATH="$(cd "$COOKBOOK_PATH" 2>/dev/null && pwd)" || {
        echo "ERROR: Cookbook directory not found: $1"
        exit 2
    }
fi

COOKBOOK_NAME=$(basename "$COOKBOOK_PATH")
cd "$COOKBOOK_PATH"

# Configuration
OUTPUT_DIR="$COOKBOOK_PATH/output"
EVENTS_FILE="$OUTPUT_DIR/events.jsonl"
SENSOR_LOG="$OUTPUT_DIR/sensor.log"
EXPECTED_FILE="$COOKBOOK_PATH/expected-events.json"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate.py"
WAIT_SCRIPT="$SCRIPT_DIR/wait-for-events.sh"

# Detect language
LANGUAGE=$("$SCRIPT_DIR/detect-language.sh" "$COOKBOOK_PATH")

# Get sensor binary path
OISP_SENSOR_BIN="${OISP_SENSOR_BIN:-$SCRIPT_DIR/../../bin/oisp-sensor}"

# Use sudo only if not root
SUDO=""
if [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

#
# Functions
#

log() {
    echo "$@"
}

error() {
    echo "ERROR: $@" >&2
}

check_prerequisites() {
    # Check sensor binary
    if [ ! -f "$OISP_SENSOR_BIN" ]; then
        error "Sensor binary not found at $OISP_SENSOR_BIN"
        error "Set OISP_SENSOR_BIN or run 'make download-sensor' from repo root"
        exit 2
    fi

    # Check expected-events.json
    if [ ! -f "$EXPECTED_FILE" ]; then
        error "expected-events.json not found in $COOKBOOK_PATH"
        exit 2
    fi

    # Check API keys (basic check - could be smarter based on provider)
    if [ -z "$OPENAI_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
        error "No API key set (OPENAI_API_KEY or ANTHROPIC_API_KEY required)"
        exit 2
    fi

    # Check language
    if [ "$LANGUAGE" = "unknown" ]; then
        error "Could not detect language for $COOKBOOK_NAME"
        error "Expected requirements.txt (Python) or package.json (Node.js)"
        exit 2
    fi
}

cleanup() {
    log ""
    log "Cleaning up..."

    # Stop sensor if running
    if [ -n "$SENSOR_PID" ] && kill -0 "$SENSOR_PID" 2>/dev/null; then
        $SUDO kill -TERM "$SENSOR_PID" 2>/dev/null || true
        wait "$SENSOR_PID" 2>/dev/null || true
    fi

    # Deactivate Python venv if active
    if [ "$LANGUAGE" = "python" ]; then
        deactivate 2>/dev/null || true
    fi
}

setup_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    rm -f "$EVENTS_FILE" "$SENSOR_LOG"
}

start_sensor() {
    log "Starting OISP Sensor..."

    # Determine process filter based on language
    PROCESS_FILTER=""
    case "$LANGUAGE" in
        python)
            PROCESS_FILTER="--process python"
            ;;
        node)
            PROCESS_FILTER="--process node"
            ;;
    esac

    $SUDO "$OISP_SENSOR_BIN" record \
        --output "$EVENTS_FILE" \
        $PROCESS_FILTER \
        > "$SENSOR_LOG" 2>&1 &
    SENSOR_PID=$!

    # Wait for sensor to initialize
    sleep 3

    # Verify sensor started
    if ! kill -0 "$SENSOR_PID" 2>/dev/null; then
        error "Sensor failed to start. Check $SENSOR_LOG"
        cat "$SENSOR_LOG"
        exit 1
    fi

    log "Sensor started (PID: $SENSOR_PID)"
}

setup_environment() {
    case "$LANGUAGE" in
        python)
            log ""
            log "Setting up Python environment..."
            if [ ! -d ".venv" ]; then
                python3 -m venv .venv
            fi
            source .venv/bin/activate
            pip install -q -r requirements.txt
            ;;

        node)
            log ""
            log "Setting up Node.js environment..."
            if [ ! -d "node_modules" ]; then
                npm install
            fi
            ;;
    esac
}

run_application() {
    log ""
    log "Running application..."

    case "$LANGUAGE" in
        python)
            python app.py
            ;;

        node)
            node index.js
            ;;

        *)
            error "Unsupported language: $LANGUAGE"
            exit 2
            ;;
    esac
}

wait_for_events() {
    log ""
    "$WAIT_SCRIPT" "$EVENTS_FILE" 2 30

    # Give sensor extra time to process and emit ai.response
    # (ai.response is generated after decompressing gzipped chunked response)
    sleep 5
}

stop_sensor() {
    log ""
    log "Stopping sensor..."
    $SUDO kill -TERM "$SENSOR_PID" 2>/dev/null || true
    sleep 2
}

validate_events() {
    log ""
    log "Validating captured events..."
    python3 "$VALIDATE_SCRIPT" "$EVENTS_FILE" "$EXPECTED_FILE"
    return $?
}

show_results() {
    local result=$1

    log ""
    if [ $result -eq 0 ]; then
        log "=== TEST PASSED ==="
    else
        log "=== TEST FAILED ==="
        log ""
        log "Captured events:"
        cat "$EVENTS_FILE" | head -20 || true
        log ""
        log "Sensor log:"
        cat "$SENSOR_LOG" | tail -50 || true
    fi
}

#
# Main test flow
#

# Banner
log "=== $COOKBOOK_NAME Test ==="
log ""

# Check prerequisites
check_prerequisites

# Setup cleanup trap
trap cleanup EXIT

# Setup output
setup_output_dir

# Start sensor
start_sensor

# Setup environment (venv, npm install)
setup_environment

# Run the application
run_application

# Wait for events
wait_for_events

# Stop sensor
stop_sensor

# Validate
validate_events
RESULT=$?

# Show results
show_results $RESULT

exit $RESULT
