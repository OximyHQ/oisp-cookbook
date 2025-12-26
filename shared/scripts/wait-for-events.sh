#!/bin/bash
# Wait for events to appear in output file
#
# Usage: ./wait-for-events.sh <output-file> <min-events> [timeout-seconds]

set -e

OUTPUT_FILE="${1:?Usage: wait-for-events.sh <output-file> <min-events> [timeout]}"
MIN_EVENTS="${2:?Usage: wait-for-events.sh <output-file> <min-events> [timeout]}"
TIMEOUT="${3:-60}"

echo "Waiting for at least $MIN_EVENTS events in $OUTPUT_FILE (timeout: ${TIMEOUT}s)..."

start_time=$(date +%s)

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $TIMEOUT ]; then
        echo "Timeout after ${TIMEOUT}s"
        exit 1
    fi
    
    if [ -f "$OUTPUT_FILE" ]; then
        count=$(wc -l < "$OUTPUT_FILE" 2>/dev/null | tr -d ' ')
        if [ "$count" -ge "$MIN_EVENTS" ]; then
            echo "Found $count events after ${elapsed}s"
            exit 0
        fi
        echo "  ... $count events (need $MIN_EVENTS, ${elapsed}s elapsed)"
    else
        echo "  ... waiting for file (${elapsed}s elapsed)"
    fi
    
    sleep 2
done

