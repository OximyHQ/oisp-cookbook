#!/bin/bash
#
# Master Test Runner for OISP Cookbook Examples
#
# This script tests all cookbook examples using OrbStack/Docker.
# It builds each Dockerfile.test and runs the test, collecting results.
#
# Usage:
#   export OPENAI_API_KEY=sk-...
#   ./test-all.sh
#
# Options:
#   ./test-all.sh [cookbook-name]    Test a specific cookbook
#   ./test-all.sh --parallel         Run tests in parallel (experimental)
#   ./test-all.sh --verbose          Show detailed output
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SENSOR_DIR="$REPO_ROOT/oisp-sensor"
COOKBOOK_DIR="$SCRIPT_DIR"
RESULTS_DIR="$SCRIPT_DIR/test-results"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Test results
RESULTS_FILE="$RESULTS_DIR/results-$TIMESTAMP.txt"
SUMMARY_FILE="$RESULTS_DIR/summary-$TIMESTAMP.md"

# Auto-discover cookbooks (any directory with expected-events.json)
DISCOVER_SCRIPT="$SCRIPT_DIR/shared/scripts/discover-cookbooks.sh"
if [ ! -f "$DISCOVER_SCRIPT" ]; then
    echo "ERROR: Discovery script not found: $DISCOVER_SCRIPT"
    exit 2
fi

mapfile -t COOKBOOKS < <("$DISCOVER_SCRIPT")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Options
VERBOSE=false
PARALLEL=false
SPECIFIC_COOKBOOK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            SPECIFIC_COOKBOOK="$1"
            shift
            ;;
    esac
done

# Functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker or OrbStack."
        exit 1
    fi

    # Check API key
    if [ -z "$OPENAI_API_KEY" ]; then
        error "OPENAI_API_KEY not set."
        echo "Please set it: export OPENAI_API_KEY=sk-..."
        exit 1
    fi

    # Check sensor directory
    if [ ! -d "$SENSOR_DIR" ]; then
        error "oisp-sensor directory not found at: $SENSOR_DIR"
        exit 1
    fi

    # Check if sensor has submodules
    if [ ! -d "$SENSOR_DIR/bpftool" ]; then
        error "oisp-sensor submodules not initialized."
        echo "Run: cd $SENSOR_DIR && git submodule update --init --recursive"
        exit 1
    fi

    success "Prerequisites OK"
}

# Test a single cookbook
test_cookbook() {
    local cookbook="$1"
    local cookbook_path="$COOKBOOK_DIR/$cookbook"
    local dockerfile="$cookbook_path/Dockerfile.test"
    local test_name=$(basename "$cookbook")
    local category=$(dirname "$cookbook")

    log "Testing: $cookbook"

    # Check if Dockerfile.test exists
    if [ ! -f "$dockerfile" ]; then
        warning "No Dockerfile.test found for $cookbook"
        echo "SKIP|$cookbook|No Dockerfile.test" >> "$RESULTS_FILE"
        return 0
    fi

    # Build image
    local image_name="oisp-test-$category-$test_name:latest"
    image_name=$(echo "$image_name" | tr '/' '-')

    # Sanitize cookbook name for file paths
    local cookbook_safe=$(echo "$cookbook" | tr '/' '-')

    log "Building image: $image_name"

    if [ "$VERBOSE" = true ]; then
        docker build \
            -f "$dockerfile" \
            -t "$image_name" \
            --build-context oisp-sensor="$SENSOR_DIR" \
            --build-context oisp-cookbook="$COOKBOOK_DIR" \
            "$REPO_ROOT"
    else
        docker build \
            -f "$dockerfile" \
            -t "$image_name" \
            --build-context oisp-sensor="$SENSOR_DIR" \
            --build-context oisp-cookbook="$COOKBOOK_DIR" \
            "$REPO_ROOT" \
            > "$RESULTS_DIR/$cookbook_safe-build.log" 2>&1
    fi

    if [ $? -ne 0 ]; then
        error "Build failed for $cookbook"
        echo "FAIL|$cookbook|Build failed" >> "$RESULTS_FILE"
        return 1
    fi

    # Run test
    log "Running test: $cookbook"

    local test_log="$RESULTS_DIR/$cookbook_safe-test.log"

    if [ "$VERBOSE" = true ]; then
        docker run --rm --privileged \
            -e OPENAI_API_KEY="$OPENAI_API_KEY" \
            "$image_name" | tee "$test_log"
        local result=$?
    else
        docker run --rm --privileged \
            -e OPENAI_API_KEY="$OPENAI_API_KEY" \
            "$image_name" > "$test_log" 2>&1
        local result=$?
    fi

    # Check result
    if [ $result -eq 0 ]; then
        success "Test passed: $cookbook"
        echo "PASS|$cookbook|Test passed" >> "$RESULTS_FILE"
        return 0
    else
        error "Test failed: $cookbook"
        echo "FAIL|$cookbook|Test failed (exit code: $result)" >> "$RESULTS_FILE"

        if [ "$VERBOSE" = false ]; then
            warning "Check log: $test_log"
            echo ""
            echo "=== Last 30 lines of test output ==="
            tail -30 "$test_log"
            echo "=== End of output ==="
            echo ""
        fi

        return 1
    fi
}

# Generate summary report
generate_summary() {
    log "Generating summary report..."

    local total=0
    local passed=0
    local failed=0
    local skipped=0

    {
        echo "# OISP Cookbook Test Results"
        echo ""
        echo "**Timestamp:** $TIMESTAMP"
        echo ""
        echo "## Summary"
        echo ""

        # Count results
        while IFS='|' read -r status cookbook message; do
            total=$((total + 1))
            case $status in
                PASS) passed=$((passed + 1)) ;;
                FAIL) failed=$((failed + 1)) ;;
                SKIP) skipped=$((skipped + 1)) ;;
            esac
        done < "$RESULTS_FILE"

        echo "- **Total:** $total"
        echo "- **Passed:** $passed"
        echo "- **Failed:** $failed"
        echo "- **Skipped:** $skipped"
        echo ""

        # Results table
        echo "## Detailed Results"
        echo ""
        echo "| Status | Cookbook | Notes |"
        echo "|--------|----------|-------|"

        while IFS='|' read -r status cookbook message; do
            local icon
            case $status in
                PASS) icon="✅" ;;
                FAIL) icon="❌" ;;
                SKIP) icon="⏭️" ;;
                *) icon="❓" ;;
            esac
            echo "| $icon | $cookbook | $message |"
        done < "$RESULTS_FILE"

        echo ""
        echo "## Test Logs"
        echo ""
        echo "All test logs are available in: \`$RESULTS_DIR/\`"
        echo ""

    } > "$SUMMARY_FILE"

    success "Summary report: $SUMMARY_FILE"
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        OISP Cookbook Test Suite                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Setup
    mkdir -p "$RESULTS_DIR"
    : > "$RESULTS_FILE"  # Clear results file

    check_prerequisites

    echo ""
    log "Starting tests..."
    echo ""

    # Determine which cookbooks to test
    local cookbooks_to_test=()
    if [ -n "$SPECIFIC_COOKBOOK" ]; then
        cookbooks_to_test=("$SPECIFIC_COOKBOOK")
        log "Testing specific cookbook: $SPECIFIC_COOKBOOK"
    else
        cookbooks_to_test=("${COOKBOOKS[@]}")
        log "Testing all ${#COOKBOOKS[@]} cookbooks"
    fi

    echo ""

    # Run tests
    local test_count=0
    local total_tests=${#cookbooks_to_test[@]}

    for cookbook in "${cookbooks_to_test[@]}"; do
        test_count=$((test_count + 1))
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Test $test_count/$total_tests: $cookbook"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        test_cookbook "$cookbook"

        echo ""
    done

    # Generate summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    generate_summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Display summary
    cat "$SUMMARY_FILE"

    # Exit code based on failures
    local failed_count=$(grep -c "^FAIL|" "$RESULTS_FILE" || true)
    if [ "$failed_count" -gt 0 ]; then
        error "$failed_count test(s) failed"
        exit 1
    else
        success "All tests passed!"
        exit 0
    fi
}

# Run main
main
